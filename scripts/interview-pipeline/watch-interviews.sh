#!/bin/bash
# watch-interviews.sh — Watch the interviews folder for new/modified files
# and automatically trigger the processing pipeline.
#
# Usage:
#   ./watch-interviews.sh              # Start watching (foreground)
#   ./watch-interviews.sh --daemon     # Start watching (background)
#   ./watch-interviews.sh --stop       # Stop the background watcher
#
# Requires: fswatch (brew install fswatch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTERVIEWS_DIR="/Users/main/Documents/Kompete/kompete-research/interviews"
PROCESS_SCRIPT="$SCRIPT_DIR/process-interview.sh"
PID_FILE="$SCRIPT_DIR/.watcher.pid"
LOG_FILE="$SCRIPT_DIR/watcher.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[watcher]${NC} $1"; }

# ── Check fswatch ──
if ! command -v fswatch &>/dev/null; then
    echo -e "${YELLOW}fswatch not installed. Installing via Homebrew...${NC}"
    brew install fswatch
fi

# ── Debounce: avoid processing the same file multiple times in quick succession ──
DEBOUNCE_SECONDS=5
declare -A LAST_PROCESSED 2>/dev/null || true

process_if_new() {
    local filepath="$1"
    local filename
    filename="$(basename "$filepath")"

    # Only process .md files
    [[ "$filename" == *.md ]] || return 0
    [[ "$filename" == .* ]] && return 0

    local now
    now=$(date +%s)
    local last="${LAST_PROCESSED[$filename]:-0}"

    if (( now - last < DEBOUNCE_SECONDS )); then
        return 0
    fi

    LAST_PROCESSED[$filename]=$now

    log "Detected change: $filename"
    "$PROCESS_SCRIPT" "$filepath"

    # Auto-synthesize after each new interview
    log "Running synthesis..."
    "$PROCESS_SCRIPT" --synthesize
}

# ── Daemon mode ──
case "${1:-}" in
    --daemon)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo -e "${YELLOW}Watcher already running (PID: $(cat "$PID_FILE"))${NC}"
            exit 1
        fi

        log "Starting watcher daemon..."
        nohup "$0" >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo -e "${GREEN}Watcher started (PID: $!, log: $LOG_FILE)${NC}"
        exit 0
        ;;
    --stop)
        if [ -f "$PID_FILE" ]; then
            local_pid=$(cat "$PID_FILE")
            if kill -0 "$local_pid" 2>/dev/null; then
                kill "$local_pid"
                rm -f "$PID_FILE"
                echo -e "${GREEN}Watcher stopped (PID: $local_pid)${NC}"
            else
                rm -f "$PID_FILE"
                echo -e "${YELLOW}Watcher was not running. Cleaned up PID file.${NC}"
            fi
        else
            echo -e "${YELLOW}No watcher running.${NC}"
        fi
        exit 0
        ;;
    --help|-h)
        echo "Usage:"
        echo "  $0              Start watching (foreground)"
        echo "  $0 --daemon     Start watching (background)"
        echo "  $0 --stop       Stop the background watcher"
        exit 0
        ;;
esac

# ── Foreground watch ──
log "Watching: $INTERVIEWS_DIR"
log "Press Ctrl+C to stop."
echo ""

fswatch -0 --event Created --event Updated --event Renamed \
    "$INTERVIEWS_DIR" | while IFS= read -r -d '' filepath; do
    process_if_new "$filepath"
done
