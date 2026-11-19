#!/usr/bin/env bash
# Unpack ARCHIVE into the target server.

# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<EOF
Usage: scripts/unpack.sh [-c CONFIG] [--merge]

Logs in to \$DST as \$DST_USER in \$DST_GROUP, unpacks \$ARCHIVE and logs out
again. The password is prompted for unless \$DST_PASSWORD is set in the
config. With single sign-on, put your session token in both \$DST_USER and
\$DST_PASSWORD.

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

info "Unpacking $ARCHIVE into $(host_only "$DST")${MERGE_FLAG[0]:+ (merge)}"
transfer_on dst unpack ${MERGE_FLAG[@]+"${MERGE_FLAG[@]}"} "$ARCHIVE"

info "Unpack finished. Verify the data in OMERO.web on $(host_only "$DST") before deleting $ARCHIVE."
