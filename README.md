# ollama-compose

A collection of `docker compose` files for running [ollama](https://ollama.com)
across different machines, organized by hardware vendor/architecture first, then environment or device profile.

## Hierarchy

```
ollama-compose/
├── master-ollama.yml          # base: image, ports, volumes, restart
├── nvidia/
│   ├── ollama-base.yml        # NVIDIA device passthrough, driver caps, flash attention
│   ├── wsl/compose.yml        # + ipc: host (WSL2 shared-memory accommodation)
│   └── linux/compose.yml      # native Linux, no ipc: host
├── rpi/
│   ├── ollama-base.yml        # generic ARM CPU base (single concurrency, keepalive, flash attn off)
│   ├── pi3/
│   │   ├── ollama-base.yml    # Pi 3 base (BCM2837B0 Cortex-A53, 4 threads, 64-bit OS required)
│   │   ├── 1gb/compose.yml    # 700M memory ceiling for 1GB RAM
│   │   └── 3b-plus/compose.yml # 3B+ configuration (alias to 1GB)
│   └── pi5/
│       ├── ollama-base.yml    # Pi 5 base (BCM2712 Cortex-A76, 4 threads)
│       ├── 2gb/compose.yml    # 1400M memory limit (0.5B - 1.5B models)
│       ├── 4gb/compose.yml    # 3200M memory limit (up to 3B models)
│       ├── 8gb/compose.yml    # 6500M memory limit (up to 7B/8B Q4 models)
│       └── 16gb/compose.yml   # 14000M memory limit (up to 14B Q4 models)
├── amd/
│   └── ollama-base.yml        # placeholder - not yet implemented
├── intel/
│   └── ollama-base.yml        # placeholder - not yet implemented
└── apple-silicon/
    └── ollama-base.yml        # placeholder - not yet implemented
```

Each level uses Docker Compose's [`extends`](https://docs.docker.com/reference/compose-file/services/#extends)
to inherit from its parent:

```
master-ollama.yml  (generic base)
  ├─ nvidia/ollama-base.yml  (+ NVIDIA GPU config)
  │    ├─ nvidia/wsl/compose.yml  (+ WSL-specific tweaks)
  │    └─ nvidia/linux/compose.yml  (no tweaks needed)
  └─ rpi/ollama-base.yml  (+ generic ARM CPU tuning)
       ├─ rpi/pi3/ollama-base.yml  (+ Pi 3 CPU architecture & 64-bit requirements)
       │    └─ rpi/pi3/1gb/compose.yml  (+ 1GB RAM memory limits)
       └─ rpi/pi5/ollama-base.yml  (+ Pi 5 CPU & thread tuning)
            └─ rpi/pi5/8gb/compose.yml  (+ 8GB RAM memory limits)
```

Because the parent file is always named `ollama-base.yml` (or `master-ollama.yml`
at the root), every environment file can reference its parent with the same
relative path (`../ollama-base.yml` or `../../ollama-base.yml`) regardless of which directory it's under.

**Important `extends` caveat:** `extends` only merges the referenced *service*
definition - it does **not** pull in top-level `volumes:`/`networks:` sections
from parent files. Every file that's actually run with `docker compose -f ... up`
must redeclare the `volumes:` block itself (see `nvidia/wsl/compose.yml` and
`nvidia/linux/compose.yml` for the pattern). Each leaf file also pins an
explicit `name: ollama` so the Compose project name doesn't vary based on
which directory it happens to be run from.

## Prerequisites

### NVIDIA GPU

For any NVIDIA GPU environment, the host must have the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
installed and configured - this is what lets the `deploy.resources.reservations`
GPU syntax in `nvidia/ollama-base.yml` actually reach the GPU. Without it, the
container will either fail to start or silently fall back to CPU.

- **WSL2**: install the toolkit *inside* the WSL distro, using the Windows
  NVIDIA driver already installed on the host. Do not install a separate
  Linux NVIDIA driver inside WSL2.
- **Native Linux**: install the toolkit per your distro's package manager,
  following the link above.

Verify the toolkit is working before running any `nvidia/*` compose file:

```bash
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi
```

### Raspberry Pi / ARM SBC

- **64-bit OS required**: Ollama publishes official container images for `linux/arm64` (aarch64). A 64-bit kernel and userland (such as Raspberry Pi OS 64-bit or Ubuntu Server 64-bit) is required on all models, including the Pi 3B+.
- **CPU-only inference**: Uses ARM NEON and vector instructions. Flash attention is explicitly disabled in the base config to prevent fallback penalties. Concurrency is pinned to 1 (`OLLAMA_NUM_PARALLEL=1`) to avoid thrashing low core counts.
- **Cooling**: On the Raspberry Pi 5, active cooling (the official Raspberry Pi Active Cooler or a fan case) is strongly recommended; bare silicon will thermally throttle under sustained prompt evaluation.

## Status

| Vendor / Architecture | Environment / Model | Status |
|---|---|---|
| NVIDIA | WSL2 | ✅ Implemented |
| NVIDIA | Linux (native) | ✅ Implemented |
| Raspberry Pi | Pi 5 (2GB, 4GB, 8GB, 16GB) | ✅ Implemented |
| Raspberry Pi | Pi 3B+ / Pi 3 (1GB) | ✅ Implemented |
| AMD | any | 🚧 Placeholder only (`amd/ollama-base.yml`) |
| Intel | any | 🚧 Placeholder only (`intel/ollama-base.yml`) |
| Apple Silicon | any | 🚧 Placeholder only (`apple-silicon/ollama-base.yml`) |

## Usage

```bash
# NVIDIA GPU on WSL2
docker compose -f nvidia/wsl/compose.yml up -d

# NVIDIA GPU on native Linux
docker compose -f nvidia/linux/compose.yml up -d

# Raspberry Pi 5 (8GB)
docker compose -f rpi/pi5/8gb/compose.yml up -d

# Raspberry Pi 3B+
docker compose -f rpi/pi3/3b-plus/compose.yml up -d

# Preview the fully-resolved config without starting anything
docker compose -f nvidia/wsl/compose.yml config

# Stop
docker compose -f nvidia/wsl/compose.yml down
```

ollama listens on `http://localhost:11434` regardless of environment.

## Adding a new environment

1. Pick (or create) the vendor directory (e.g. `nvidia/`, `amd/`, `rpi/`).
2. If the vendor's `ollama-base.yml` doesn't exist yet or is still a
   placeholder, fill it in with the hardware-specific device/driver config.
3. Create `<vendor>/<environment>/compose.yml` extending `../ollama-base.yml`,
   adding only what's specific to that environment (e.g. `ipc: host` for WSL2, memory caps for RAM tiers).
4. Don't forget: `name: ollama` and a redeclared `volumes:` block at the top
   level, per the caveat above.
5. Validate with `docker compose -f <vendor>/<environment>/compose.yml config`
   before running it for real.
