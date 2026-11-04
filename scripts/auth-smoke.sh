#!/usr/bin/env bash
# Run after `nix build .#default`. No sudo or desktop required.
set -euo pipefail
cd "$(dirname "$0")/.."
bin="$(readlink -f result)/bin"
dbus-run-session -- bash -euo pipefail -c '
    bin="$1"
    tmp=$(mktemp -d)
    trap '\''kill "$daemon" 2>/dev/null || true; rm -rf "$tmp"'\'' EXIT
    "$bin/lumen" & daemon=$!
    sleep 1
    "$bin/lumen-auth-gui" next >/dev/null
    "$bin/lumen-askpass" "Smoke test:" >"$tmp/secret" 2>"$tmp/error" & ask=$!
    sleep 0.5
    id=$("$bin/lumen-auth-gui" next | python3 -c '\''import json,sys; print(json.load(sys.stdin)["id"])'\'')
    test -n "$id"
    printf "smoke-secret\n" | "$bin/lumen-auth-gui" submit "$id"
    wait "$ask"
    test "$(cat "$tmp/secret")" = smoke-secret
    if printf "late\n" | "$bin/lumen-auth-gui" submit "$id" 2>/dev/null; then
        echo "late submit accepted" >&2; exit 1
    fi
    "$bin/lumen-askpass" "Deny test:" >"$tmp/secret" 2>"$tmp/error" & ask=$!
    sleep 0.5
    id=$("$bin/lumen-auth-gui" next | python3 -c '\''import json,sys; print(json.load(sys.stdin)["id"])'\'')
    "$bin/lumen-auth-gui" deny "$id"
    if wait "$ask"; then echo "denied request succeeded" >&2; exit 1; fi
    python3 scripts/auth-pty-test.py "$bin"
    echo "auth smoke tests passed"
' -- "$bin"
