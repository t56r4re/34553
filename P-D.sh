#!/usr/bin/env bash
#
# proc_manager.sh
# Interactive process inspector + kill + optional delete executable
#
# Usage: ./proc_manager.sh
#
# Requirements: coreutils, ps, pgrep, readlink, lsof (optional), sudo for privileged actions
#
set -u
LOGFILE="${LOGFILE:-/var/log/proc_manager.log}"
TMP="/tmp/proc_manager.$$"
BLACKLIST_PATHS=("/bin" "/sbin" "/usr/bin" "/usr/sbin" "/lib" "/lib64" "/etc" "/proc" "/sys" "/dev" "/root" "/boot")

# Languages/keywords to detect
KEYWORDS=(python node nodejs php ruby java go perl bash sh ksh zsh "python3")

# Helpers
die() { echo "Error: $*" >&2; exit 1; }
info(){ echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }
ok(){ echo -e "\e[1;32m[OK]\e[0m $*"; }
log() {
  ts="$(date --iso-8601=seconds 2>/dev/null || date)"
  echo "[$ts] $*" >> "$LOGFILE" 2>/dev/null || true
}

ensure_tools() {
  for cmd in ps awk sed readlink pgrep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      die "Required tool '$cmd' not found. Install it and re-run."
    fi
  done
}

# Build process list (filtered by keywords or show all)
build_list() {
  > "$TMP"
  # ps -eo pid,uid,user,cmd --no-headers may show long cmd
  ps -eo pid,uid,user:16,etimes,args --no-headers | while read -r pid uid user etime args_rest; do
    # ignore kernel threads (in brackets) or very short/empty commands
    if [ -z "$pid" ] || [ -z "$args_rest" ]; then continue; fi
    # get command base
    cmdbase=$(echo "$args_rest" | awk '{print $1}')
    # try to match any keyword
    matched=false
    for kw in "${KEYWORDS[@]}"; do
      if echo "$args_rest" | grep -i -q -- "$kw"; then matched=true; break; fi
      if [ -x "$cmdbase" ] && basename "$cmdbase" | grep -i -q -- "$kw"; then matched=true; break; fi
    done
    if [ "$FILTER_MODE" = "all" ] || [ "$matched" = true ]; then
      printf "%s\t%s\t%s\t%s\t%s\n" "$pid" "$uid" "$user" "$etime" "$args_rest" >> "$TMP"
    fi
  done
}

show_menu() {
  echo
  echo "================ Process Manager ================"
  echo "Logged actions will be appended to: $LOGFILE"
  echo
  echo "Choose listing mode:"
  echo "  1) Show only likely programming-language processes (python/node/php/java/...)"
  echo "  2) Show ALL processes"
  echo "  q) Quit"
  read -rp "> " choice
  case "$choice" in
    1) FILTER_MODE="lang";;
    2) FILTER_MODE="all";;
    q|Q) cleanup_and_exit;;
    *) echo "Invalid"; show_menu;;
  esac

  build_list
  if [ ! -s "$TMP" ]; then
    echo "No matching processes found."
    cleanup_and_exit
  fi

  echo
  echo "Index | PID   | UID | USER            | ELAPSED(s) | COMMAND"
  echo "---------------------------------------------------------------"
  nl -ba -w3 -s'. ' "$TMP" | while read -r line; do
    # print formatted
    echo "$line" | awk -F'\t' '{printf "%4s | %5s | %3s | %-15s | %10s | %s\n", $1, $2, $3, $3, $4, $5}'
  done
  echo
  interact_loop
}

interact_loop() {
  echo "Options:"
  echo "  <index> - inspect process by index"
  echo "  r       - refresh list"
  echo "  q       - quit"
  while true; do
    read -rp "proc-mgr> " cmd
    case "$cmd" in
      r) build_list; echo "Refreshed."; show_entries;;
      q) cleanup_and_exit;;
      '' ) ;;
      * )
        if echo "$cmd" | grep -qE '^[0-9]+$'; then
          inspect_by_index "$cmd"
        else
          echo "Unknown input. Type index number, r, or q."
        fi
      ;;
    esac
  done
}

show_entries() {
  echo
  echo "Index | PID   | UID | USER            | ELAPSED(s) | COMMAND"
  echo "---------------------------------------------------------------"
  nl -ba -w3 -s'. ' "$TMP" | while read -r line; do
    # show same as earlier
    awk -F'\t' '{printf "%4s | %5s | %3s | %-15s | %10s | %s\n", $1, $2, $3, $3, $4, $5}' <<<"$line"
  done
}

get_line_by_index() {
  idx="$1"
  line=$(sed -n "${idx}p" "$TMP" 2>/dev/null || true)
  echo "$line"
}

inspect_by_index() {
  idx="$1"
  line="$(get_line_by_index "$idx")"
  if [ -z "$line" ]; then
    echo "No entry at index $idx"
    return
  fi
  pid=$(awk -F'\t' '{print $1}' <<<"$line")
  uid=$(awk -F'\t' '{print $2}' <<<"$line")
  user=$(awk -F'\t' '{print $3}' <<<"$line")
  etime=$(awk -F'\t' '{print $4}' <<<"$line")
  cmdline=$(awk -F'\t' '{ $1=""; $2=""; $3=""; $4=""; sub("\t\t\t", ""); print substr($0,2) }' <<<"$line")

  echo
  echo "------ DETAILS for PID $pid ------"
  echo "User: $user (UID $uid)"
  echo "Elapsed (s): $etime"
  echo "Cmdline: $cmdline"
  exe_path=""
  if [ -r "/proc/$pid/exe" ]; then
    exe_path="$(readlink -f /proc/$pid/exe 2>/dev/null || true)"
  fi
  echo "Executable path: ${exe_path:-(not available)}"

  # try to read /proc/<pid>/cgroup to detect systemd unit
  unitname=""
  if [ -r "/proc/$pid/cgroup" ]; then
    cg=$(grep -E "name=systemd" -n /proc/$pid/cgroup 2>/dev/null || true)
    if [ -n "$cg" ]; then
      # try to pick unit mention
      unitname=$(sed -n '1,1p' /proc/$pid/cgroup | sed 's/^.*\///' | tr -d '[:space:]' || true)
    else
      # search for ".service"
      unitline=$(tr -d '\0' < /proc/$pid/cgroup 2>/dev/null | grep -Eo '[a-zA-Z0-9_.-]+\.service' | head -n1 || true)
      unitname="$unitline"
    fi
  fi

  if command -v lsof >/dev/null 2>&1; then
    echo
    echo "Open network/listening sockets (if any):"
    sudo lsof -nP -p "$pid" 2>/dev/null | sed -n '1,7p'
  fi

  echo
  echo "Actions for PID $pid:"
  echo "  1) Stop (SIGTERM)"
  echo "  2) Force stop (SIGKILL)"
  if [ -n "$unitname" ]; then
    echo "  3) Stop & disable systemd unit: $unitname"
  fi
  echo "  4) Delete executable/script file (requires confirmation)"
  echo "  b) Back to list"

  read -rp "Choose action: " act
  case "$act" in
    1) do_kill "$pid" "TERM";;
    2) do_kill "$pid" "KILL";;
    3)
      if [ -n "$unitname" ]; then
        stop_and_disable_unit "$unitname"
      else
        echo "No systemd unit detected for this PID."
      fi
    ;;
    4)
      if [ -n "$exe_path" ]; then
        attempt_delete_file "$exe_path" "$uid" "$user"
      else
        echo "Executable path not known. Provide absolute path to delete (or 'c' to cancel):"
        read -rp "Path> " given
        if [ "$given" = "c" ]; then echo "Cancelled."; else attempt_delete_file "$given" "$uid" "$user"; fi
      fi
    ;;
    b|B) return;;
    *) echo "Unknown action";;
  esac
}

do_kill() {
  pid="$1"
  mode="$2" # TERM or KILL
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Process $pid does not exist anymore."
    return
  fi

  # if root-owned, force extra confirmation
  owner_uid=$(awk '{print $2}' <<<"$(ps -o pid,uid -p "$pid" --no-headers 2>/dev/null)" | tr -d ' ' || true)
  if [ "$owner_uid" = "0" ]; then
    warn "Process is owned by root. Killing root processes can break the system."
    read -rp "Type EXACTLY 'YES I KNOW' to continue: " conf
    if [ "$conf" != "YES I KNOW" ]; then
      echo "Aborted by user."
      return
    fi
  fi

  if [ "$mode" = "TERM" ]; then
    echo "Sending SIGTERM to PID $pid..."
    sudo kill "$pid" 2>/dev/null || { warn "Failed to send SIGTERM"; return; }
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
      warn "Process still alive after SIGTERM."
      read -rp "Send SIGKILL (y/N)? " yn
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        sudo kill -9 "$pid" 2>/dev/null && ok "SIGKILL sent." || warn "Failed to send SIGKILL."
        log "Forced killed PID $pid"
      else
        echo "Not forcing kill."
      fi
    else
      ok "Process $pid terminated."
      log "Terminated PID $pid with SIGTERM"
    fi
  else
    echo "Sending SIGKILL to PID $pid..."
    sudo kill -9 "$pid" 2>/dev/null && ok "SIGKILL sent." || warn "Failed to send SIGKILL."
    log "Killed PID $pid with SIGKILL"
  fi
}

stop_and_disable_unit() {
  unit="$1"
  warn "Attempting to stop and disable unit: $unit"
  read -rp "Proceed? (y/N): " yn
  if [[ ! "$yn" =~ ^[Yy]$ ]]; then echo "Cancelled."; return; fi
  sudo systemctl stop "$unit" && ok "stopped $unit" || warn "failed to stop $unit"
  sudo systemctl disable "$unit" && ok "disabled $unit" || warn "failed to disable $unit"
  log "Stopped & disabled systemd unit $unit"
}

is_under_blacklist() {
  path="$1"
  for b in "${BLACKLIST_PATHS[@]}"; do
    case "$path" in
      "$b"/*|"$b") return 0;;
    esac
  done
  return 1
}

attempt_delete_file() {
  path="$1"
  proc_uid="$2"
  proc_user="$3"

  if [ -z "$path" ]; then echo "No path provided."; return; fi
  if [ ! -e "$path" ]; then warn "Path does not exist: $path"; return; fi

  # resolve symlink
  resolved="$(readlink -f "$path" 2>/dev/null || echo "$path")"

  if is_under_blacklist "$resolved"; then
    warn "Refusing to delete: $resolved (protected system path)."
    return
  fi

  echo
  echo "About to delete: $resolved"
  echo "Owned by UID: $(stat -c '%u' "$resolved")  Group: $(stat -c '%g' "$resolved")"
  echo "Make sure you really want to remove this file. This action is irreversible."
  read -rp "Type DELETE to permanently remove, or anything else to cancel: " confirm
  if [ "$confirm" != "DELETE" ]; then
    echo "Cancelled deletion."
    return
  fi

  # if file is currently executed by some PID(s), warn
  pids_using=$(lsof -t "$resolved" 2>/dev/null || true)
  if [ -n "$pids_using" ]; then
    warn "File is currently opened/used by PID(s): $pids_using"
    read -rp "Kill those PIDs before deleting? (y/N) " killyn
    if [[ "$killyn" =~ ^[Yy]$ ]]; then
      for pk in $pids_using; do
        sudo kill -9 "$pk" 2>/dev/null || true
        log "Force killed PID $pk before deleting $resolved"
      done
    fi
  fi

  sudo rm -f "$resolved" && ok "Deleted: $resolved" || warn "Failed to delete: $resolved"
  log "Deleted file $resolved (requested by user $USER)"
}

cleanup_and_exit() {
  rm -f "$TMP" 2>/dev/null || true
  echo "Exiting. Log saved to $LOGFILE (if writable)."
  exit 0
}

# main
ensure_tools
echo "Process Manager - interactive"
echo "Log: $LOGFILE"
# create log file if possible
touch "$LOGFILE" 2>/dev/null || true

FILTER_MODE="lang"
show_menu
