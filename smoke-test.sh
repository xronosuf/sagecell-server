#!/usr/bin/env bash
set -Eeuo pipefail

image="${1:-sagecell-server:local}"
container="sagecell-smoke-$$"
port="${SAGECELL_TEST_PORT:-18892}"

tmp75="$(mktemp)"
tmp200000="$(mktemp)"
tmp200001="$(mktemp)"
resp75="$(mktemp)"
resp200000="$(mktemp)"
resp200001="$(mktemp)"

cleanup() {
    podman rm -f "$container" >/dev/null 2>&1 || true
    rm -f \
        "$tmp75" \
        "$tmp200000" \
        "$tmp200001" \
        "$resp75" \
        "$resp200000" \
        "$resp200001"
}
trap cleanup EXIT

make_valid_program() {
    local total_length="$1"
    local output_file="$2"

    python3 - "$total_length" "$output_file" <<'PY'
from pathlib import Path
import sys

total = int(sys.argv[1])
output = Path(sys.argv[2])

prefix = "print(len('"
suffix = "'))"
payload_length = total - len(prefix) - len(suffix)

if payload_length < 0:
    raise SystemExit("Requested total program length is too small.")

code = prefix + ("x" * payload_length) + suffix

assert len(code) == total
output.write_text(code)
PY
}

echo "Starting temporary SageCell container..."

podman run -d \
    --name "$container" \
    -p "127.0.0.1:${port}:8888" \
    "$image" \
    >/dev/null

echo "Waiting for SageCell..."

ready=0
for i in $(seq 1 120); do
    if curl \
        --max-time 5 \
        -fsS \
        --data-urlencode 'code=print(2+2)' \
        "http://127.0.0.1:${port}/service" \
        | grep -q '"4\\n"'
    then
        ready=1
        break
    fi

    sleep 2
done

if [ "$ready" -ne 1 ]; then
    echo "SageCell failed to become ready; recent logs:" >&2
    podman logs --tail 250 "$container" >&2 || true
    exit 1
fi

echo "Basic calculation: PASS"

basic="$(
    curl \
        --max-time 30 \
        -fsS \
        --data-urlencode 'code=2+3' \
        "http://127.0.0.1:${port}/service"
)"

python3 - "$basic" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])

if not data.get("success"):
    raise SystemExit("Bare-expression request did not report success.")

if "5" not in json.dumps(data):
    raise SystemExit("Expected expression result 5 was not returned.")
PY

echo "Bare expression: PASS"

make_valid_program 75000 "$tmp75"

status="$(
    curl \
        --max-time 90 \
        -sS \
        -o "$resp75" \
        -w '%{http_code}' \
        --data-urlencode "code@${tmp75}" \
        "http://127.0.0.1:${port}/service"
)"

test "$status" = "200"

python3 - "$resp75" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if not data.get("success"):
    raise SystemExit("75,000-character request did not report success.")

if data.get("stdout", "").strip() != "74986":
    raise SystemExit(
        "Unexpected 75,000-character result: "
        + repr(data.get("stdout"))
    )
PY

echo "75,000-character request: PASS"

make_valid_program 200000 "$tmp200000"

status="$(
    curl \
        --max-time 120 \
        -sS \
        -o "$resp200000" \
        -w '%{http_code}' \
        --data-urlencode "code@${tmp200000}" \
        "http://127.0.0.1:${port}/service"
)"

test "$status" = "200"

python3 - "$resp200000" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if not data.get("success"):
    raise SystemExit("200,000-character request did not report success.")

if data.get("stdout", "").strip() != "199986":
    raise SystemExit(
        "Unexpected 200,000-character result: "
        + repr(data.get("stdout"))
    )
PY

echo "200,000-character exact boundary: PASS"

python3 - "$tmp200001" <<'PY'
from pathlib import Path
import sys

code = "#" * 200001
assert len(code) == 200001
Path(sys.argv[1]).write_text(code)
PY

status="$(
    curl \
        --max-time 30 \
        -sS \
        -o "$resp200001" \
        -w '%{http_code}' \
        --data-urlencode "code@${tmp200001}" \
        "http://127.0.0.1:${port}/service"
)"

test "$status" = "413"

grep -Fq \
    'Max code size is 200000 characters' \
    "$resp200001"

echo "200,001-character rejection: PASS"

commit="$(
    podman exec "$container" \
        git -C /opt/sagecell rev-parse HEAD
)"

test "$commit" = "281fc2356c52929fb08f4cd4cbfd8655e4ddd236"

echo "Pinned SageCell commit: PASS"

echo
echo "SageCell smoke test passed."
