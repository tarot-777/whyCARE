# ~/.config/nushell/env.nu
# whyCARE v3 — Nushell Environment Initializer

# ── PATH ──────────────────────────────────────────────────────────────────────
$env.PATH = (
    $env.PATH
    | split row (char env_sep)
    | prepend [
        ($env.HOME | path join ".local" "bin")
        ($env.HOME | path join ".nix-profile" "bin")
        ($env.HOME | path join ".local" "share" "uv" "shims")
        "/usr/local/bin"
    ]
    | uniq
)

# ── Python / uv ───────────────────────────────────────────────────────────────
$env.UV_PYTHON_PREFERENCE = "only-managed"
$env.VIRTUAL_ENV_DISABLE_PROMPT = "1"

# ── Editor ────────────────────────────────────────────────────────────────────
$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.PAGER  = "less -R"

# ── Nix ───────────────────────────────────────────────────────────────────────
$env.NIX_PATH = ($env | get -i NIX_PATH | default "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs")

# ── Wayland / GPU ─────────────────────────────────────────────────────────────
$env.QT_QPA_PLATFORM        = "wayland"
$env.GDK_BACKEND            = "wayland,x11"
$env.MOZ_ENABLE_WAYLAND     = "1"
$env.SDL_VIDEODRIVER         = "wayland"
$env.CLUTTER_BACKEND         = "wayland"
$env.XDG_CURRENT_DESKTOP    = "niri"
$env.XDG_SESSION_TYPE       = "wayland"
$env.XDG_RUNTIME_DIR        = $"/run/user/($env | get -i UID | default "1000")"

# ── AMD RX 480 ROCm override ──────────────────────────────────────────────────
$env.HSA_OVERRIDE_GFX_VERSION = "8.0.3"
$env.ROCR_VISIBLE_DEVICES     = "0"
$env.GPU_TARGET_LIST          = "gfx803"
$env.HCC_AMDGPU_TARGET        = "gfx803"

# ── Locale ────────────────────────────────────────────────────────────────────
$env.LANG   = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"

# ── FZF ───────────────────────────────────────────────────────────────────────
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
$env.FZF_DEFAULT_OPTS = "
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --border=rounded --height=40% --layout=reverse --info=inline
"

# ── bat ───────────────────────────────────────────────────────────────────────
$env.BAT_THEME = "Catppuccin Mocha"

# ── Nushell prompt ────────────────────────────────────────────────────────────
$env.PROMPT_COMMAND = {||
    let dir = ([$env.HOME] | each {|h| ($env.PWD | str replace $h "~") } | first)
    let git_branch = (
        do --ignore-errors { ^git symbolic-ref --short HEAD } | str trim
    )
    let git_part = if ($git_branch | is-empty) { "" } else {
        $" \(ansi purple)($git_branch)\(ansi reset)"
    }
    let priv = if ($env | get -i USER | default "") == "root" { "# " } else { "❯ " }
    $"\(ansi purple_bold)($dir)\(ansi reset)($git_part)\n\(ansi purple)($priv)\(ansi reset)"
}

$env.PROMPT_COMMAND_RIGHT = {||
    let time = (date now | format date "%H:%M:%S")
    $"\(ansi dark_gray)($time)\(ansi reset)"
}

$env.PROMPT_INDICATOR            = ""
$env.PROMPT_INDICATOR_VI_INSERT  = ": "
$env.PROMPT_INDICATOR_VI_NORMAL  = "〉"
$env.PROMPT_MULTILINE_INDICATOR  = "::: "

# ── Completions path ──────────────────────────────────────────────────────────
$env.NU_LIB_DIRS = [
    ($nu.default-config-dir | path join "lib")
]

$env.NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join "plugins")
]
