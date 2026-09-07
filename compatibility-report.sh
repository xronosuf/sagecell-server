#!/usr/bin/env bash
set -Eeuo pipefail

image="${1:-docker.io/sagemath/sagemath:latest}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages_file="$repo_dir/packages-known-good.txt"
requirements_file="$repo_dir/requirements-known-good.txt"

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman is required to run this compatibility report." >&2
    exit 2
fi

for file in "$packages_file" "$requirements_file"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: required file not found: $file" >&2
        exit 2
    fi
done

echo "============================================================"
echo "SAGECELL SERVER — SAGEMATH COMPATIBILITY REPORT"
echo "============================================================"
echo
echo "Target SageMath image:"
echo "  $image"
echo
echo "This is a diagnostic report, not a compatibility guarantee."
echo "It compares the repository's reviewed baseline with the selected"
echo "SageMath image. A full build and smoke test are still required."
echo

podman run --rm \
    --user root \
    --entrypoint /bin/bash \
    -v "$packages_file:/tmp/packages-known-good.txt:ro" \
    -v "$requirements_file:/tmp/requirements-known-good.txt:ro" \
    "$image" \
    -lc '
set -Eeuo pipefail

apt-get update >/dev/null

echo "============================================================"
echo "TARGET ENVIRONMENT"
echo "============================================================"
echo
sage --version || true
python_version="$(sage -python -c "import platform; print(platform.python_version())" 2>/dev/null || true)"
echo "Sage Python: ${python_version:-unknown}"
echo

echo "============================================================"
echo "OPERATING-SYSTEM PACKAGE DIFFERENCES"
echo "============================================================"
echo

os_missing=0
os_missing_names=""

while IFS= read -r line; do
    case "$line" in
        ""|\#*) continue ;;
    esac

    pkg=${line%%=*}
    pinned=${line#*=}

    if apt-cache madison "$pkg" | awk "{print \$3}" | grep -Fxq "$pinned"; then
        printf "OK       %-28s %s\n" "$pkg" "$pinned"
    else
        candidate="$(apt-cache policy "$pkg" | awk "/Candidate:/ {print \$2; exit}")"
        [ -n "$candidate" ] || candidate="NONE"
        printf "UPDATE   %-28s pinned=%s  available=%s\n" "$pkg" "$pinned" "$candidate"
        os_missing=$((os_missing + 1))
        os_missing_names="${os_missing_names}${pkg}|${pinned}|${candidate}\n"
    fi
done < /tmp/packages-known-good.txt

echo
echo "============================================================"
echo "PYTHON PACKAGE DIFFERENCES"
echo "============================================================"
echo

python_report="$(sage -python - /tmp/requirements-known-good.txt <<"PYREPORT"
from importlib import metadata
from pathlib import Path
import sys

path = Path(sys.argv[1])
mismatch_count = 0
absent_count = 0
check_count = 0
rows = []

for raw in path.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue

    if "==" not in line:
        rows.append(("CHECK", line, "unparsed baseline constraint", "unknown"))
        check_count += 1
        continue

    name, pinned = line.split("==", 1)
    try:
        installed = metadata.version(name)
    except metadata.PackageNotFoundError:
        installed = "NOT-IN-BASE-IMAGE"
        status = "ABSENT"
        absent_count += 1
    else:
        if installed == pinned:
            status = "OK"
        else:
            status = "UPDATE"
            mismatch_count += 1

    rows.append((status, name, pinned, installed))

for status, name, pinned, installed in rows:
    print(f"{status:<8} {name:<28} pinned={pinned}  base-image={installed}")

print(f"__PY_MISMATCH_COUNT__={mismatch_count}")
print(f"__PY_ABSENT_COUNT__={absent_count}")
print(f"__PY_CHECK_COUNT__={check_count}")
PYREPORT
)"

printf "%s\n" "$python_report" | grep -v "^__PY_"
py_mismatch="$(printf "%s\n" "$python_report" | sed -n "s/^__PY_MISMATCH_COUNT__=//p")"
py_absent="$(printf "%s\n" "$python_report" | sed -n "s/^__PY_ABSENT_COUNT__=//p")"
py_check="$(printf "%s\n" "$python_report" | sed -n "s/^__PY_CHECK_COUNT__=//p")"
[ -n "$py_mismatch" ] || py_mismatch=0
[ -n "$py_absent" ] || py_absent=0
[ -n "$py_check" ] || py_check=0

echo
echo "============================================================"
echo "ACTION SUMMARY"
echo "============================================================"
echo

echo "OS package pins requiring review: $os_missing"
if [ "$os_missing" -gt 0 ]; then
    printf "%b" "$os_missing_names" | while IFS="|" read -r pkg pinned candidate; do
        [ -n "$pkg" ] || continue
        echo "  - $pkg: reviewed $pinned -> repository candidate $candidate"
    done
else
    echo "  - none"
fi

echo
echo "Python installed-version mismatches requiring review: $py_mismatch"
printf "%s\n" "$python_report" \
    | awk "\$1 == \"UPDATE\" {sub(/^[^ ]+[ ]+/, \"\"); print \"  - \" \$0}"
if [ "$py_mismatch" -eq 0 ]; then
    echo "  - none"
fi

echo
echo "Python baseline packages absent from the base image: $py_absent"
printf "%s\n" "$python_report" \
    | awk "\$1 == \"ABSENT\" {sub(/^[^ ]+[ ]+/, \"\"); print \"  - \" \$0}"
if [ "$py_absent" -eq 0 ]; then
    echo "  - none"
fi

if [ "$py_check" -gt 0 ]; then
    echo
echo "Python constraints needing manual parsing/checking: $py_check"
    printf "%s\n" "$python_report" \
        | awk "\$1 == \"CHECK\" {sub(/^[^ ]+[ ]+/, \"\"); print \"  - \" \$0}"
fi

echo
echo "Interpretation:"
echo "  - UPDATE means the selected base image already contains a different version."
echo "  - ABSENT means the package is not in the base image; this is not itself an incompatibility."
echo "  - the experimental build may install absent direct packages and resolve their dependencies."
echo "  - available/base-image values are observations, not minimum required versions."
echo "  - source/API compatibility cannot be proven by version comparison alone."
echo "  - finish by building the image and running smoke-test.sh."
'

echo
echo "============================================================"
echo "COMPATIBILITY REPORT COMPLETE"
echo "============================================================"
