# -*- coding: utf-8 -*-
# ~/.config/qtile/config.py
# whyCARE v3 — Qtile Pentesting WM
# Theme: Catppuccin Mocha | Hardware: Intel X299 / AMD RX 480

import os
import subprocess
from libqtile import bar, hook, layout, qtile, widget
from libqtile.config import (
    Click, Drag, Group, Key, KeyChord, Match, Screen, ScratchPad, DropDown
)
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal
try:
    from libqtile.widget import WidgetBox
    from qtile_extras import widget as ext_widget
    from qtile_extras.widget.decorations import BorderDecoration, PowerLineDecoration
    HAS_EXTRAS = True
except ImportError:
    HAS_EXTRAS = False

# ==============================================================================
# CATPPUCCIN MOCHA PALETTE
# ==============================================================================
CRUST   = "#11111b"
BASE    = "#1e1e2e"
MANTLE  = "#181825"
SURFACE0= "#313244"
SURFACE1= "#45475a"
OVERLAY0= "#6c7086"
TEXT    = "#cdd6f4"
SUBTEXT = "#a6adc8"
MAUVE   = "#cba6f7"
BLUE    = "#89b4fa"
LAVENDER= "#b4befe"
GREEN   = "#a6e3a1"
RED     = "#f38ba8"
YELLOW  = "#f9e2af"
PEACH   = "#fab387"
TEAL    = "#94e2d5"
PINK    = "#f5c2e7"
SKY     = "#89dceb"

# ==============================================================================
# MODIFIERS AND TERMINAL
# ==============================================================================
MOD  = "mod4"   # Super key
ALT  = "mod1"
TERM = os.environ.get("TERMINAL", "alacritty")

# ==============================================================================
# KEYBINDINGS — Pentesting-Optimized Layout
# ==============================================================================
keys = [
    # ── Navigation ────────────────────────────────────────────────────────────
    Key([MOD], "h",           lazy.layout.left(),            desc="Focus left"),
    Key([MOD], "l",           lazy.layout.right(),           desc="Focus right"),
    Key([MOD], "j",           lazy.layout.down(),            desc="Focus down"),
    Key([MOD], "k",           lazy.layout.up(),              desc="Focus up"),
    Key([MOD], "space",       lazy.layout.next(),            desc="Next window"),

    # ── Window movement ───────────────────────────────────────────────────────
    Key([MOD, "shift"], "h",  lazy.layout.shuffle_left(),    desc="Move left"),
    Key([MOD, "shift"], "l",  lazy.layout.shuffle_right(),   desc="Move right"),
    Key([MOD, "shift"], "j",  lazy.layout.shuffle_down(),    desc="Move down"),
    Key([MOD, "shift"], "k",  lazy.layout.shuffle_up(),      desc="Move up"),

    # ── Resize ────────────────────────────────────────────────────────────────
    Key([MOD, "control"], "h",lazy.layout.grow_left(),       desc="Shrink left"),
    Key([MOD, "control"], "l",lazy.layout.grow_right(),      desc="Grow right"),
    Key([MOD, "control"], "j",lazy.layout.grow_down(),       desc="Grow down"),
    Key([MOD, "control"], "k",lazy.layout.grow_up(),         desc="Grow up"),
    Key([MOD], "n",           lazy.layout.normalize(),        desc="Normalize"),
    Key([MOD], "m",           lazy.layout.maximize(),         desc="Maximize"),
    Key([MOD, "shift"], "m",  lazy.window.toggle_fullscreen(),desc="Fullscreen"),
    Key([MOD], "t",           lazy.window.toggle_floating(), desc="Float toggle"),

    # ── Applications ──────────────────────────────────────────────────────────
    Key([MOD], "Return",      lazy.spawn(TERM),               desc="Terminal"),
    Key([MOD], "b",           lazy.spawn("qutebrowser"),      desc="Browser"),
    Key([MOD], "d",           lazy.spawn("rofi -show drun"),  desc="App launcher"),
    Key([MOD], "r",           lazy.spawn("rofi -show run"),   desc="Run launcher"),
    Key([MOD, "shift"], "d",  lazy.spawn("rofi -show window"),desc="Window switcher"),
    Key([MOD], "e",           lazy.spawn(f"{TERM} -e nu"),    desc="Nushell"),
    Key([MOD, "shift"], "e",  lazy.spawn(f"{TERM} -e zsh"),   desc="Zsh"),

    # ── Ops shortcuts ─────────────────────────────────────────────────────────
    # Ephemeral Kali container
    Key([MOD, ALT], "k", lazy.spawn(
        f'{TERM} -e bash -c "incus launch images:kali/current ops-$RANDOM '
        '--ephemeral --profile ephemeral-ops && '
        'incus exec ops-$RANDOM -- /bin/bash"'
    ), desc="Kali ephemeral container"),

    # OSINT dashboard
    Key([MOD, ALT], "o", lazy.spawn(
        f"{TERM} -e uv run --with textual python ~/.config/kitty/osint_dashboard.py"
    ), desc="OSINT Dashboard"),

    # AI orchestrator
    Key([MOD, ALT], "a", lazy.spawn(
        f"{TERM} -e bash -c 'ollama run llama3.1'"
    ), desc="AI Shell"),

    # open-webui in browser
    Key([MOD, ALT], "w", lazy.spawn("qutebrowser http://127.0.0.1:8080"),
        desc="open-webui"),

    # Snapper pre-ops snapshot
    Key([MOD, ALT], "s", lazy.spawn(
        f'{TERM} -e bash -c \'sudo snapper -c root create '
        '--description "PRE-OPS: $(date +%Y-%m-%d)"\''
    ), desc="Snapper snapshot"),

    # Screenshot
    Key([MOD], "Print", lazy.spawn("sh -c 'grim ~/Screenshots/$(date +%s).png'"),
        desc="Screenshot"),
    Key([MOD, "shift"], "Print", lazy.spawn(
        "sh -c 'grim -g \"$(slurp)\" ~/Screenshots/$(date +%s).png'"
    ), desc="Screenshot region"),

    # ── Qtile management ──────────────────────────────────────────────────────
    Key([MOD, "shift"], "c",  lazy.window.kill(),             desc="Kill window"),
    Key([MOD, "control"], "r",lazy.reload_config(),           desc="Reload config"),
    Key([MOD, "control"], "q",lazy.shutdown(),                desc="Quit Qtile"),

    # ── Layout cycle ─────────────────────────────────────────────────────────
    Key([MOD], "Tab",          lazy.next_layout(),            desc="Next layout"),
    Key([MOD, "shift"], "Tab", lazy.prev_layout(),            desc="Prev layout"),

    # ── Volume / brightness (requires amixer / brightnessctl) ─────────────────
    Key([], "XF86AudioRaiseVolume",  lazy.spawn("amixer -q set Master 5%+"),  desc="Vol+"),
    Key([], "XF86AudioLowerVolume",  lazy.spawn("amixer -q set Master 5%-"),  desc="Vol-"),
    Key([], "XF86AudioMute",         lazy.spawn("amixer -q set Master toggle"),desc="Mute"),
    Key([], "XF86MonBrightnessUp",   lazy.spawn("brightnessctl set 5%+"),    desc="Bright+"),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 5%-"),    desc="Bright-"),
]

# ── KeyChord blocks for advanced ops ─────────────────────────────────────────
ops_chord = KeyChord([MOD], "o", [
    Key([], "k", lazy.spawn(f"{TERM} -e bash -c 'incus launch images:kali/current kali-$RANDOM --ephemeral --profile ephemeral-ops'"),
        desc="Kali"),
    Key([], "b", lazy.spawn(f"{TERM} -e bash -c 'incus launch images:archlinux/current blackarch-$RANDOM --ephemeral --profile ephemeral-ops'"),
        desc="BlackArch"),
    Key([], "l", lazy.spawn(f"{TERM} -e bash -c 'incus list'"),
        desc="List containers"),
    Key([], "s", lazy.spawn(f"{TERM} -e bash -c 'sudo snapper list'"),
        desc="Snapper list"),
    Key([], "n", lazy.spawn(f"{TERM} -e bash -c 'nmap -sV --script=default'"),
        desc="Nmap"),
    Key([], "m", lazy.spawn(f"{TERM} -e bash -c 'msfconsole'"),
        desc="Metasploit"),
    Key([], "t", lazy.spawn("qutebrowser https://duckduckgo.com"),
        desc="DDG"),
    Key([], "o", lazy.spawn("qutebrowser http://127.0.0.1:8080"),
        desc="AI WebUI"),
], name="ops")
keys.append(ops_chord)

# ==============================================================================
# WORKSPACES (Groups) — Pentesting workflow
# ==============================================================================
GROUPS_SPEC = [
    ("1", "󰣇",  "MAIN",     None),
    ("2", "󰙵",  "BROWSER",  [Match(wm_class="qutebrowser")]),
    ("3", "󰞦",  "RECON",    None),
    ("4", "󰢻",  "EXPLOIT",  None),
    ("5", "󱃖",  "AI",       None),
    ("6", "󰭹",  "COMMS",    None),
    ("7", "",   "FILES",    None),
    ("8", "󰙏",  "MONITOR",  None),
    ("9", "󱐋",  "MEDIA",    None),
]

groups = []
for key, icon, name, matches in GROUPS_SPEC:
    kwargs = {}
    if matches:
        kwargs["matches"] = matches
    groups.append(Group(f"{icon} {name}", **kwargs))
    keys += [
        Key([MOD], key,
            lazy.group[f"{icon} {name}"].toscreen(),
            desc=f"Switch to group {name}"),
        Key([MOD, "shift"], key,
            lazy.window.togroup(f"{icon} {name}", switch_group=True),
            desc=f"Move to group {name}"),
    ]

# ScratchPad — floating ops terminal
groups.append(ScratchPad("scratchpad", [
    DropDown("term",  TERM,       width=0.8, height=0.6, x=0.1, y=0.1),
    DropDown("nu",    f"{TERM} -e nu", width=0.8, height=0.6, x=0.1, y=0.1),
    DropDown("htop",  f"{TERM} -e btop", width=0.9, height=0.7, x=0.05, y=0.1),
    DropDown("notes", f"{TERM} -e nvim ~/notes.md", width=0.7, height=0.8, x=0.15, y=0.05),
]))
keys += [
    Key([MOD], "grave",      lazy.group["scratchpad"].dropdown_toggle("term")),
    Key([MOD, "shift"], "n", lazy.group["scratchpad"].dropdown_toggle("nu")),
    Key([MOD, "shift"], "b", lazy.group["scratchpad"].dropdown_toggle("htop")),
    Key([MOD, "shift"], "o", lazy.group["scratchpad"].dropdown_toggle("notes")),
]

# ==============================================================================
# LAYOUTS
# ==============================================================================
LAYOUT_THEME = dict(
    border_width=2,
    margin=6,
    border_focus=MAUVE,
    border_normal=SURFACE0,
)

layouts = [
    layout.Columns(**LAYOUT_THEME, border_focus_stack=BLUE, num_columns=2),
    layout.MonadTall(**LAYOUT_THEME, ratio=0.55),
    layout.MonadWide(**LAYOUT_THEME),
    layout.Bsp(**LAYOUT_THEME),
    layout.Matrix(**LAYOUT_THEME),
    layout.Max(),
    layout.Floating(**LAYOUT_THEME),
]

floating_layout = layout.Floating(
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),
        Match(wm_class="makebranch"),
        Match(wm_class="maketag"),
        Match(wm_class="ssh-askpass"),
        Match(title="branchdialog"),
        Match(title="pinentry"),
        Match(wm_class="nm-connection-editor"),
        Match(wm_class="pavucontrol"),
    ],
    **LAYOUT_THEME,
)

# ==============================================================================
# WIDGETS
# ==============================================================================
WIDGET_DEFAULTS = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=13,
    padding=4,
    background=BASE,
    foreground=TEXT,
)

SEP = widget.Sep(linewidth=0, padding=6, background=BASE)

def make_powerline_left(bg_from, bg_to):
    return widget.TextBox(text="", fontsize=22, padding=0,
                          background=bg_to, foreground=bg_from)

def make_powerline_right(bg_from, bg_to):
    return widget.TextBox(text="", fontsize=22, padding=0,
                          background=bg_from, foreground=bg_to)

def build_bar():
    widgets = [
        # Logo
        widget.TextBox(
            text=" 󰣇 ",
            fontsize=16,
            background=MAUVE,
            foreground=CRUST,
            mouse_callbacks={"Button1": lazy.spawn("rofi -show drun")},
        ),
        make_powerline_left(MAUVE, SURFACE0),

        # Groups
        widget.GroupBox(
            font="JetBrainsMono Nerd Font",
            fontsize=13,
            margin_y=3,
            margin_x=4,
            padding_y=5,
            padding_x=6,
            borderwidth=2,
            active=TEXT,
            inactive=OVERLAY0,
            rounded=True,
            highlight_color=[SURFACE0, SURFACE0],
            highlight_method="line",
            this_current_screen_border=MAUVE,
            this_screen_border=BLUE,
            other_current_screen_border=TEAL,
            other_screen_border=SURFACE1,
            background=SURFACE0,
            foreground=TEXT,
            urgent_alert_method="line",
            urgent_border=RED,
        ),
        make_powerline_left(SURFACE0, BASE),

        SEP,

        # Current layout icon
        widget.CurrentLayoutIcon(scale=0.7, background=BASE),
        widget.CurrentLayout(background=BASE, foreground=MAUVE),

        SEP,

        # Window name
        widget.WindowName(
            background=BASE,
            foreground=SUBTEXT,
            format="{name}",
            max_chars=50,
        ),

        # ── Right side ───────────────────────────────────────────────────────
        widget.Spacer(),

        # Chord mode indicator
        widget.Chord(
            chords_colors={"ops": (PEACH, CRUST)},
            name_transform=lambda name: name.upper(),
        ),

        make_powerline_right(BASE, SURFACE1),

        # Network
        widget.TextBox(text=" 󰈀", background=SURFACE1, foreground=BLUE),
        widget.Net(
            interface="auto",
            format="{down} ↓ {up} ↑",
            background=SURFACE1,
            foreground=TEXT,
        ),

        make_powerline_right(SURFACE1, SURFACE0),

        # CPU
        widget.TextBox(text=" ", background=SURFACE0, foreground=PEACH),
        widget.CPU(
            format="{load_percent:.0f}%",
            background=SURFACE0,
            foreground=TEXT,
            update_interval=2,
        ),

        # RAM
        widget.TextBox(text="  ", background=SURFACE0, foreground=GREEN),
        widget.Memory(
            format="{MemUsed:.0f}{mm}/{MemTotal:.0f}{mm}",
            measure_mem="G",
            background=SURFACE0,
            foreground=TEXT,
            update_interval=3,
        ),

        make_powerline_right(SURFACE0, SURFACE1),

        # Clock
        widget.TextBox(text=" 󰸗", background=SURFACE1, foreground=MAUVE),
        widget.Clock(
            format="%a %d %b  %H:%M",
            background=SURFACE1,
            foreground=TEXT,
        ),

        make_powerline_right(SURFACE1, MAUVE),

        # System tray
        widget.Systray(background=MAUVE, padding=4),
        widget.TextBox(text=" ", background=MAUVE),
    ]
    return bar.Bar(widgets, 32, background=BASE, opacity=0.95, margin=[4, 6, 0, 6])


# ==============================================================================
# SCREENS
# ==============================================================================
screens = [
    Screen(top=build_bar()),
]

# ==============================================================================
# MOUSE
# ==============================================================================
mouse = [
    Drag([MOD], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([MOD], "Button3", lazy.window.set_size_floating(),     start=lazy.window.get_size()),
    Click([MOD], "Button2", lazy.window.bring_to_front()),
]

# ==============================================================================
# HOOKS
# ==============================================================================
@hook.subscribe.startup_once
def autostart():
    """Autostart applications on first Qtile launch."""
    progs = [
        ["feh", "--bg-fill", os.path.expanduser("~/.local/share/wallpapers/catppuccin-mocha.png")],
        ["picom", "--daemon"],
        ["dunst"],
    ]
    for prog in progs:
        try:
            subprocess.Popen(prog)
        except FileNotFoundError:
            pass  # Gracefully skip missing autostart binaries

@hook.subscribe.client_new
def assign_app_group(client):
    """Auto-assign specific apps to dedicated groups."""
    wm_class = client.window.get_wm_class()
    if not wm_class:
        return
    wm_class = wm_class[0].lower() if isinstance(wm_class, (list, tuple)) else wm_class.lower()
    rules = {
        "qutebrowser": "󰙵 BROWSER",
        "firefox":     "󰙵 BROWSER",
    }
    target = rules.get(wm_class)
    if target:
        client.togroup(target)

# ==============================================================================
# GLOBAL SETTINGS
# ==============================================================================
dgroups_key_binder        = None
dgroups_app_rules         = []
follow_mouse_focus        = True
bring_front_click         = False
floats_kept_above         = True
cursor_warp               = False
auto_fullscreen           = True
focus_on_window_activation = "smart"
reconfigure_screens       = True
auto_minimize             = True
wl_input_rules            = None
wmname                    = "LG3D"
