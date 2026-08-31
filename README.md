# ollama-compose

A collection of `docker compose` files for running [ollama](https://ollama.com)
across different machines, organized by GPU vendor first, then environment.

## Hierarchy

```
ollama-compose/
├── master-ollama.yml          # base: image, ports, volumes, restart
├── nvidia/
│   ├── ollama-base.yml        # NVIDIA device passthrough, driver caps, flash attention
│   ├── wsl/compose.yml        # + ipc: host (WSL2 shared-memory accommodation)
│   └── linux/compose.yml      # native Linux, no ipc: host
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
  └─ nvidia/ollama-base.yml  (+ NVIDIA GPU config)
       └─ nvidia/wsl/compose.yml  (+ WSL-specific tweaks)
       └─ nvidia/linux/compose.yml  (no tweaks needed)
```

Because the parent file is always named `ollama-base.yml` (or `master-ollama.yml`
at the root), every environment file can reference its parent with the same
relative path (`../ollama-base.yml`) regardless of which vendor directory it's
under.

**Important `extends` caveat:** `extends` only merges the referenced *service*
definition - it does **not** pull in top-level `volumes:`/`networks:` sections
from parent files. Every file that's actually run with `docker compose -f ... up`
must redeclare the `volumes:` block itself (see `nvidia/wsl/compose.yml` and
`nvidia/linux/compose.yml` for the pattern). Each leaf file also pins an
explicit `name: ollama` so the Compose project name doesn't vary based on
which directory it happens to be run from.

## Prerequisites

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

## Status

| Vendor | Environment | Status |
|---|---|---|
| NVIDIA | WSL2 | ✅ Implemented |
| NVIDIA | Linux (native) | ✅ Implemented |
| AMD | any | 🚧 Placeholder only (`amd/ollama-base.yml`) |
| Intel | any | 🚧 Placeholder only (`intel/ollama-base.yml`) |
| Apple Silicon | any | 🚧 Placeholder only (`apple-silicon/ollama-base.yml`) |

## Usage

```bash
# NVIDIA GPU on WSL2
docker compose -f nvidia/wsl/compose.yml up -d

# NVIDIA GPU on native Linux
docker compose -f nvidia/linux/compose.yml up -d

# Preview the fully-resolved config without starting anything
docker compose -f nvidia/wsl/compose.yml config

# Stop
docker compose -f nvidia/wsl/compose.yml down
```

ollama listens on `http://localhost:11434` regardless of environment.

## Adding a new environment

1. Pick (or create) the vendor directory (e.g. `nvidia/`, `amd/`).
2. If the vendor's `ollama-base.yml` doesn't exist yet or is still a
   placeholder, fill it in with the hardware-specific device/driver config.
3. Create `<vendor>/<environment>/compose.yml` extending `../ollama-base.yml`,
   adding only what's specific to that environment (e.g. `ipc: host` for WSL2).
4. Don't forget: `name: ollama` and a redeclared `volumes:` block at the top
   level, per the caveat above.
5. Validate with `docker compose -f <vendor>/<environment>/compose.yml config`
   before running it for real.
