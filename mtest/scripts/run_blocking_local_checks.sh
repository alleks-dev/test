#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run_blocking_local_checks.sh [--strict] [--skip-host] [--skip-target]

Runs the blocking local verification bundle for architecture-sensitive changes:
1. Architecture invariants
2. Host build/tests when present
3. Target build when present

Options:
  --strict      Treat low-severity architecture findings as blocking too.
  --skip-host   Skip host configure/build/test steps.
  --skip-target Skip target build step.
EOF
}

strict_mode=0
skip_host=0
skip_target=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      strict_mode=1
      ;;
    --skip-host)
      skip_host=1
      ;;
    --skip-target)
      skip_target=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_HOST_DIR="${BUILD_HOST_DIR:-build-host}"
TARGET_BUILD_DIR="${TARGET_BUILD_DIR:-build-target}"

run_step() {
  local title="$1"
  shift
  echo
  echo "==> ${title}"
  "$@"
}

cd "${ROOT_DIR}"

if [[ "${strict_mode}" -eq 1 ]]; then
  run_step "Architecture invariants (strict)" \
    env ARCH_BLOCKING_SEVERITIES=high,medium,low bash ./scripts/check_arch_invariants.sh
else
  run_step "Architecture invariants" \
    bash ./scripts/check_arch_invariants.sh
fi

if [[ "${skip_host}" -eq 0 ]]; then
  if [[ -f "test/host/CMakeLists.txt" ]]; then
    run_step "Configure host tests" \
      cmake -S test/host -B "${BUILD_HOST_DIR}"
    run_step "Build host tests" \
      cmake --build "${BUILD_HOST_DIR}" --parallel
    if [[ -f "${BUILD_HOST_DIR}/CTestTestfile.cmake" || -d "${BUILD_HOST_DIR}" ]]; then
      run_step "Run host tests" \
        ctest --test-dir "${BUILD_HOST_DIR}" --output-on-failure
    fi
  else
    echo
    echo "==> Skipping host checks (test/host not present yet)"
  fi
else
  echo
  echo "==> Skipping host checks"
fi

if [[ "${skip_target}" -eq 0 ]]; then
  if [[ -f "CMakeLists.txt" ]]; then
    echo
    echo "==> Target build step is a placeholder until ESP-IDF skeleton exists"
    echo "    expected future command: idf.py -B ${TARGET_BUILD_DIR} build"
  else
    echo
    echo "==> Skipping target checks (project skeleton not present yet)"
  fi
else
  echo
  echo "==> Skipping target checks"
fi

echo
echo "Blocking local checks completed"
