#!/usr/bin/env bash
# Pack OBJ from the source server into ARCHIVE.

# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<EOF
Usage: scripts/pack.sh [-c CONFIG]

Logs in to \$SRC, packs \$OBJ into \$ARCHIVE and logs out again.

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

omero_login "$SRC" "$SRC_GROUP"
info "Packing $OBJ into $ARCHIVE (this downloads every original file and can take a while)"
omero transfer pack "$OBJ" "$ARCHIVE"
logout_quietly

info "Archive written:"
du -sh "$ARCHIVE" | sed 's/^/    /'
