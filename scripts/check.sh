#!/usr/bin/env bash
# Preflight checks before a transfer: tooling, config, reachability, disk space.

# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() {
    cat <<EOF
Usage: scripts/check.sh [-c CONFIG]

Checks that uv and omero-cli-transfer work, that the config is filled in,
that both servers are reachable on their OMERO port (\$PORT, default 4064, or
the port implied by an ssl:// style host) and that there is disk space for
the archive.

  -c, --config FILE   config file (default: transfer.env)
EOF
}

check_port() {
    local host port
    host="$(host_only "$1")"
    port="$(host_port "$1")"
    if ! command -v nc >/dev/null 2>&1; then
        warn "nc not found, skipping reachability check for $host"
        return 0
    fi
    if nc -z -w 5 "$host" "$port" >/dev/null 2>&1; then
        info "$host:$port is reachable"
    else
        warn "$host:$port is not reachable. Check the hostname and that the server is reachable from your network."
        return 1
    fi
}

parse_args "$@"
require_uv
load_config
print_config

info "Checking omero-cli-transfer"
omero transfer -h >/dev/null 2>&1 ||
    die "'omero transfer' does not work. Run 'uv sync' in $REPO_ROOT and check the zeroc-ice wheel for your platform in pyproject.toml."
info "omero-cli-transfer is installed"

failed=0
check_port "$SRC" || failed=1
check_port "$DST" || failed=1

archive_dir="$(dirname "$ARCHIVE")"
mkdir -p "$archive_dir"
info "Free space at $archive_dir (needs roughly the size of the raw data):"
df -h "$archive_dir" | sed 's/^/    /'

if [[ -e "$ARCHIVE" ]]; then
    warn "$ARCHIVE already exists and will be overwritten by pack"
fi
if [[ "$OBJ" == Plate:* || "$OBJ" == Screen:* ]]; then
    warn "Plates and Screens need omero.policy.binary_access relaxed on $(host_only "$SRC"), or pack will fail"
fi

[[ $failed -eq 0 ]] || die "preflight checks failed"
info "All checks passed"
