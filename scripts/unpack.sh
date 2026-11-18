#!/usr/bin/env bash
# Unpack ARCHIVE into the target server.

# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<EOF
Usage: scripts/unpack.sh [-c CONFIG] [--merge]

Logs in to \$DST, unpacks \$ARCHIVE and logs out again.

  -c, --config FILE   config file (default: transfer.env)
  --merge             add into an existing Project/Dataset with the same name
                      instead of creating a duplicate (same as MERGE=true)
EOF
}

parse_args "$@"
require_uv
load_config
print_config

[[ -e "$ARCHIVE" ]] || die "archive not found: $ARCHIVE (run scripts/pack.sh first)"

omero_login "$DST" "$DST_GROUP"
info "Unpacking $ARCHIVE into $DST${MERGE_FLAG[0]:+ (merge)}"
omero transfer unpack ${MERGE_FLAG[@]+"${MERGE_FLAG[@]}"} "$ARCHIVE"
logout_quietly

info "Unpack finished. Verify the data in OMERO.web on $DST before deleting $ARCHIVE."
