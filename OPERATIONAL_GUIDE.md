# Operational Guide: Automated & Standalone Exploratory Tests

This guide provides standalone, entitlement-free test procedures using minimal Alpine images to investigate filesystem permissions, guardrails (`read_only: true`, `tmpfs`, `cap_drop: [ALL]`), and user identity mapping across Windows, macOS, and Linux Rootless environments.

---

## 1. Automated Test Scripts

To run the complete test suite automatically in a single command:

* **On Linux / macOS**:
  ```bash
  ./test.sh
  ```
* **On Windows Command Prompt / PowerShell**:
  ```cmd
  test.bat
  ```

The test scripts automatically:
1. Initialize `.env` from `EXAMPLE.env` if not present.
2. Build and launch `dev-runner` with security guardrails.
3. Validate root filesystem read-only enforcement (`/app/forbidden.txt`).
4. Validate `tmpfs` scratchpad write capabilities (`/tmp`, `/app/temp`, `/app/logs`).
5. Validate configuration read-only enforcement (`/app/config/application.properties`).
6. Create test files inside `packages/SamplePackage` as default non-root user (`UID 1824`) and as root (`-u root`).
7. Output the host file permissions before and after running the namespace-aware sweeper.

---

## 2. Namespace-Aware Sweeper Logic

### How User Namespace Detection Works
When running inside a container, the sweeper reads `/proc/self/uid_map`:
* **Standard Rootful / Hypervisor Bridge (macOS/Windows RD)**:
  * `/proc/self/uid_map` starts with `0 0 4294967295`.
  * The sweeper applies `chown -R ${DEV_UID:-1000}:${DEV_GID:-0} /workspace/packages`.
* **Rootless Docker on Linux (e.g. Void Linux `L_M_0U`)**:
  * `/proc/self/uid_map` starts with `0 1000 1` (guest UID `0` maps to host UID `1000`).
  * The sweeper automatically detects the user namespace and sets ownership to **`0:0` (root:root)** inside the guest.
  * The Linux kernel's user namespace mapping translates container `0:0` directly to **Host Developer User `1000:1000`** on the underlying filesystem!

---

## 3. Host Behavior Matrix

| Scenario | File created by `devuser` (UID 1824) | File created by `root` (`-u root`) | Post-Sweeper Host Ownership |
| :--- | :--- | :--- | :--- |
| **`H_W_0R` (Windows + Rancher Desktop)** | Active Windows User | Active Windows User | Active Windows User |
| **`H_M_0R` (macOS + Rancher Desktop)** | Active macOS User | Active macOS User | Active macOS User |
| **`L_M_0U` (Void Linux + Rootless Docker)** | Subordinate UID (e.g. `166535`) | Host Developer (UID `1000`) | **Host Developer (`1000:1000`)** |

---

## 4. Teardown

```bash
docker compose down -v
```
