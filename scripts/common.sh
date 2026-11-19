# shellcheck shell=bash disable=SC2034  # MERGE_FLAG is read by unpack.sh
# Shared helpers for the transfer scripts. Source this file, do not execute it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-$REPO_ROOT/transfer.env}"
MERGE_FLAG=()
CONN_FLAGS=()
CONFIG_KEYS=(SRC DST SRC_USER SRC_PASSWORD SRC_GROUP DST_USER DST_PASSWORD DST_GROUP OBJ ARCHIVE MERGE PORT)
LOGGED_IN=false

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

# The zeroc-ice 3.6.5 sources trigger SyntaxWarnings on Python 3.12.
omero() {
    PYTHONWARNINGS="ignore::SyntaxWarning" uv run --quiet --project "$REPO_ROOT" omero "$@"
}

# Usage: parse_args "$@"   (handles -c/--config, --merge, -h/--help)
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c | --config)
                [[ $# -ge 2 ]] || die "$1 needs a file argument"
                CONFIG="$2"
                shift 2
                ;;
            --merge)
                MERGE=true
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) die "unknown argument: $1 (see --help)" ;;
        esac
    done
}

# Reads KEY=VALUE lines. Variables already set in the environment win over the file.
load_config() {
    [[ -f "$CONFIG" ]] || die "config file not found: $CONFIG (copy transfer.env.example to transfer.env first)"

    local line key val
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        [[ "$line" == *=* ]] || continue
        key="$(echo "${line%%=*}" | xargs)"
        val="$(echo "${line#*=}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        val="${val#\"}" val="${val%\"}"
        val="${val#\'}" val="${val%\'}"
        [[ " ${CONFIG_KEYS[*]} " == *" $key "* ]] || die "unknown key '$key' in $CONFIG"
        if [[ -z "${!key:-}" ]]; then
            printf -v "$key" '%s' "$val"
        fi
    done <"$CONFIG"

    SRC_GROUP="${SRC_GROUP:-}"
    DST_GROUP="${DST_GROUP:-}"
    SRC_USER="${SRC_USER:-}"
    DST_USER="${DST_USER:-}"
    SRC_PASSWORD="${SRC_PASSWORD:-}"
    DST_PASSWORD="${DST_PASSWORD:-}"
    MERGE="${MERGE:-false}"
    PORT="${PORT:-4064}"
    ARCHIVE="${ARCHIVE:-}"
    ARCHIVE="${ARCHIVE/#\~/$HOME}"

    validate_config
    if [[ "$MERGE" == true ]]; then
        MERGE_FLAG=(--merge)
    fi
}

# Strips a scheme:// prefix, any /path and any :port, leaving a bare hostname
# for things that cannot take a URL, such as nc and the progress messages.
host_only() {
    local h="${1#*://}"
    h="${h%%/*}"
    printf '%s' "${h%:*}"
}

# Port a host string implies: an explicit :port wins, then the scheme default
# omero itself uses, then PORT.
host_port() {
    local h="$1"
    if [[ "$h" =~ :([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return
    fi
    case "${h%%://*}" in
        ssl) printf '4064' ;;
        tcp) printf '4063' ;;
        ws) printf '80' ;;
        wss) printf '443' ;;
        *) printf '%s' "$PORT" ;;
    esac
}

# Builds the -s/-p flags for one host. omero parses a trailing :port out of the
# server string itself and then dies with "Port specified twice" if -p is also
# given, and it derives the port from the scheme of a URL host, so -p is only
# useful for a plain hostname.
conn_flags() {
    CONN_FLAGS=(-s "$1")
    [[ "$1" == *://* || "$1" =~ :[0-9]+$ ]] || CONN_FLAGS+=(-p "$PORT")
}

validate_config() {
    local key val errors=0
    # Passwords are deliberately absent: an empty one means prompt interactively.
    for key in SRC DST SRC_USER SRC_GROUP DST_USER DST_GROUP OBJ ARCHIVE; do
        val="${!key:-}"
        if [[ -z "$val" ]]; then
            warn "$key is not set"
            errors=1
        elif [[ "$val" == *"<"*">"* ]]; then
            warn "$key still holds a placeholder: $val"
            errors=1
        fi
    done
    if [[ -n "${OBJ:-}" && ! "$OBJ" =~ ^(Image|Dataset|Project|Plate|Screen):[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ ]]; then
        warn "OBJ must look like Image:19, Dataset:1,4,7 or Image:19-25 (got '$OBJ')"
        errors=1
    fi
    [[ "$MERGE" == true || "$MERGE" == false ]] || {
        warn "MERGE must be true or false (got '$MERGE')"
        errors=1
    }
    [[ $errors -eq 0 ]] || die "fix $CONFIG and try again"
}

print_config() {
    info "Config: $CONFIG"
    printf '    %-10s %s (group %s)\n' "source" "$(host_only "$SRC")" "$SRC_GROUP"
    printf '    %-10s %s\n' "src_user" "$(user_label "$SRC_USER")"
    printf '    %-10s %s (group %s)\n' "target" "$(host_only "$DST")" "$DST_GROUP"
    printf '    %-10s %s\n' "dst_user" "$(user_label "$DST_USER")"
    printf '    %-10s %s\n' "object" "$OBJ"
    printf '    %-10s %s\n' "archive" "$ARCHIVE"
    printf '    %-10s %s\n' "merge" "$MERGE"
}

# An SSO token used as the username is a secret, so never echo it.
user_label() {
    if [[ "$1" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        printf '(session token)'
    else
        printf '%s' "$1"
    fi
}

require_uv() {
    command -v uv >/dev/null 2>&1 ||
        die "uv is not installed, see https://docs.astral.sh/uv/getting-started/installation/"
}

# Only logs out of sessions we created ourselves. check.sh sources this file
# without ever logging in, and must not kill a session it did not start.
logout_quietly() {
    [[ "$LOGGED_IN" == true ]] || return 0
    omero logout >/dev/null 2>&1 || true
    LOGGED_IN=false
}
trap logout_quietly EXIT

# Usage: omero_login HOST GROUP USER [PASSWORD]
omero_login() {
    local host="$1" group="$2" user="$3" password="${4:-}"
    info "Logging in to $(host_only "$host") as $(user_label "$user") (group $group)"
    conn_flags "$host"
    if [[ -n "$password" ]]; then
        omero login -u "$user" "${CONN_FLAGS[@]}" -g "$group" -w "$password"
    else
        omero login -u "$user" "${CONN_FLAGS[@]}" -g "$group"
    fi
    LOGGED_IN=true
}

# Usage: transfer_on src|dst ARGS...
# Logs in to that side with its own user and group, runs the command and logs
# out again. An SSO token works here as both the username and the password.
transfer_on() {
    local side="$1"; shift
    local host group user password
    if [[ "$side" == src ]]; then
        host="$SRC" group="$SRC_GROUP" user="$SRC_USER" password="$SRC_PASSWORD"
    else
        host="$DST" group="$DST_GROUP" user="$DST_USER" password="$DST_PASSWORD"
    fi

    omero_login "$host" "$group" "$user" "$password"
    omero transfer "$@"
    logout_quietly
}
