# shellcheck shell=bash disable=SC2034  # MERGE_FLAG is read by unpack.sh
# Shared helpers for the transfer scripts. Source this file, do not execute it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-$REPO_ROOT/transfer.env}"
MERGE_FLAG=()
CONFIG_KEYS=(SRC DST SRC_USER SRC_PASSWORD SRC_SESSION_KEY DST_USER DST_PASSWORD DST_SESSION_KEY GROUP SRC_GROUP DST_GROUP OBJ ARCHIVE MERGE PORT)
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

    SRC_GROUP="${SRC_GROUP:-${GROUP:-}}"
    DST_GROUP="${DST_GROUP:-${GROUP:-}}"
    SRC_USER="${SRC_USER:-}"
    DST_USER="${DST_USER:-}"
    SRC_PASSWORD="${SRC_PASSWORD:-}"
    DST_PASSWORD="${DST_PASSWORD:-}"
    SRC_SESSION_KEY="${SRC_SESSION_KEY:-}"
    DST_SESSION_KEY="${DST_SESSION_KEY:-}"
    MERGE="${MERGE:-false}"
    PORT="${PORT:-4064}"
    ARCHIVE="${ARCHIVE:-}"
    ARCHIVE="${ARCHIVE/#\~/$HOME}"

    validate_config
    if [[ "$MERGE" == true ]]; then
        MERGE_FLAG=(--merge)
    fi
}

# True when a value is present and is not still a <placeholder>.
is_set() { [[ -n "$1" && "$1" != *"<"*">"* ]]; }

# Checks the credentials for one server. A session key replaces the username
# and password, but not the group, which is switched to separately.
validate_side() {
    local label="$1" key="$2" user="$3" password="$4" group="$5" errors=0
    if is_set "$key"; then
        is_set "$user" &&
            warn "${label}_USER is unused because ${label}_SESSION_KEY is set"
        is_set "$password" &&
            warn "${label}_PASSWORD is unused because ${label}_SESSION_KEY is set"
        return 0
    fi
    require_value "${label}_USER" "$user" "$label" || errors=1
    require_value "${label}_GROUP" "$group" "$label" || errors=1
    return $errors
}

require_value() {
    local name="$1" val="$2" label="$3"
    if [[ -z "$val" ]]; then
        warn "$name is not set (or set ${label}_SESSION_KEY instead)"
        return 1
    elif [[ "$val" == *"<"*">"* ]]; then
        warn "$name still holds a placeholder: $val"
        return 1
    fi
    return 0
}

validate_config() {
    local key val errors=0
    for key in SRC DST OBJ ARCHIVE; do
        val="${!key:-}"
        if [[ -z "$val" ]]; then
            warn "$key is not set"
            errors=1
        elif [[ "$val" == *"<"*">"* ]]; then
            warn "$key still holds a placeholder: $val"
            errors=1
        fi
    done
    validate_side SRC "$SRC_SESSION_KEY" "$SRC_USER" "$SRC_PASSWORD" "$SRC_GROUP" || errors=1
    validate_side DST "$DST_SESSION_KEY" "$DST_USER" "$DST_PASSWORD" "$DST_GROUP" || errors=1
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
    printf '    %-10s %s (group %s)\n' "source" "$SRC" "$SRC_GROUP"
    printf '    %-10s %s\n' "src_user" "$(auth_label "$SRC_SESSION_KEY" "$SRC_USER")"
    printf '    %-10s %s (group %s)\n' "target" "$DST" "$DST_GROUP"
    printf '    %-10s %s\n' "dst_user" "$(auth_label "$DST_SESSION_KEY" "$DST_USER")"
    printf '    %-10s %s\n' "object" "$OBJ"
    printf '    %-10s %s\n' "archive" "$ARCHIVE"
    printf '    %-10s %s\n' "merge" "$MERGE"
}

# Never prints the session key itself.
auth_label() {
    if [[ -n "$1" ]]; then
        printf '(session key)'
    else
        printf '%s' "$2"
    fi
}

require_uv() {
    command -v uv >/dev/null 2>&1 ||
        die "uv is not installed, see https://docs.astral.sh/uv/getting-started/installation/"
}

# Only logs out of sessions we created ourselves. A session joined with a
# session key belongs to the user's browser login and must survive.
logout_quietly() {
    [[ "$LOGGED_IN" == true ]] || return 0
    omero logout >/dev/null 2>&1 || true
    LOGGED_IN=false
}
trap logout_quietly EXIT

# Usage: omero_login HOST GROUP USER [PASSWORD]
omero_login() {
    local host="$1" group="$2" user="$3" password="${4:-}"
    info "Logging in to $host as $user (group $group)"
    if [[ -n "$password" ]]; then
        omero login -u "$user" -s "$host" -p "$PORT" -g "$group" -w "$password"
    else
        omero login -u "$user" -s "$host" -p "$PORT" -g "$group"
    fi
    LOGGED_IN=true
}

# Usage: transfer_on src|dst ARGS...
# With a session key, joins the existing session and switches it to the
# configured group. Otherwise logs in, runs the command and logs out again.
transfer_on() {
    local side="$1"; shift
    local host group user password key
    if [[ "$side" == src ]]; then
        host="$SRC" group="$SRC_GROUP" user="$SRC_USER"
        password="$SRC_PASSWORD" key="$SRC_SESSION_KEY"
    else
        host="$DST" group="$DST_GROUP" user="$DST_USER"
        password="$DST_PASSWORD" key="$DST_SESSION_KEY"
    fi

    if [[ -n "$key" ]]; then
        info "Joining the session on $host with a session key"
        if [[ -n "$group" ]]; then
            # omero ignores -g when a session key is used, so set the group
            # on the session itself before transferring.
            info "Switching the session on $host to group $group"
            omero sessions -s "$host" -p "$PORT" -k "$key" group "$group"
        fi
        omero transfer -s "$host" -p "$PORT" -k "$key" "$@"
    else
        omero_login "$host" "$group" "$user" "$password"
        omero transfer "$@"
        logout_quietly
    fi
}
