#!/bin/bash
# Create log directory
mkdir -p "$HOME/Documents/Github/logs"

# Check all panes across all sessions
tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} #{session_name} #{window_name}" | \
while read target session_name window_name; do
  
  process_type=""
  
  # Match window names to determine log type
  case "$window_name" in
    *mobile-runner*)
      process_type="mobile"
      ;;
    *web-runner*)
      process_type="web"
      ;;
    *net-runner*)
      process_type="aspire"
      ;;
    *)
      # Skip windows that don't match our runners
      continue
      ;;
  esac
  
  # Create log filename: session-window-processtype.log
  safe_session=$(echo "$session_name" | tr ' /:' '_')
  safe_window=$(echo "$window_name" | tr ' /:' '_')
  
  log_file="$HOME/Documents/Github/logs/${safe_session}-${safe_window}-${process_type}.log"
  
  # Check if already piping
  is_piping=$(tmux display -p -t "$target" "#{pane_pipe}" 2>/dev/null)
  
  # Only enable if not already piping
  if [[ "$is_piping" == "0" ]]; then
    # Clear/create the log file
    > "$log_file"
    
    # Enable logging with ANSI filtering
    if [[ "$process_type" == "aspire" ]]; then
      tmux pipe-pane -t "$target" -o "ansifilter >> '$log_file'"
    else
      tmux pipe-pane -t "$target" -o "sed -u 's/\x1b\[[0-9;]*m//g' >> '$log_file'"
    fi
    
    echo "Logging $session_name:$window_name ($process_type) to: $log_file"
  fi
done
