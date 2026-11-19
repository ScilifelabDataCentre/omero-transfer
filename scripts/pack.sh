#!/usr/bin/env bash
# Pack OBJ from the source server into ARCHIVE.

# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<EOF
Usage: scripts/pack.sh [-c CONFIG]

Logs in to \$SRC, packs \$OBJ into \$ARCHIVE and logs out again.
The password is prompted for unless \$SRC_PASSWORD is set in the config.
Set \$SRC_SESSION_KEY instead to join an existing single sign-on session.

  -c, --config FILE   config file (default: transfer.env)
EOF
}

parse_args "$@"
require_uv
load_config
print_config

if [[ -e "$ARCHIVE" ]]; then
    read -r -p "$ARCHIVE already exists. Overwrite? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || die "aborted"
    rm -rf "$ARCHIVE"
fi
mkdir -p "$(dirname "$ARCHIVE")"

info "Packing $OBJ into $ARCHIVE (this downloads every original file and can take a while)"
transfer_on src pack "$OBJ" "$ARCHIVE"

info "Archive written:"
du -sh "$ARCHIVE" | sed 's/^/    /'
