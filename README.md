# Spike: Docker Development with Filesystem Mounts & Security Guardrails

This repository investigates and provides solutions for running containerized development environments with filesystem mounts under strict security guardrails (read-only root filesystem, dropped capabilities, non-root user execution) across different host operating systems and container runtimes.

The test setup is **100% self-contained and entitlement-free**, built on lightweight Alpine Linux images to easily reproduce and verify permission behaviors across all targets.

## Key Documents

* **[Spike Requirements](SPIKE_REQUIREMENTS.md)**: Original problem description and host utilization scenarios.
* **[Analysis & Proposed Solutions](ANALYSIS_AND_SOLUTIONS.md)**: Detailed technical evaluation of UID/GID mapping, rootless namespaces, and permission drift.
* **[Operational Guide](OPERATIONAL_GUIDE.md)**: Complete test procedure comparing file creation as default non-root user (`UID 1824`) vs. root (`-u root`) across:
  * `H_W_0R`: Windows + Rancher Desktop
  * `H_M_0R`: macOS + Rancher Desktop
  * `L_M_0U`: Void Linux + Rootless Docker

## Project Structure

```text
.
├── ANALYSIS_AND_SOLUTIONS.md       # Technical evaluation & architectural solution
├── EXAMPLE.env                     # Environment variables template
├── OPERATIONAL_GUIDE.md            # Step-by-step verification guide
├── README.md                       # Repository overview
├── SPIKE_REQUIREMENTS.md           # Requirements and scope
├── build/
│   └── Dockerfile                  # Self-contained Alpine image with non-root user (UID 1824)
├── config/
│   └── application.properties      # Read-only configuration mount example
├── docker-compose.yml              # Guardrailed compose runner & sweeper profile
└── packages/
    └── SamplePackage/              # Read-write package bind mount
```
