#!/bin/bash
# snapshot.sh — Creates a dated backup of the current website
# Usage: ./scripts/snapshot.sh [optional-label]
#
# Creates: snapshots/YYYY-MM-DD/ (or snapshots/YYYY-MM-DD-v2/ if exists)
# Also creates a git tag: snapshot-YYYY-MM-DD

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SITE_DIR="$REPO_ROOT/site"
SNAPSHOTS_DIR="$REPO_ROOT/snapshots"

DATE=$(date +%Y-%m-%d)
LABEL="${1:-}"

if [ -n "$LABEL" ]; then
    SNAPSHOT_NAME="${DATE}-${LABEL}"
else
    SNAPSHOT_NAME="$DATE"
fi

# Handle duplicate dates by appending version
TARGET="$SNAPSHOTS_DIR/$SNAPSHOT_NAME"
if [ -d "$TARGET" ]; then
    VERSION=2
    while [ -d "$SNAPSHOTS_DIR/${SNAPSHOT_NAME}-v${VERSION}" ]; do
        VERSION=$((VERSION + 1))
    done
    SNAPSHOT_NAME="${SNAPSHOT_NAME}-v${VERSION}"
    TARGET="$SNAPSHOTS_DIR/$SNAPSHOT_NAME"
fi

# Check site directory exists and has content
if [ ! -d "$SITE_DIR" ] || [ -z "$(ls -A "$SITE_DIR" 2>/dev/null)" ]; then
    echo "Error: site/ directory is empty or doesn't exist."
    echo "Add your website files to site/ first."
    exit 1
fi

# Create snapshot
echo "Creating snapshot: $SNAPSHOT_NAME"
mkdir -p "$TARGET"
cp -r "$SITE_DIR"/* "$TARGET"/

# Create metadata file
cat > "$TARGET/.snapshot-meta.json" <<EOF
{
  "date": "$DATE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "label": "$LABEL",
  "snapshot_name": "$SNAPSHOT_NAME",
  "files": $(find "$TARGET" -type f ! -name '.snapshot-meta.json' | wc -l | tr -d ' ')
}
EOF

echo "Snapshot created at: snapshots/$SNAPSHOT_NAME/"
echo "Files copied: $(find "$TARGET" -type f ! -name '.snapshot-meta.json' | wc -l | tr -d ' ')"
echo ""
echo "Next steps:"
echo "  git add snapshots/$SNAPSHOT_NAME"
echo "  git commit -m 'Snapshot: $SNAPSHOT_NAME'"
echo "  git tag snapshot-$SNAPSHOT_NAME"
