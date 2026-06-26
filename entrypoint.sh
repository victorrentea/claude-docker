#!/usr/bin/env bash
# Two-phase entrypoint:
#   phase 1 (root): apply firewall, then re-exec self as dev via gosu
#   phase 2 (dev):  drop into shell or claude
set -euo pipefail

if [ "$(id -u)" = "0" ]; then
    /usr/local/bin/init-firewall.sh
    exec gosu dev /usr/local/bin/entrypoint.sh "$@"
fi

cd /workspace
git config --global --add safe.directory '*' >/dev/null 2>&1 || true

# Subcommands: `shell` drops to bash, `refresh` re-runs the firewall (requires sudo)
case "${1:-}" in
    shell|bash)
        shift || true
        exec bash "$@"
        ;;
    refresh)
        exec sudo /usr/local/bin/init-firewall.sh
        ;;
esac

exec claude --dangerously-skip-permissions "$@"
