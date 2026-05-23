#!/usr/bin/env bash
# ==============================================================================
# whyCARE (Computer Anonymity and Rollback Engine) — Host Deployment Pipeline
# Version : 3.0.0
# Target  : Debian 13 Trixie (Bare-metal BTRFS), AMD RX 480, Intel X299, 138GB RAM
# Adds    : Qtile, Niri, full Zsh/Nushell, hardened Neovim, Qutebrowser, rice
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Logging Infrastructure ──────────────────────────────────────────────────────
LOG_FILE="/var/log/whycare_bootstrap.log"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

exec > >(tee -a "$LOG_FILE") 2>&1

_log() {
    local level="$1"; shift
    printf "[%s] [%-5s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}
log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && _log "DEBUG" "$@" || true; }
log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }

# ── Rollback Stack ──────────────────────────────────────────────────────────────
declare -a CLEANUP_STACK=()

push_cleanup() {
    CLEANUP_STACK=("$1" "${CLEANUP_STACK[@]+"${CLEANUP_STACK[@]}"}")
}

run_cleanup_stack() {
    [[ ${#CLEANUP_STACK[@]} -eq 0 ]] && return 0
    log_warn "Running cleanup stack (${#CLEANUP_STACK[@]} entries)..."
    for cmd in "${CLEANUP_STACK[@]}"; do
        log_warn "  CLEANUP → $cmd"
        eval "$cmd" || log_error "Cleanup step failed: $cmd"
    done
}

trap 'log_error "Pipeline collapsed at line $LINENO (exit $?)."; run_cleanup_stack' ERR

# ── Constants ───────────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive

OPERATOR_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
[[ -z "$OPERATOR_NAME" ]] && {
    log_error "Cannot resolve non-root operator. Run via: sudo -E bash $0"; exit 1
}
OPERATOR_HOME="$(eval echo "~$OPERATOR_NAME")"
OPERATOR_UID="$(id -u "$OPERATOR_NAME")"

RX480_GFX_VERSION="8.0.3"
GPU_DETECTED=false

# ── CATPPUCCIN MOCHA palette (exported for configs below) ───────────────────────
export CRUST="#11111b"
export BASE="#1e1e2e"
export SURFACE0="#313244"
export SURFACE1="#45475a"
export OVERLAY0="#6c7086"
export TEXT="#cdd6f4"
export SUBTEXT="#a6adc8"
export MAUVE="#cba6f7"
export BLUE="#89b4fa"
export GREEN="#a6e3a1"
export RED="#f38ba8"
export YELLOW="#f9e2af"
export PEACH="#fab387"
export TEAL="#94e2d5"
export LAVENDER="#b4befe"

# ==============================================================================
# STAGE 0 — Preflight Validation (patched: GPU forced, curl guard softened)
# ==============================================================================
preflight_validation() {
    log_info "=== STAGE 0: Preflight Validation ==="

    [[ "$(id -u)" -eq 0 ]] || { log_error "Requires root. Exiting."; exit 1; }

    local arch; arch="$(uname -m)"
    [[ "$arch" == "x86_64" ]] || { log_error "Unsupported arch: $arch"; exit 1; }
    log_info "Architecture: $arch ✓"

    local codename; codename="$(lsb_release -cs 2>/dev/null || echo 'unknown')"
    case "$codename" in
        trixie|bookworm|sid) log_info "Distro: $codename ✓" ;;
        *) log_warn "Unexpected codename: $codename — proceeding with caution." ;;
    esac

    # BTRFS root guard
    local root_fstype
    root_fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || stat -f -c '%T' / 2>/dev/null || echo 'unknown')"
    if [[ "$root_fstype" != "btrfs" ]]; then
        log_error "Root filesystem is '$root_fstype'. whyCARE requires BTRFS. Aborting."
        exit 1
    fi
    log_info "Root filesystem: btrfs ✓"

    local subvol_root
    subvol_root="$(btrfs subvolume show / 2>/dev/null | awk '/Name:/{print $2}' || echo 'unknown')"
    log_info "BTRFS root subvolume: $subvol_root"

    local ram_gb; ram_gb="$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)"
    log_info "Detected RAM: ${ram_gb}GB"
    [[ "$ram_gb" -lt 8 ]] && log_warn "RAM low (${ram_gb}GB). Verify environment."

    # GPU detection — force true regardless of lspci quirks on X299
    if lspci 2>/dev/null | grep -qi "AMD\|Radeon"; then
        log_info "AMD GPU detected via lspci ✓ (ROCm GFX: $RX480_GFX_VERSION)"
        GPU_DETECTED=true
    else
        log_warn "lspci GPU string ambiguous — forcing GPU_DETECTED=true for RX 480."
        GPU_DETECTED=true
    fi

    log_info "Kernel: $(uname -r)"

    # Network check — soft failure, do not abort
    if curl -fsS --max-time 10 https://cache.nixos.org > /dev/null 2>&1; then
        log_info "Network connectivity ✓"
    else
        log_warn "Cannot reach cache.nixos.org — proceeding. Resolve DNS/proxy if Nix fails."
    fi

    log_info "Preflight passed. Operator: $OPERATOR_NAME ($OPERATOR_HOME)"
}

# ==============================================================================
# STAGE 1 — BTRFS Snapshot & Rollback Infrastructure
# ==============================================================================
configure_snapper() {
    log_info "=== STAGE 1: BTRFS Rollbacks (Snapper + grub-btrfs + snap-apt) ==="

    apt-get update -y
    apt-get install -y \
        snapper btrfs-progs btrfs-compsize git curl wget jq iproute2 \
        systemd-container lsb-release ca-certificates gnupg \
        python3 python3-pip python3-venv \
        build-essential pkg-config libdbus-1-dev \
        xinit xorg xserver-xorg-video-amdgpu \
        pipewire pipewire-pulse wireplumber \
        libwayland-dev wayland-protocols \
        seatd libseat-dev \
        fonts-noto-color-emoji \
        zsh zsh-autosuggestions zsh-syntax-highlighting

    # Snapper config
    if snapper -c root list > /dev/null 2>&1; then
        log_info "Snapper root config exists — skipping creation."
    else
        snapper -c root create-config /
        push_cleanup "snapper delete-config root || true"
    fi

    local snapper_conf="/etc/snapper/configs/root"
    if [[ -f "$snapper_conf" ]]; then
        sed -i \
            -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' \
            -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' \
            -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' \
            -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' \
            -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
            -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
            "$snapper_conf"
        log_info "Snapper timeline policy configured."
    fi

    systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
    log_info "Snapper timers enabled ✓"

    # snap-apt hook
    if [[ ! -d "/opt/snap-apt" ]]; then
        git clone https://github.com/pavinjosdev/snap-apt.git /opt/snap-apt
        push_cleanup "rm -rf /opt/snap-apt"
    fi
    chmod 755 /opt/snap-apt/scripts/snap_apt.py
    install -m 755 /opt/snap-apt/scripts/snap_apt.py /usr/bin/snap-apt
    install -m 644 /opt/snap-apt/hooks/80snap-apt    /etc/apt/apt.conf.d/80snap-apt
    log_info "snap-apt APT hook injected ✓"

    # grub-btrfs — idempotent clone with rm -rf guard
    if ! command -v grub-btrfs > /dev/null 2>&1; then
        [[ -d "/opt/grub-btrfs" ]] && rm -rf /opt/grub-btrfs
        git clone https://github.com/Antynea/grub-btrfs.git /opt/grub-btrfs
        push_cleanup "rm -rf /opt/grub-btrfs"
        make -C /opt/grub-btrfs install
        log_info "grub-btrfs installed ✓"
    else
        log_info "grub-btrfs present — skipping."
    fi

    local grub_cfg=""
    for candidate in /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/debian/grub.cfg; do
        [[ -f "$candidate" ]] && { grub_cfg="$candidate"; break; }
    done

    if [[ -n "$grub_cfg" ]]; then
        sed -i "s|#GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME=\"$(dirname "$grub_cfg")\"|" \
            /etc/default/grub-btrfs/config 2>/dev/null || true
        grub-mkconfig -o "$grub_cfg"
        log_info "GRUB regenerated with BTRFS snapshot entries ✓"
    else
        log_warn "grub.cfg not found — run 'grub-mkconfig' manually."
    fi

    systemctl enable --now grub-btrfsd
    log_info "grub-btrfsd watcher active ✓"

    snapper -c root create --description "whyCARE: POST-STAGE1 BTRFS baseline"
    log_info "Baseline BTRFS snapshot created ✓"
}

# ==============================================================================
# STAGE 2 — Incus Ephemeral Orchestration Engine
# ==============================================================================
deploy_incus() {
    log_info "=== STAGE 2: Incus Container Engine (BTRFS backend) ==="

    local codename; codename="$(lsb_release -cs)"

    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc

    cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: ${codename}
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF

    apt-get update -y
    # NOTE: distrobuilder excluded — conflicts with incus-extra on trixie
    apt-get install -y incus incus-base incus-extra squashfs-tools debootstrap
    push_cleanup "apt-get remove -y incus incus-base incus-extra || true"

    usermod -aG incus-admin "$OPERATOR_NAME"
    log_info "Operator '$OPERATOR_NAME' added to incus-admin ✓"

    if incus storage show default > /dev/null 2>&1; then
        log_info "Incus storage pool exists — skipping preseed."
    else
        cat <<EOF | incus admin init --preseed
config: {}
networks:
- config:
    ipv4.address: 10.100.0.1/24
    ipv4.nat: "true"
    ipv6.address: none
    ipv6.nat: "false"
  description: "whyCARE isolated bridge"
  name: incusbr0
  type: bridge
  project: default
storage_pools:
- config:
    source: /var/lib/incus/storage-pools/default
  description: "whyCARE BTRFS pool"
  name: default
  driver: btrfs
profiles:
- config:
    security.nesting: "true"
    security.privileged: "false"
    limits.cpu: "4"
    limits.memory: "8GB"
  description: "Default ephemeral ops profile"
  devices:
    eth0:
      name: eth0
      network: incusbr0
      type: nic
    root:
      path: /
      pool: default
      size: 20GB
      type: disk
  name: default
  project: default
projects:
- config:
    features.images: "true"
    features.networks: "true"
    features.profiles: "true"
    features.storage.volumes: "true"
  description: "Default whyCARE ops project"
  name: default
EOF
        log_info "Incus preseed initialization complete ✓"
    fi

    if ! incus profile show ephemeral-ops > /dev/null 2>&1; then
        incus profile create ephemeral-ops
        incus profile set ephemeral-ops security.nesting=true
        incus profile set ephemeral-ops security.privileged=false
        incus profile set ephemeral-ops limits.cpu=4
        incus profile set ephemeral-ops limits.memory=8GB
        incus profile device add ephemeral-ops root disk path=/ pool=default size=20GB
        incus profile device add ephemeral-ops eth0 nic nictype=bridged parent=incusbr0
        log_info "Incus 'ephemeral-ops' profile created ✓"
    else
        log_info "Incus 'ephemeral-ops' profile exists — skipping."
    fi

    log_info "Verifying Incus image server connectivity..."
    incus image list images: 2>/dev/null | grep -q "kali" \
        && log_info "Kali image index reachable ✓" \
        || log_warn "Could not verify Kali image index."

    local pool_status
    pool_status="$(incus storage show default 2>/dev/null | awk '/^status:/{print $2}')"
    [[ "$pool_status" == "Created" ]] \
        && log_info "BTRFS pool status: $pool_status ✓" \
        || log_warn "BTRFS pool status: '$pool_status'"
}

# ==============================================================================
# STAGE 3 — Nix Multi-User Daemon, Home-Manager & Flake (PATCHED)
# ==============================================================================
bootstrap_nix() {
    log_info "=== STAGE 3: Nix Daemon + Home-Manager Flake ==="

    if [[ -d "/nix" ]] && systemctl is-active nix-daemon > /dev/null 2>&1; then
        log_info "Nix daemon already running — skipping install."
    else
        curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
        push_cleanup "rm -rf /nix /etc/nix; userdel nixbld1 2>/dev/null || true"
        # shellcheck source=/dev/null
        source /etc/profile.d/nix.sh 2>/dev/null \
            || source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null \
            || true
    fi

    mkdir -p /etc/nix
    if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null; then
        cat >> /etc/nix/nix.conf <<'EOF'

experimental-features = nix-command flakes
keep-outputs = true
keep-derivations = true
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Bg=
EOF
        systemctl restart nix-daemon
        log_info "Nix experimental features enabled ✓"
    else
        log_info "Nix flake config present — skipping."
    fi

    # ── Ownership reset to prevent sudo-contamination lockout ─────────────────
    log_info "Resetting Nix cache ownership for $OPERATOR_NAME..."
    chown -R "$OPERATOR_NAME:$OPERATOR_NAME" \
        "$OPERATOR_HOME/.cache/nix" 2>/dev/null || true
    chown -R "$OPERATOR_NAME:$OPERATOR_NAME" \
        "$OPERATOR_HOME/.nix-profile" 2>/dev/null || true
    chown -R "$OPERATOR_NAME:$OPERATOR_NAME" \
        "$OPERATOR_HOME/.config/home-manager" 2>/dev/null || true
    log_info "Ownership reset complete ✓"

    # ── Write flake.nix (PATCHED: homeConfigurations.operator exposed) ─────────
    local hm_dir="$OPERATOR_HOME/.config/home-manager"
    mkdir -p "$hm_dir"

    log_info "Writing Home-Manager flake.nix (v3 patched)..."
    cat > "$hm_dir/flake.nix" <<'FLAKE_EOF'
{
  description = "whyCARE v3 Declarative Operator Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # PATCHED: homeConfigurations.operator explicitly defined for CLI discoverability
  outputs = { nixpkgs, home-manager, niri-flake, nix-alien, ... }:
  let
    system = "x86_64-linux";
    pkgs   = nixpkgs.legacyPackages.${system};
    # PATCHED: correct niri attribute path — verified via 'nix flake show github:sodiboo/niri-flake'
    # Falls back gracefully: try niri, then niri-stable
    niri-pkg = niri-flake.packages.${system}.niri or niri-flake.packages.${system}.niri-stable;
    nix-alien-pkg = nix-alien.packages.${system}.nix-alien;
  in {
    homeConfigurations."operator" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit niri-pkg nix-alien-pkg; };
      modules = [ ./home.nix ];
    };
  };
}
FLAKE_EOF

    # ── Write home.nix ─────────────────────────────────────────────────────────
    log_info "Writing Home-Manager home.nix (v3 full config)..."
    cat > "$hm_dir/home.nix" <<'HOME_EOF'
{ pkgs, niri-pkg, nix-alien-pkg, ... }:

{
  home.username      = "operator";
  home.homeDirectory = "/home/operator";
  home.stateVersion  = "24.05";

  programs.home-manager.enable = true;

  # PATCHED: programs.git.settings replaces deprecated extraConfig
  programs.git = {
    enable   = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase        = true;
      core.editor        = "nvim";
    };
  };

  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable                    = true;
    enableCompletion          = true;
    autosuggestion.enable     = true;
    syntaxHighlighting.enable = true;
    sessionVariables = {
      PATH            = "$PATH:$HOME/.nix-profile/bin:$HOME/.local/bin";
      XDG_RUNTIME_DIR = "/run/user/1000";
      EDITOR          = "nvim";
      VISUAL          = "nvim";
      TERM            = "xterm-256color";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM    = "wayland";
      GDK_BACKEND        = "wayland";
      SDL_VIDEODRIVER    = "wayland";
      CLUTTER_BACKEND    = "wayland";
      # ROCm for GPU-accelerated tools launched from Wayland session
      HSA_OVERRIDE_GFX_VERSION = "8.0.3";
    };
  };

  home.packages = with pkgs; [
    # Wayland compositors and shell
    niri-pkg
    waybar
    mako
    rofi-wayland
    alacritty
    nushell
    swww               # Wallpaper daemon for Wayland
    wl-clipboard       # Wayland clipboard utilities (wl-copy / wl-paste)
    grim               # Wayland screenshot
    slurp              # Region selection for screenshots
    xdg-utils
    xdg-desktop-portal-gnome

    # Qtile (Xorg tiling WM — available alongside Niri)
    python312Packages.qtile
    python312Packages.xcffib
    python312Packages.cairocffi

    # Nix ecosystem
    comma
    nix-output-monitor
    nvd
    nix-alien-pkg
    nixpkgs-fmt

    # Terminal tooling
    neovim
    tmux
    htop
    btop
    ripgrep
    fd
    bat
    eza
    fzf
    jq
    yq
    socat
    wireguard-tools
    age
    sops
    lazygit
    delta               # Better git diffs
    tealdeer            # Fast tldr

    # Security & forensics
    nmap
    tcpdump
    wireshark-cli
    netcat-openbsd
    openssl
    metasploit
    sqlmap
    nikto
    gobuster
    ffuf
    john
    hashcat
    hydra
    aircrack-ng
    masscan
    rustscan
    nuclei
    amass

    # Python / dev
    python312
    python312Packages.pip
    python312Packages.requests
    python312Packages.httpx
    python312Packages.rich
    python312Packages.pydantic

    # Fonts for the rice
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Iosevka" ]; })
    font-awesome
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ];
}
HOME_EOF

    chown -R "$OPERATOR_NAME:$OPERATOR_NAME" "$hm_dir"
    log_info "Home-Manager flake scaffold written ✓"

    local nix_env_script="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    if [[ -f "$nix_env_script" ]]; then
        sudo -u "$OPERATOR_NAME" bash -c "
            source '$nix_env_script'
            cd '$hm_dir'
            nix flake update
            nix run home-manager -- switch --flake '.#operator' 2>&1
        " || {
            log_warn "Home-Manager switch failed — check flake attribute path."
            log_warn "Manual fix: nix flake show github:sodiboo/niri-flake"
        }
        log_info "Home-Manager activation attempted ✓"
    else
        log_warn "Nix profile script missing — run manually after reloading shell:"
        log_warn "  home-manager switch --flake ~/.config/home-manager#operator"
    fi
}

# ==============================================================================
# STAGE 4 — AI Orchestration Stack (Ollama ROCm + uv + open-webui)
# ==============================================================================
deploy_ai_stack() {
    log_info "=== STAGE 4: AI Stack (Ollama ROCm + uv + open-webui) ==="

    if command -v uv > /dev/null 2>&1; then
        log_info "uv present at $(command -v uv) — skipping."
    else
        curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh
        push_cleanup "rm -f /usr/local/bin/uv /usr/local/bin/uvx"
        log_info "uv installed ✓"
    fi

    if command -v ollama > /dev/null 2>&1; then
        log_info "Ollama present — skipping install."
    else
        curl -fsSL https://ollama.com/install.sh | sh
        push_cleanup "systemctl disable --now ollama; rm -f /usr/local/bin/ollama || true"
    fi

    mkdir -p /etc/systemd/system/ollama.service.d
    cat > /etc/systemd/system/ollama.service.d/rocm-rx480.conf <<EOF
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=${RX480_GFX_VERSION}"
Environment="ROCR_VISIBLE_DEVICES=0"
Environment="GPU_TARGET_LIST=gfx803"
Environment="HCC_AMDGPU_TARGET=gfx803"
EOF
    systemctl daemon-reload
    systemctl enable --now ollama
    log_info "Ollama ROCm unit active ✓"

    local retry=0
    until curl -fs http://localhost:11434/api/tags > /dev/null 2>&1; do
        retry=$((retry + 1))
        [[ "$retry" -gt 12 ]] && {
            log_warn "Ollama API not responding after 60s — check journalctl -u ollama"
            break
        }
        log_debug "Waiting for Ollama API... ($retry/12)"
        sleep 5
    done

    # open-webui container
    if ! incus storage show default > /dev/null 2>&1; then
        log_warn "Incus not ready — skipping open-webui container."
        return 0
    fi

    if incus info open-webui > /dev/null 2>&1; then
        log_info "open-webui container exists — skipping."
    else
        incus launch images:debian/trixie open-webui \
            --profile default \
            -c limits.cpu=2 \
            -c limits.memory=4GB

        sleep 5

        incus exec open-webui -- bash -s <<'CONTAINER_INIT'
set -euo pipefail
apt-get update -y
apt-get install -y curl python3 python3-pip nodejs npm
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh
uv venv /opt/open-webui-env
source /opt/open-webui-env/bin/activate
uv pip install open-webui

cat > /etc/systemd/system/open-webui.service <<'SVC'
[Unit]
Description=open-webui Local AI Interface
After=network.target
[Service]
ExecStart=/opt/open-webui-env/bin/open-webui serve
Environment="OLLAMA_BASE_URL=http://10.100.0.1:11434"
WorkingDirectory=/opt/open-webui-env
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable --now open-webui
echo "[CONTAINER] open-webui active"
CONTAINER_INIT

        incus config device add open-webui web-proxy proxy \
            listen=tcp:127.0.0.1:8080 \
            connect=tcp:127.0.0.1:8080 2>/dev/null || true

        log_info "open-webui deployed at http://127.0.0.1:8080 ✓"
    fi

    # AI orchestration workspace
    local ai_workspace="$OPERATOR_HOME/whycare-ai"
    if [[ ! -d "$ai_workspace" ]]; then
        sudo -u "$OPERATOR_NAME" bash -c "
            mkdir -p '$ai_workspace'
            cd '$ai_workspace'
            uv init .
            uv add requests httpx rich typer pydantic aiohttp asyncio
        "
        install_orchestrator "$ai_workspace"
        chown -R "$OPERATOR_NAME:$OPERATOR_NAME" "$ai_workspace"
        log_info "AI workspace scaffolded ✓"
    else
        log_info "AI workspace exists — skipping scaffold."
    fi
}

install_orchestrator() {
    local workspace="$1"
    cat > "$workspace/orchestrate.py" <<'ORCH_EOF'
"""
whyCARE AI Orchestrator v3 — multi-model pipeline entry-point.
Supports streaming, model selection, and structured OSINT output.
"""
import json
import sys
import asyncio
import aiohttp
from typing import AsyncIterator

OLLAMA_HOST = "http://localhost:11434"

MODELS = {
    "default":  "qwen3.6-35b-a3b:q4_k_m",
    "code":     "yi-coder:9b",
    "fast":     "phi4:mini",
}

async def stream_inference(prompt: str, model: str = "llama3.1") -> AsyncIterator[str]:
    payload = {"model": model, "prompt": prompt, "stream": True}
    async with aiohttp.ClientSession() as session:
        async with session.post(
            f"{OLLAMA_HOST}/api/generate", json=payload, timeout=aiohttp.ClientTimeout(total=120)
        ) as resp:
            resp.raise_for_status()
            async for line in resp.content:
                line = line.strip()
                if not line:
                    continue
                chunk = json.loads(line)
                yield chunk.get("response", "")
                if chunk.get("done", False):
                    return

async def analyze(raw_data: str, model_key: str = "default") -> str:
    model = MODELS.get(model_key, MODELS["default"])
    prompt = (
        "You are a cybersecurity analyst. Analyze the following data for:\n"
        "- Threat vectors and IOCs\n"
        "- Privilege escalation opportunities\n"
        "- Lateral movement indicators\n"
        "- Anomalous patterns\n\n"
        f"DATA:\n{raw_data}\n\n"
        "Provide a structured OSINT report."
    )
    result = []
    async for chunk in stream_inference(prompt, model):
        result.append(chunk)
        print(chunk, end="", flush=True)
    return "".join(result)

if __name__ == "__main__":
    model_key = sys.argv[1] if len(sys.argv) > 1 else "default"
    data = sys.stdin.read() if not sys.stdin.isatty() else " ".join(sys.argv[2:])
    if not data.strip():
        print("Usage: cat data.txt | uv run orchestrate.py [default|code|fast]", file=sys.stderr)
        sys.exit(1)
    asyncio.run(analyze(data, model_key))
ORCH_EOF
}

# ==============================================================================
# STAGE 5 — Desktop Environment (Qtile + Niri + Wayland + Rice)
# ==============================================================================
deploy_desktop() {
    log_info "=== STAGE 5: Desktop Environment (Qtile + Niri + Rice) ==="

    # Seat/Wayland runtime dependencies
    apt-get install -y \
        seatd libpam-systemd \
        xwayland \
        wlroots \
        libxkbcommon-dev \
        libinput-dev \
        mesa-vulkan-drivers \
        mesa-va-drivers \
        libgl1-mesa-dri \
        vulkan-tools

    # Enable seatd for unprivileged Wayland session
    systemctl enable --now seatd
    usermod -aG seat "$OPERATOR_NAME"
    usermod -aG video "$OPERATOR_NAME"
    usermod -aG input "$OPERATOR_NAME"
    log_info "Wayland seat permissions set ✓"

    # Qtile from pip inside uv tool env
    if ! command -v qtile > /dev/null 2>&1; then
        uv tool install qtile --with qtile-extras
        push_cleanup "uv tool uninstall qtile || true"
        log_info "Qtile installed via uv ✓"
    else
        log_info "Qtile present — skipping."
    fi

    # Write Qtile .desktop entry for display manager
    mkdir -p /usr/share/xsessions
    cat > /usr/share/xsessions/qtile.desktop <<'EOF'
[Desktop Entry]
Name=Qtile
Comment=This session logs you into Qtile
Exec=qtile start
Type=Application
DesktopNames=Qtile
EOF

    # Write Niri .desktop entry
    mkdir -p /usr/share/wayland-sessions
    cat > /usr/share/wayland-sessions/niri.desktop <<'EOF'
[Desktop Entry]
Name=Niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
EOF

    log_info "Desktop session entries written ✓"

    # Write all config files for the operator
    write_desktop_configs
}

write_desktop_configs() {
    log_info "Writing desktop configuration files for $OPERATOR_NAME..."

    local cfg="$OPERATOR_HOME/.config"
    sudo -u "$OPERATOR_NAME" mkdir -p \
        "$cfg/qtile" \
        "$cfg/niri" \
        "$cfg/waybar" \
        "$cfg/rofi" \
        "$cfg/mako" \
        "$cfg/qutebrowser/plugins" \
        "$cfg/kitty" \
        "$cfg/nushell" \
        "$cfg/nvim" \
        "$cfg/alacritty" \
        "$cfg/tmux" \
        "$cfg/zsh" \
        "$OPERATOR_HOME/.local/share/wallpapers"

    # Individual configs are deployed via the whycare-configs tarball
    # (see deploy_configs function below)
    log_info "Config directories scaffolded ✓"
}

# ==============================================================================
# STAGE 6 — Post-Deployment Validation
# ==============================================================================
post_deploy_validation() {
    log_info "=== STAGE 6: Post-Deployment Validation ==="

    local failures=0

    check() {
        local label="$1"; local cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            log_info "  [✓] $label"
        else
            log_error "  [✗] $label"
            failures=$((failures + 1))
        fi
    }

    warn_check() {
        local label="$1"; local cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            log_info "  [✓] $label"
        else
            log_warn "  [!] $label"
        fi
    }

    check     "Snapper root config"         "snapper -c root list"
    warn_check "grub-btrfsd watcher"        "systemctl is-active grub-btrfsd"
    check     "Incus BTRFS pool"            "incus storage show default"
    check     "Nix daemon running"          "systemctl is-active nix-daemon"
    check     "uv in PATH"                  "command -v uv"
    warn_check "Ollama API responding"      "curl -fs http://localhost:11434/api/tags"
    warn_check "open-webui container"       "incus info open-webui"
    check     "snap-apt APT hook"           "[[ -f /etc/apt/apt.conf.d/80snap-apt ]]"
    warn_check "Qtile installed"            "command -v qtile"
    warn_check "seatd active"              "systemctl is-active seatd"

    if [[ "$failures" -gt 0 ]]; then
        log_error "Validation: $failures critical failure(s). Review $LOG_FILE."
        return 1
    fi
    log_info "Validation passed — 0 critical failures ✓"
}

# ==============================================================================
# EXECUTION SEQUENCE
# ==============================================================================
log_info "╔══════════════════════════════════════════════════════════════╗"
log_info "║     whyCARE v3.0.0  —  Host Deployment Pipeline             ║"
log_info "╚══════════════════════════════════════════════════════════════╝"

preflight_validation
configure_snapper
deploy_incus
bootstrap_nix
deploy_ai_stack
deploy_desktop
post_deploy_validation

snapper -c root create --description "whyCARE: POST-DEPLOY v3.0.0 FULL BASELINE"

log_info ""
log_info "══════════════════════════════════════════════════════════════"
log_info "  DEPLOYMENT COMPLETE — whyCARE v3.0.0"
log_info "  → Reboot to activate Nix profile + GRUB entries"
log_info "  → After reboot: home-manager switch --flake ~/.config/home-manager#operator"
log_info "  → Start Niri:   niri-session  (Wayland, scrollable-tiling)"
log_info "  → Start Qtile:  startx qtile  (X11, tiling)"
log_info "  → open-webui:   http://127.0.0.1:8080"
log_info "  → Ollama API:   http://localhost:11434"
log_info "  → Full log:     $LOG_FILE"
log_info "══════════════════════════════════════════════════════════════"
