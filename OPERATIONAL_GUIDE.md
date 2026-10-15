# Operational Guide: Standalone Alpine-Based Exploratory Tests

This guide provides standalone, entitlement-free test procedures using minimal Alpine images to investigate filesystem permissions, guardrails (`read_only: true`, `tmpfs`, `cap_drop: [ALL]`), and user identity mapping across Windows, macOS, and Linux Rootless environments.

---

## 1. Test Setup & Build

1. Copy the environment configuration:
   ```bash
   cp EXAMPLE.env .env
   # On Windows PowerShell: copy EXAMPLE.env .env
   ```
2. Build and launch the exploratory test runner container:
   ```bash
   docker compose up -d --build dev-runner
   ```
3. Inspect running user identity inside container:
   ```bash
   docker compose exec dev-runner id
   # Output: uid=1824(devuser) gid=1824(devgroup) groups=1824(devgroup)
   ```

---

## 2. Guardrail Verification Tests

### Test G1: Read-Only Root Filesystem Verification
Attempt to create a file in the root filesystem.
```bash
docker compose exec dev-runner touch /app/forbidden.txt
```
* **Expected Result**: `touch: /app/forbidden.txt: Read-only file system` (Guardrail PASSED).

### Test G2: Tmpfs Scratchpad Verification
Attempt to create files in configured `tmpfs` mounts (`/tmp`, `/app/temp`, `/app/logs`).
```bash
docker compose exec dev-runner touch /tmp/test_scratch.txt
docker compose exec dev-runner touch /app/temp/engine.lock
docker compose exec dev-runner touch /app/logs/runtime.log
```
* **Expected Result**: Successfully created in memory without modifying the host disk.

### Test G3: Read-Only Configuration Mount
Attempt to modify the bind-mounted application properties.
```bash
docker compose exec dev-runner touch /app/config/application.properties
```
* **Expected Result**: `touch: /app/config/application.properties: Read-only file system` (Guardrail PASSED).

---

## 3. Exploratory File Permission Tests (Default User vs. Root)

### Test P1: Create File as Default Non-Root User (`UID 1824`)
Simulates the container runtime or IDE Designer modifying package source code:
```bash
docker compose exec dev-runner touch /app/packages/SamplePackage/file_by_devuser.txt
```

### Test P2: Create File as Container Root User (`-u root`)
Simulates container initialization scripts or root-level instrumentation:
```bash
docker compose exec -u root dev-runner touch /app/packages/SamplePackage/file_by_root.txt
```

---

## 4. Host Observations & Cross-Platform Behavior

Inspect the created files on the host filesystem:
```bash
# On Linux / macOS:
ls -la packages/SamplePackage/

# On Windows PowerShell:
Get-ChildItem packages/SamplePackage/ | Select-Object Name, Mode
```

### Behavior Matrix Across the Three Test Scenarios

| Scenario | File created by `devuser` (UID 1824) | File created by `root` (`-u root`) | Host Developer Edit/Delete Capability |
| :--- | :--- | :--- | :--- |
| **`H_W_0R` (Windows + Rancher Desktop)** | Appears owned by active Windows user. | Appears owned by active Windows user. | **Full Access**: Both files freely editable and deletable from Windows IDE / Git. |
| **`H_M_0R` (macOS + Rancher Desktop)** | `virtiofs` maps ownership to current macOS user. | `virtiofs` maps ownership to current macOS user. | **Full Access**: Both files freely editable and deletable from macOS IDE / Git. |
| **`L_M_0U` (Void Linux + Rootless Docker)** | **Host UID `101823`** (subordinate range `100000 + 1824 - 1`). | **Host UID `1000`** (container root maps to host developer user). | **Partial Permission Block**: Host developer (UID 1000) **CANNOT edit or delete** `file_by_devuser.txt` directly without namespace switching! |

---

## 5. Sweeper / Reconciliation Verification

When running on Linux Rootless (`L_M_0U`) where `file_by_devuser.txt` has drifted to subordinate UID `101823`:

1. Execute the sweeper service:
   ```bash
   docker compose --profile sweeper run --rm sweeper
   ```
2. Verify host ownership normalization:
   ```bash
   ls -la packages/SamplePackage/
   ```
   * **Result**: All files (including those created by UID 1824) are reset to host UID `1000` and `rw-rw-r--` permissions, enabling Git and IDEs to work seamlessly.

---

## 6. Teardown

```bash
docker compose down -v
```
