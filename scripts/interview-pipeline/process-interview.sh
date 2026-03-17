#!/bin/bash
# process-interview.sh — Extract structured insights from a single interview transcript
#
# Usage:
#   ./process-interview.sh <path-to-transcript.md>
#   ./process-interview.sh --all          # Process all unprocessed interviews
#   ./process-interview.sh --reprocess    # Reprocess all interviews (ignore log)
#
# Output: Creates an extract file in kompete-research/synthesis/extracts/
# Updates: processed.log to track what's been done

set -euo pipefail

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KOMPETE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RESEARCH_DIR="/Users/main/Documents/Kompete/kompete-research"
INTERVIEWS_DIR="$RESEARCH_DIR/interviews"
EXTRACTS_DIR="$RESEARCH_DIR/synthesis/extracts"
WEBSITE_DIR="$KOMPETE_ROOT"

PROMPT_FILE="$SCRIPT_DIR/extraction-prompt.md"
PROCESSED_LOG="$SCRIPT_DIR/processed.log"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Setup ──
mkdir -p "$EXTRACTS_DIR"
touch "$PROCESSED_LOG"

log() { echo -e "${BLUE}[pipeline]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ── Check dependencies ──
if ! command -v "$CLAUDE_BIN" &>/dev/null; then
    error "Claude CLI not found. Set CLAUDE_BIN or install claude."
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    error "Extraction prompt not found at $PROMPT_FILE"
    exit 1
fi

# ── Process a single transcript ──
process_one() {
    local transcript="$1"
    local filename
    filename="$(basename "$transcript")"
    local extract_name="extract-${filename}"
    local extract_path="$EXTRACTS_DIR/$extract_name"

    # Skip non-markdown or gitkeep
    if [[ "$filename" == .* ]] || [[ "$filename" != *.md ]]; then
        return 0
    fi

    # Skip if already processed (unless --reprocess)
    if [[ "$REPROCESS" != "true" ]] && grep -qF "$filename" "$PROCESSED_LOG" 2>/dev/null; then
        warn "Skipping (already processed): $filename"
        return 0
    fi

    log "Processing: $filename"

    # Build the prompt: system prompt + transcript content
    local system_prompt
    system_prompt="$(cat "$PROMPT_FILE")"

    local transcript_content
    transcript_content="$(cat "$transcript")"

    # Run Claude in print mode
    local output
    if output=$("$CLAUDE_BIN" -p \
        --system-prompt "$system_prompt" \
        --allowedTools "" \
        --model sonnet \
        "Analyze the following interview transcript and extract structured insights per the format in your system prompt.

TRANSCRIPT:
$transcript_content" 2>&1); then

        # Write extract
        echo "$output" > "$extract_path"

        # Log as processed
        echo "$filename|$(date -u +%Y-%m-%dT%H:%M:%SZ)|$extract_name" >> "$PROCESSED_LOG"

        success "Extract saved: $extract_name"
    else
        error "Claude failed for $filename: $output"
        return 1
    fi
}

# ── Synthesize: merge all extracts into updated synthesis files ──
run_synthesis() {
    log "Running synthesis across all extracts..."

    local all_extracts=""
    local count=0

    for extract in "$EXTRACTS_DIR"/extract-*.md; do
        [ -f "$extract" ] || continue
        all_extracts+="

--- EXTRACT: $(basename "$extract") ---

$(cat "$extract")"
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        warn "No extracts found. Nothing to synthesize."
        return 0
    fi

    log "Synthesizing $count extracts..."

    local synthesis_prompt
    synthesis_prompt="You are a research synthesis agent for Kompete.ai.

You have $count interview extracts below. Your job is to produce THREE updated synthesis documents:

## Document 1: PAIN POINTS UPDATE
Identify any NEW pain points not already in the existing pain-points.md, or update frequency counts.
Output format: a list of additions/updates to make, with quotes and interview sources.

## Document 2: KEY THEMES UPDATE
Identify any NEW themes or update frequency counts for existing themes.
Output format: a list of additions/updates to make, with quotes and interview sources.

## Document 3: WAR ROOM UPDATES
Identify NEW objections, insights, or strategic feedback that should be added to the strategic-war-room.md.
For each, provide:
- Objection/Insight number (continue from existing numbering)
- Full formatted entry matching the war room format (with Key quote, Our response, etc.)
- Which conversation it came from

## Existing Files for Reference

### Current Pain Points:
$(cat "$RESEARCH_DIR/synthesis/pain-points.md" 2>/dev/null | head -100)

### Current Key Themes:
$(cat "$RESEARCH_DIR/synthesis/key-themes.md" 2>/dev/null | head -100)

## All Extracts:
$all_extracts"

    local output
    if output=$("$CLAUDE_BIN" -p \
        --system-prompt "You are a research synthesis agent. Output clean markdown only. Be specific about what to add or update and where." \
        --allowedTools "" \
        --model sonnet \
        "$synthesis_prompt" 2>&1); then

        local synthesis_path="$RESEARCH_DIR/synthesis/extracts/_synthesis-report-$(date +%Y%m%d-%H%M%S).md"
        echo "$output" > "$synthesis_path"
        success "Synthesis report saved: $(basename "$synthesis_path")"
        log "Review the synthesis report and apply updates to the main files."
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Review: cat $synthesis_path"
        echo "  2. Apply updates to pain-points.md, key-themes.md, and strategic-war-room.md"
        echo "  3. Or run: ./process-interview.sh --apply (coming soon)"
    else
        error "Synthesis failed: $output"
        return 1
    fi
}

# ── Main ──
REPROCESS="false"
MODE="single"

case "${1:-}" in
    --all)
        MODE="all"
        ;;
    --reprocess)
        MODE="all"
        REPROCESS="true"
        ;;
    --synthesize)
        MODE="synthesize"
        ;;
    --help|-h)
        echo "Usage:"
        echo "  $0 <transcript.md>       Process a single interview"
        echo "  $0 --all                 Process all unprocessed interviews"
        echo "  $0 --reprocess           Reprocess ALL interviews (ignores log)"
        echo "  $0 --synthesize          Run synthesis on existing extracts"
        echo ""
        echo "Pipeline: process interviews → generate extracts → synthesize → update docs"
        exit 0
        ;;
    "")
        error "No argument provided. Use --help for usage."
        exit 1
        ;;
    *)
        MODE="single"
        ;;
esac

if [ "$MODE" = "single" ]; then
    process_one "$1"
    echo ""
    log "Run '$0 --synthesize' after processing to update synthesis files."

elif [ "$MODE" = "all" ]; then
    total=0
    processed=0
    skipped=0
    failed=0

    for transcript in "$INTERVIEWS_DIR"/*.md; do
        [ -f "$transcript" ] || continue
        total=$((total + 1))

        if process_one "$transcript"; then
            filename="$(basename "$transcript")"
            if [[ "$filename" == .* ]]; then
                continue
            fi
            # Check if it was actually processed or skipped
            if grep -qF "Skipping" <<< "$(process_one "$transcript" 2>&1)" 2>/dev/null; then
                skipped=$((skipped + 1))
            else
                processed=$((processed + 1))
            fi
        else
            failed=$((failed + 1))
        fi
    done

    echo ""
    log "Done. Total: $total | Processed: $processed | Skipped: $skipped | Failed: $failed"
    echo ""
    log "Run '$0 --synthesize' to update synthesis files."

elif [ "$MODE" = "synthesize" ]; then
    run_synthesis
fi
