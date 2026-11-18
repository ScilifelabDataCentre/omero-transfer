#!/usr/bin/env bash
# Full transfer: preflight checks, pack on SRC, unpack on DST, optional cleanup.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPTS_DIR/common.sh"

usage() {
    cat <<EOF
Usage: scripts/transfer.sh [-c CONFIG] [--merge]

Runs check.sh, pack.sh and unpack.sh in sequence, then offers to delete the
local archive. Each login prompts for the password.

  -c, --config FILE   config file (default: transfer.env)
  --merge             add into an existing Project/Dataset with the same name
                      instead of creating a duplicate (same as MERGE=true)
EOF
}

parse_args "$@"
export CONFIG MERGE

# CONFIG and MERGE are exported above; sub-scripts pick them up from the environment.
"$SCRIPTS_DIR/check.sh"
"$SCRIPTS_DIR/pack.sh"
"$SCRIPTS_DIR/unpack.sh"

load_config
cat <<EOF

Verify the transfer in OMERO.web on $DST:
  1. Project/Dataset tree, image count and thumbnails match the source.
  2. Spot-check tags, key-value pairs, file attachments, ratings and ROIs on a few images.

Not transferred: Mask ROIs, rendering settings, and annotations other than
MapAnnotations, Tags, FileAnnotations, ratings and CommentAnnotations.

EOF

read -r -p "Delete the local archive $ARCHIVE now? Only do this after verifying. [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    rm -rf "$ARCHIVE"
    info "Deleted $ARCHIVE"
else
    info "Kept $ARCHIVE"
fi
