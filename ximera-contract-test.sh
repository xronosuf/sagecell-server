#!/usr/bin/env bash
set -Eeuo pipefail

service_url="${1:-${SAGECELL_SERVICE_URL:-http://127.0.0.1:8888/service}}"
support_trace="${SAGECELL_SUPPORT_TRACE:-xr-contract-test-20260907}"
timeout="${SAGECELL_CONTRACT_TIMEOUT:-60}"

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required." >&2
    exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required." >&2
    exit 2
fi

workdir="$(mktemp -d)"
cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

success_body="$workdir/success.json"
error_body="$workdir/error.json"

cat > "$workdir/ximera-like.sage" <<'SAGE'
# This program intentionally resembles the sort of exact symbolic/numeric
# computation a trusted Ximera-side service may send to SageCell after request
# authentication/authorization has already succeeded.

x = var('x')

polynomial = expand((x + 3) * (x - 5))
value_at_7 = polynomial.subs(x=7)

M = matrix(QQ, [[1, 2], [3, 5]])
determinant = M.det()
inverse_check = M * M.inverse()

rational_value = (QQ(7) / 12) + (QQ(5) / 18)

derivative_value = diff(x^4 - 3*x^2 + 2*x - 9, x).subs(x=2)

assert value_at_7 == 20
assert determinant == -1
assert inverse_check == identity_matrix(QQ, 2)
assert rational_value == QQ(31) / 36
assert derivative_value == 22

print("XRONOS_CONTRACT_OK")
print("polynomial_value=20")
print("matrix_determinant=-1")
print("rational_value=31/36")
print("derivative_value=22")
SAGE

cat > "$workdir/expected-error.sage" <<'SAGE'
raise RuntimeError("XRONOS_EXPECTED_SAGE_ERROR")
SAGE

echo "============================================================"
echo "XIMERA / TRUSTED-UPSTREAM SAGECELL CONTRACT TEST"
echo "============================================================"
echo
echo "Service URL:"
echo "  $service_url"
echo
echo "Support trace header:"
echo "  X-Xronos-Support-Trace: $support_trace"
echo
echo "This test assumes authentication/authorization has already happened"
echo "upstream. It validates the SageCell-facing request/response contract."
echo

echo "============================================================"
echo "1. SUCCESSFUL XIMERA-LIKE COMPUTATION"
echo "============================================================"
echo

success_status="$(
    curl \
        --max-time "$timeout" \
        --silent \
        --show-error \
        -o "$success_body" \
        -w '%{http_code}' \
        -H "X-Xronos-Support-Trace: $support_trace" \
        --data-urlencode "code@$workdir/ximera-like.sage" \
        "$service_url"
)"

if [ "$success_status" != "200" ]; then
    echo "ERROR: expected HTTP 200, received HTTP $success_status" >&2
    echo "Response body:" >&2
    cat "$success_body" >&2 || true
    exit 1
fi

python3 - "$success_body" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as exc:
    raise SystemExit(f"Response was not valid JSON: {exc}")

if data.get("success") is not True:
    raise SystemExit(f"Expected success=true, received: {data!r}")

stdout = data.get("stdout", "")
expected = [
    "XRONOS_CONTRACT_OK",
    "polynomial_value=20",
    "matrix_determinant=-1",
    "rational_value=31/36",
    "derivative_value=22",
]

missing = [item for item in expected if item not in stdout]
if missing:
    raise SystemExit(
        "Successful response was missing expected output markers: "
        + ", ".join(missing)
        + f"\nstdout={stdout!r}"
    )

reply = data.get("execute_reply")
if not isinstance(reply, dict):
    raise SystemExit("Successful response did not contain execute_reply object.")

if reply.get("status") != "ok":
    raise SystemExit(f"Expected execute_reply.status='ok', received: {reply!r}")

print("HTTP 200: PASS")
print("JSON response: PASS")
print("success=true: PASS")
print("exact symbolic/numeric computations: PASS")
print("execute_reply.status=ok: PASS")
PY

echo
echo "Successful Ximera-like request: PASS"

echo
echo "============================================================"
echo "2. NORMAL SAGE EXECUTION ERROR CONTRACT"
echo "============================================================"
echo

error_status="$(
    curl \
        --max-time "$timeout" \
        --silent \
        --show-error \
        -o "$error_body" \
        -w '%{http_code}' \
        -H "X-Xronos-Support-Trace: $support_trace-error" \
        --data-urlencode "code@$workdir/expected-error.sage" \
        "$service_url"
)"

if [ "$error_status" != "200" ]; then
    echo "ERROR: a normal Sage execution error should still return HTTP 200." >&2
    echo "Received HTTP $error_status" >&2
    echo "Response body:" >&2
    cat "$error_body" >&2 || true
    exit 1
fi

python3 - "$error_body" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as exc:
    raise SystemExit(f"Error response was not valid JSON: {exc}")

if data.get("success") is not False:
    raise SystemExit(f"Expected success=false for Sage execution error: {data!r}")

serialized = json.dumps(data)
if "XRONOS_EXPECTED_SAGE_ERROR" not in serialized:
    raise SystemExit(
        "Expected Sage error marker was not present in the response: "
        + serialized
    )

print("HTTP 200 for Sage execution failure: PASS")
print("JSON response: PASS")
print("success=false: PASS")
print("Sage error detail preserved: PASS")
PY

echo
echo "Normal Sage execution error contract: PASS"

echo
echo "============================================================"
echo "CONTRACT TEST RESULT"
echo "============================================================"
echo
echo "Trusted-upstream / Ximera-style SageCell contract: PASS"
echo
echo "Validated assumptions:"
echo "  - POST application/x-www-form-urlencoded-style code requests are accepted."
echo "  - X-Xronos-Support-Trace may accompany the request without changing results."
echo "  - successful Sage execution returns HTTP 200 JSON with success=true."
echo "  - execute_reply.status is ok on successful execution."
echo "  - exact symbolic, matrix, rational, and derivative computations work."
echo "  - normal Sage execution errors return HTTP 200 JSON with success=false."
echo
echo "This script does NOT validate authentication itself. It is intentionally"
echo "the contract test for the boundary after an upstream service has already"
echo "authenticated/authorized the request."
