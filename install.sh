#!/usr/bin/env bash
# User-level OmaeStrata setup. Omarchy does not run plugin install hooks;
# this script only calls `omarchy plugin add` and writes ~/.config/omarchy/omaestrata.env.
set -euo pipefail

REPO="${OMAESTRATA_REPO:-https://github.com/chrisakira/OmaeStrata.git}"
PLUGIN_ID="io.github.akira.omaestrata"
ENV_FILE="${HOME}/.config/omarchy/omaestrata.env"
PRINT_ENV=0
SKIP_ADD=0
YES=0
MODE=""
SSH_TARGET=""
STRATA_ROOT=""
START_SCRIPT=""
DISK_PATH="/"
PROCESS_PATTERN="strata"
REFRESH_SECONDS="10"

usage() {
  cat <<'EOF'
Install OmaeStrata for Omarchy and write machine paths.

With no arguments, run this in a terminal. It will ask for connection mode,
SSH target (if needed), Strata folder, and start script, then install.

Usage:
  ./install.sh
  ./install.sh [--mode ssh|local] [--ssh-target user@host]
               [--strata-root /path] [--start-script /path] [--disk-path /path]
               [--print-env] [--skip-add] [--yes]

  --print-env   write dotenv to stdout; do not install the plugin
  --skip-add    write env only; assume the plugin is already added
  --yes         non-interactive (requires --mode and --strata-root)

Remove:
  omarchy plugin remove io.github.akira.omaestrata
EOF
}

die() { echo "install.sh: $*" >&2; exit 1; }

valid_path() {
  case "$1" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *..*) return 1 ;;
  esac
  case "$1" in
    *[!A-Za-z0-9_./+-]*) return 1 ;;
  esac
  return 0
}

valid_target() {
  case "$1" in
    *[!A-Za-z0-9_.@%:-]*|"") return 1 ;;
  esac
  return 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --print-env) PRINT_ENV=1 ;;
    --skip-add) SKIP_ADD=1 ;;
    --yes) YES=1 ;;
    --mode) MODE="${2:-}"; shift ;;
    --ssh-target) SSH_TARGET="${2:-}"; shift ;;
    --strata-root) STRATA_ROOT="${2:-}"; shift ;;
    --start-script) START_SCRIPT="${2:-}"; shift ;;
    --disk-path) DISK_PATH="${2:-}"; shift ;;
    --repo) REPO="${2:-}"; shift ;;
    --env-file) ENV_FILE="${2:-}"; shift ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

prompt() {
  local label="$1" current="$2" out=""
  if [ -n "$current" ]; then
    printf '%s [%s]: ' "$label" "$current" >&2
  else
    printf '%s: ' "$label" >&2
  fi
  IFS= read -r out || true
  if [ -n "$out" ]; then printf '%s' "$out"; else printf '%s' "$current"; fi
}

ask_until() {
  local label="$1" current="$2" check="$3" value=""
  while true; do
    value="$(prompt "$label" "$current")"
    if "$check" "$value"; then
      printf '%s' "$value"
      return 0
    fi
    echo "That value is not valid. Try again." >&2
  done
}

is_mode() {
  case "$1" in
    ssh|local) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$PRINT_ENV" -eq 0 ] && [ "$YES" -eq 0 ]; then
  if [ ! -t 0 ]; then
    die "run ./install.sh in a terminal so it can ask for your Strata paths, or pass --mode and --strata-root with --yes"
  fi
  echo "OmaeStrata setup" >&2
  echo "This installs the Omarchy plugin and saves your Strata paths." >&2
  echo >&2
  MODE="$(ask_until 'Is Strata on another machine over SSH, or on this PC? (ssh/local)' "${MODE:-ssh}" is_mode)"
  if [ "$MODE" = "ssh" ]; then
    SSH_TARGET="$(ask_until 'SSH target (user@hostname)' "$SSH_TARGET" valid_target)"
    STRATA_ROOT="$(ask_until 'Strata folder on that machine (absolute path)' "${STRATA_ROOT:-/home/${SSH_TARGET%%@*}/Strata}" valid_path)"
  else
    STRATA_ROOT="$(ask_until 'Strata folder on this PC (absolute path)' "${STRATA_ROOT:-$HOME/Strata}" valid_path)"
  fi
  START_SCRIPT="$(ask_until 'Start script (absolute path)' "${START_SCRIPT:-$STRATA_ROOT/run.sh}" valid_path)"
  DISK_PATH="$(ask_until 'Disk path to measure' "${DISK_PATH:-/}" valid_path)"
  echo >&2
  echo "Connection: $MODE" >&2
  [ "$MODE" = "ssh" ] && echo "SSH target: $SSH_TARGET" >&2
  echo "Strata root: $STRATA_ROOT" >&2
  echo "Start script: $START_SCRIPT" >&2
  echo "Disk path: $DISK_PATH" >&2
  printf 'Write this to %s and install the plugin? [Y/n] ' "$ENV_FILE" >&2
  IFS= read -r confirm || true
  case "$confirm" in
    ''|Y|y|yes|YES) ;;
    *) die "cancelled" ;;
  esac
fi

[ -n "$MODE" ] || die "need --mode ssh|local"
case "$MODE" in
  ssh|local) ;;
  *) die "mode must be ssh or local" ;;
esac

[ -n "$STRATA_ROOT" ] || die "need --strata-root"
valid_path "$STRATA_ROOT" || die "invalid strata root: $STRATA_ROOT"

if [ -z "$START_SCRIPT" ]; then
  START_SCRIPT="$STRATA_ROOT/run.sh"
fi
valid_path "$START_SCRIPT" || die "invalid start script: $START_SCRIPT"
valid_path "$DISK_PATH" || die "invalid disk path: $DISK_PATH"

if [ "$MODE" = "ssh" ]; then
  [ -n "$SSH_TARGET" ] || die "need --ssh-target user@host"
  valid_target "$SSH_TARGET" || die "invalid ssh target: $SSH_TARGET"
fi

emit_env() {
  printf 'MODE=%s\n' "$MODE"
  if [ -n "$SSH_TARGET" ]; then
    printf 'SSH_TARGET=%s\n' "$SSH_TARGET"
  fi
  printf 'STRATA_ROOT=%s\n' "$STRATA_ROOT"
  printf 'START_SCRIPT=%s\n' "$START_SCRIPT"
  printf 'DISK_PATH=%s\n' "$DISK_PATH"
  printf 'PROCESS_PATTERN=%s\n' "$PROCESS_PATTERN"
  printf 'REFRESH_SECONDS=%s\n' "$REFRESH_SECONDS"
}

if [ "$PRINT_ENV" -eq 1 ]; then
  emit_env
  exit 0
fi

command -v omarchy >/dev/null 2>&1 || die "omarchy CLI not found. Install Omarchy 4 first."

if [ "$SKIP_ADD" -eq 0 ]; then
  if omarchy plugin list --json 2>/dev/null | grep -q "$PLUGIN_ID"; then
    echo "Plugin $PLUGIN_ID is already discovered."
  else
    omarchy plugin add "$REPO" --enable --yes
  fi
fi

mkdir -p "$(dirname "$ENV_FILE")"
if [ -f "$ENV_FILE" ]; then
  cp -a "$ENV_FILE" "$ENV_FILE.bak"
  echo "Backed up existing env to $ENV_FILE.bak"
fi
emit_env > "$ENV_FILE"
echo "Wrote $ENV_FILE"
echo "Enable/place the OmaeStrata widget on the bar if it is not visible, then run: omarchy-restart-shell"
echo "Remove later with: omarchy plugin remove $PLUGIN_ID"
