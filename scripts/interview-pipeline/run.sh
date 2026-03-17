#!/bin/bash
# run.sh — Quick launcher for the interview pipeline
#
# Usage:
#   ./run.sh                    # Process all new interviews + synthesize
#   ./run.sh watch              # Start file watcher
#   ./run.sh single <file>      # Process one interview
#   ./run.sh synthesize         # Just run synthesis on existing extracts
#   ./run.sh status             # Show pipeline status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROCESS="$SCRIPT_DIR/process-interview.sh"
WATCH="$SCRIPT_DIR/watch-interviews.sh"
LOG="$SCRIPT_DIR/processed.log"
EXTRACTS="/Users/main/Documents/Kompete/kompete-research/synthesis/extracts"
INTERVIEWS="/Users/main/Documents/Kompete/kompete-research/interviews"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "${1:-}" in
    watch)
        exec "$WATCH" "${2:-}"
        ;;
    single)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 single <path-to-transcript.md>"
            exit 1
        fi
        bash "$PROCESS" "$2"
        bash "$PROCESS" --synthesize
        ;;
    synthesize|sync)
        bash "$PROCESS" --synthesize
        ;;
    status)
        total=$(find "$INTERVIEWS" -name "*.md" ! -name ".*" | wc -l | tr -d ' ')
        processed=$(wc -l < "$LOG" 2>/dev/null | tr -d ' ' || echo "0")
        extracts=$(find "$EXTRACTS" -name "extract-*.md" 2>/dev/null | wc -l | tr -d ' ')
        synthesis=$(find "$EXTRACTS" -name "_synthesis-*.md" 2>/dev/null | wc -l | tr -d ' ')

        echo ""
        echo -e "${BLUE}═══ Interview Pipeline Status ═══${NC}"
        echo ""
        echo -e "  Interviews found:     ${GREEN}$total${NC}"
        echo -e "  Processed:            ${GREEN}$processed${NC}"
        echo -e "  Remaining:            ${YELLOW}$((total - processed))${NC}"
        echo -e "  Extracts generated:   ${GREEN}$extracts${NC}"
        echo -e "  Synthesis reports:    ${GREEN}$synthesis${NC}"
        echo ""

        if [ -f "$SCRIPT_DIR/.watcher.pid" ] && kill -0 "$(cat "$SCRIPT_DIR/.watcher.pid")" 2>/dev/null; then
            echo -e "  Watcher:              ${GREEN}Running (PID: $(cat "$SCRIPT_DIR/.watcher.pid"))${NC}"
        else
            echo -e "  Watcher:              ${YELLOW}Not running${NC}"
        fi
        echo ""
        ;;
    --help|-h|help)
        echo ""
        echo "Interview Pipeline — Kompete.ai"
        echo ""
        echo "Usage:"
        echo "  ./run.sh                     Process all new interviews + synthesize"
        echo "  ./run.sh watch               Start file watcher (auto-process on new files)"
        echo "  ./run.sh watch --daemon      Start watcher in background"
        echo "  ./run.sh single <file.md>    Process one interview + synthesize"
        echo "  ./run.sh synthesize          Run synthesis on existing extracts"
        echo "  ./run.sh status              Show pipeline status"
        echo ""
        echo "Flow:"
        echo "  1. Drop .md transcript into kompete-research/interviews/"
        echo "  2. Pipeline extracts objections, pain points, insights, quotes"
        echo "  3. Synthesis merges all extracts into update recommendations"
        echo "  4. Review synthesis report → apply to war room, pain-points, key-themes"
        echo ""
        ;;
    *)
        # Default: process all unprocessed + synthesize
        bash "$PROCESS" --all
        bash "$PROCESS" --synthesize
        ;;
esac
