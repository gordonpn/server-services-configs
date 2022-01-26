#!/usr/bin/env bash

trim_logs() {
  logfile="$1"
  max_lines=200
  local lines
  lines=$(wc -l <"${logfile}")
  if ((lines >= max_lines)); then
    lines_to_remove=$((lines - max_lines + 1))
    tail -n +"${lines_to_remove}" "$logfile" >"$logfile.tmp" && mv "$logfile.tmp" "$logfile"
  else
    echo "Log file not long enough yet, not trimming."
  fi
}
