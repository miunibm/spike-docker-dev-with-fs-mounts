# Spike Analysis & Solutions: Docker Development with Filesystem Mounts

## 1. Executive Summary & Problem Formulation

In containerized development environments where runtime engines (such as webMethods Microservices Runtime - MSR) execute inside containers with security guardrails (read-only root filesystem, dropped capabilities, non-root execution), developers must bind-mount source code packages into the guest.

### The Core Dilemma
* **Vendor Image Identity**: webMethods container images default to user `sagadmin` with fixed UID/GID `1824:1824`.
* **Designer / Runtime Mutation**: During development using webMethods Service Designer / Eclipse, services create or update files (Flow services, `.ndf`, Java services in `code/source`, bytecode in `code/classes`, `manifest.v3`) inside the bind-mounted package directory.
* **Host Permission Collision**:
  * On Linux (especially **Rootless Docker** `L_M_0U`), files written by container UID `1824` are saved on the host with an offset subordinate UID (e.g. `101823`), preventing the host developer (UID `1000`) and host Git tooling from modifying, staging, or deleting them without namespace switching.
  * On native Linux rootful (`L_M_0R`), files written by container UID `1824` are saved as host UID `1824`, requiring `sudo` to clean up.
  * On macOS (`H_M_0R`) and Windows WSL2 (`H_W_0R`), hypervisor drivers (`virtiofs`, `9P`/`drvfs`) translate ownership transparently, but guardrails like read-only root filesystems require strict `tmpfs` design.

### Crucial Finding: `tmpfs` Mount Permissions
When `read_only: true` is enabled, containers require `tmpfs` mounts for temporary scratchpads (e.g., `/tmp`, `/app/temp`, `/app/logs`).
* `/tmp` defaults to `mode=1777` (world-writable sticky bit).
* **Custom paths** (like `/app/temp` and `/app/logs`) are mounted by Docker daemon as `root:root (0755)`.
* When the container executes as a non-root user (`UID 1824`), attempts to write to `/app/temp` or `/app/logs` fail with `Permission denied` unless explicit mount permissions (`mode=1777`) are declared in Docker Compose.

---

## 2. In-Depth Analysis of the Three Primary Test Scenarios

```
+---------------------------------------------------------------------------------------------------+
| Scenario 1: H_W_0R (Windows + Rancher Desktop / WSL2)                                             |
| Host (Windows NTFS / WSL2) <==[ virtio-fs / 9P / drvfs ]==> Container Guest (UID 1824 or custom)  |
| - Files created by MSR map cleanly to the active Windows user.                                    |
| - Primary guardrail concern: Container read_only rootfs + tmpfs allocations.                      |
+---------------------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------------------+
| Scenario 2: H_M_0R (macOS + Rancher Desktop / vz / QEMU)                                          |
| Host (macOS APFS) <==[ virtiofs translation bridge ]==> Container Guest (UID 1824 or custom)      |
| - virtiofs presents files inside container as accessible; host sees them owned by macOS user.     |
| - Primary guardrail concern: Container read_only rootfs + tmpfs allocations.                      |
+---------------------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------------------+
| Scenario 3: L_M_0U (Void Linux / Linux + Rootless Docker Engine)                                  |
| Host User (UID 1000)                                                                              |
|   |--> User Namespace (userns)                                                                    |
|          |-- Container UID 0 (root)   =======> Maps to Host UID 1000 (Developer)                  |
|          |-- Container UID 1824 (MSR) =======> Maps to Host UID 100000 + 1824 - 1 = 101823        |
| - Host directory owned by UID 1000 (0755) appears as owned by root:root (0755) in guest.          |
| - Guest non-root user (UID 1824) gets "Permission denied" creating files unless directory is a+rwX.|
| - Files created by MSR (UID 1824) are written to host disk as subordinate UID (e.g. 166535)!       |
| - Solution: Set workspace packages to a+rwX and use Sweeper to reset ownership to 0:0 / 1000:1000.  |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Evaluated Solutions

### Solution Option A: Image User Remapping (`usermod` / `groupmod` at build time)
* **How it works**: Dockerfile accepts build arguments `DEV_UID` and `DEV_GID` (defaulting to host user, e.g. `1000:1000`), altering `sagadmin` UID/GID and recursively chowning `/opt/webmethods`.
* **Behavior across platforms**:
  * `H_W_0R` & `H_M_0R`: Works seamlessly.
  * `L_M_0R` (Rootful): Works perfectly; host user UID 1000 matches container UID 1000.
  * `L_M_0U` (Rootless): Container UID 1000 maps to host UID `100999`. Still produces subordinate ownership on host files unless container user is set to UID 0 (which is host UID 1000 in rootless mode).

### Solution Option B: SGID + Default POSIX ACLs on Host Workspace
* **How it works**: Host directories are initialized with `chmod -R 2775 workspace/code` and `setfacl -d -m g::rwx,o::rx`. Container runtime uses `umask 002`.
* **Behavior across platforms**:
  * Excellent on Linux rootful; however, requires host-level ACL toolchain and does not eliminate subuid isolation in rootless containers without matching subordinate GIDs.

### Solution Option C: Guardrailed MSR + Profile-Based Alpine Sweeper Service (**Recommended**)
* **How it works**:
  1. The MSR container runs with strict guardrails (`read_only: true`, `cap_drop: [ALL]`, non-root user `1824` or remapped `DEV_UID`).
  2. Temporary/cache directories are mounted on dedicated `tmpfs` mounts.
  3. A lightweight Alpine service (`sweeper`) is defined under a dedicated compose profile (`profiles: ["sweeper"]` or `--profile tools`).
  4. On `L_M_0U` (Rootless), when `docker compose --profile sweeper run --rm sweeper` executes as root inside the container, the Linux kernel maps container root (`UID 0`) directly to the **host developer user (`UID 1000`)**. The sweeper instantly fixes permissions and group access across all bind mounts without requiring host `sudo`.

---

## 4. Synthesis & Architectural Recommendation

We recommend a **Unified Development Architecture**:
1. **Docker Compose Standard Definition**: Includes guardrails (`read_only: true`, `tmpfs`, `security_opt: [no-new-privileges:true]`).
2. **Dynamic Identity via `.env`**: Passes `DEV_UID` and `DEV_GID` for building and running.
3. **Integrated Sweeper Profile (`sweeper`)**: Allows one-command reconciliation of bind-mount permissions across all platforms, especially Void Linux / Rootless Docker.
