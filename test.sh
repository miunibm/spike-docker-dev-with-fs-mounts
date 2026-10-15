#!/usr/bin/env bash
set -e

# ==============================================================================
# Spike Automated Test Runner (POSIX: Linux / macOS)
# Multi-Identity Matrix: Host UID/GID vs. Custom/Vendor UID/GID (1824)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

run_test_iteration() {
  local TEST_UID="$1"
  local TEST_GID="$2"
  local ITERATION_TITLE="$3"

  echo ""
  echo "######################################################################"
  echo " ### [TEST ITERATION] ${ITERATION_TITLE}"
  echo " ### Configured Target -> DEV_UID=${TEST_UID} | DEV_GID=${TEST_GID}"
  echo "######################################################################"

  # Clean previous test files in package mount
  rm -f packages/SamplePackage/file_by_devuser.txt packages/SamplePackage/file_by_root.txt

  # Export environment variables for Docker Compose substitution
  export DEV_UID="${TEST_UID}"
  export DEV_GID="${TEST_GID}"

  echo ""
  echo "[1/6] Building and launching dev-runner container..."
  docker compose build --build-arg DEV_UID="${DEV_UID}" --build-arg DEV_GID="${DEV_GID}" dev-runner
  docker compose up -d --force-recreate dev-runner

  # Guardrail tests
  echo ""
  echo "[2/6] Guardrail Verification..."
  echo "  -> Testing Read-Only Root Filesystem (/app/forbidden.txt)..."
  if docker compose exec dev-runner touch /app/forbidden.txt 2>/dev/null; then
    echo "     [FAIL] Root filesystem was writable!"
    exit 1
  else
    echo "     [PASS] Root filesystem is read-only (as expected)."
  fi

  echo "  -> Testing Tmpfs Scratchpads (/tmp, /app/temp, /app/logs)..."
  docker compose exec dev-runner touch /tmp/test_scratch.txt
  docker compose exec dev-runner touch /app/temp/engine.lock
  docker compose exec dev-runner touch /app/logs/runtime.log
  echo "     [PASS] Tmpfs scratchpads writable by container user."

  echo "  -> Testing Read-Only Config (/app/config/application.properties)..."
  if docker compose exec dev-runner touch /app/config/application.properties 2>/dev/null; then
    echo "     [FAIL] Config file was writable!"
    exit 1
  else
    echo "     [PASS] Config file is read-only (as expected)."
  fi

  # Package bind mount write tests
  echo ""
  echo "[3/6] Creating files in package bind mount (/app/packages/SamplePackage)..."
  echo "  -> Creating file as default container user (UID ${DEV_UID})..."
  docker compose exec dev-runner touch /app/packages/SamplePackage/file_by_devuser.txt

  echo "  -> Creating file as container root user (-u root / UID 0)..."
  docker compose exec -u root dev-runner touch /app/packages/SamplePackage/file_by_root.txt

  # Inspect BEFORE sweeper
  echo ""
  echo "[4/6] State BEFORE Sweeper:"
  echo "  [GUEST VIEW] (docker compose exec dev-runner ls -lan /app/packages/SamplePackage/):"
  docker compose exec dev-runner ls -lan /app/packages/SamplePackage/
  
  echo ""
  echo "  [HOST VIEW]  (host ls -lan packages/SamplePackage/):"
  ls -lan packages/SamplePackage/

  # Run sweeper
  echo ""
  echo "[5/6] Executing Namespace-Aware Sweeper..."
  docker compose --profile sweeper run --rm sweeper

  # Inspect AFTER sweeper
  echo ""
  echo "[6/6] State AFTER Sweeper:"
  echo "  [GUEST VIEW] (docker compose exec dev-runner ls -lan /app/packages/SamplePackage/):"
  docker compose exec dev-runner ls -lan /app/packages/SamplePackage/

  echo ""
  echo "  [HOST VIEW]  (host ls -lan packages/SamplePackage/):"
  ls -lan packages/SamplePackage/
}

echo "======================================================================"
echo " Docker Dev with Filesystem Mounts Spike: Automated Test Suite"
echo "======================================================================"

HOST_CURRENT_UID="$(id -u)"
HOST_CURRENT_GID="$(id -g)"

# Iteration 1: Current Host UID/GID (e.g. 501:20 on macOS or 1000:1000 on Linux)
run_test_iteration "${HOST_CURRENT_UID}" "${HOST_CURRENT_GID}" "Iteration 1: Host Identity (UID=${HOST_CURRENT_UID}, GID=${HOST_CURRENT_GID})"

# Iteration 2: Vendor / Disjoint Identity (UID=1824, GID=1824)
run_test_iteration "1824" "1824" "Iteration 2: Vendor Identity (UID=1824, GID=1824)"

echo ""
echo "======================================================================"
echo " [SUMMARY OF RESULTS]"
echo "======================================================================"
echo " - Iteration 1 (Host UID/GID ${HOST_CURRENT_UID}:${HOST_CURRENT_GID}):"
echo "     * Guest: Created as ${HOST_CURRENT_UID}:${HOST_CURRENT_GID}"
echo "     * Host:  Visible as ${HOST_CURRENT_UID}:${HOST_CURRENT_GID}"
echo " - Iteration 2 (Vendor UID/GID 1824:1824):"
echo "     * Guest: Created as 1824:1824"
echo "     * Host on macOS/Win: Mapped by hypervisor bridge to host user (${HOST_CURRENT_UID}:${HOST_CURRENT_GID})"
echo "     * Host on Rootless Linux: Appears as subordinate UID (e.g. 166535), normalized to ${HOST_CURRENT_UID} by sweeper"
echo "======================================================================"
