# ~/.config/nushell/config.nu
# whyCARE v3 — Sovereign Nushell Shell Engine
# Fully typed pipeline orchestration for pentesting + AI workflows

# ==============================================================================
# CORE CONFIGURATION
# ==============================================================================
$env.config = {
    show_banner: false
    render_right_prompt_on_last_line: false

    history: {
        file_format: "sqlite"
        max_results: 50000
        sync_on_enter: true
        isolation: true          # Prevent bleed across sessions
    }

    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
        use_ls_colors: true
    }

    filesize: {
        metric: false            # Show GiB not GB
        format: "auto"
    }

    cursor_shape: {
        emacs: line
        vi_insert: line
        vi_normal: block
    }

    color_config: (catppuccin_mocha)

    use_grid_icons: true
    footer_mode: "25"            # Show footer for tables > 25 rows
    float_precision: 2
    use_ansi_coloring: true
    bracketed_paste: true
    edit_mode: emacs
    shell_integration: {
        osc2: true
        osc7: true
        osc8: true
        osc9_9: false
        osc133: true
        osc633: true
        reset_application_mode: true
    }

    table: {
        mode: rounded
        index_mode: always
        show_empty: true
        padding: { left: 1, right: 1 }
        trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
            truncating_suffix: "..."
        }
        header_on_separator: false
    }

    datetime_format: {
        normal: '%a, %d %b %Y %H:%M:%S %z'
        table: '%d %b %Y %H:%M'
    }

    explore: {
        status_bar_background: { fg: "#cdd6f4", bg: "#313244" }
        command_bar_text: { fg: "#cdd6f4" }
        highlight: { fg: "#1e1e2e", bg: "#cba6f7" }
        status: {
            error:   { fg: "#f38ba8" }
            warn:    { fg: "#f9e2af" }
            info:    { fg: "#89b4fa" }
        }
        selected_cell: { bg: "#45475a" }
    }

    hooks: {
        pre_prompt:     [{ null }]
        pre_execution:  [{ null }]
        env_change: {
            PWD: [
                { |before, after|
                    # Auto-activate .env files (simple .env loader)
                    if ($after | path join ".env" | path exists) {
                        let env_file = ($after | path join ".env")
                        open $env_file
                            | lines
                            | where { |l| ($l | str trim | str starts-with "#" | not $in) and ($l | str trim | is-not-empty) }
                            | each { |l|
                                let pair = ($l | split row "=" | first 2)
                                if ($pair | length) >= 2 {
                                    load-env { ($pair | first): ($pair | last) }
                                }
                            }
                    }
                }
            ]
        }
        display_output: {
            if (term size).columns >= 100 { table -e } else { table }
        }
        command_not_found: {
            |cmd_name|
            # Try nix-run via comma if command not found (requires comma in PATH)
            if (which , | is-not-empty) {
                $"Try: , ($cmd_name)"
            }
        }
    }

    menus: [
        { name: completion_menu,      only_buffer_difference: false, marker: "| ", type: { layout: columnar, columns: 4, col_padding: 2 }, style: { text: green_bold, selected_text: { bg: "#cba6f7", fg: "#1e1e2e" }, description_text: "#a6adc8" } }
        { name: history_menu,         only_buffer_difference: true,  marker: "? ", type: { layout: list, page_size: 10 }, style: { text: green_bold, selected_text: { bg: "#89b4fa", fg: "#1e1e2e" }, description_text: "#a6adc8" } }
        { name: help_menu,            only_buffer_difference: true,  marker: "? ", type: { layout: description, columns: 4, col_width: 20, col_padding: 2, selection_rows: 4, description_rows: 10 }, style: { text: green_bold, selected_text: { bg: "#cba6f7", fg: "#1e1e2e" }, description_text: "#a6adc8" } }
    ]

    keybindings: [
        { name: completion_menu,       modifier: none,    keycode: tab,       mode: [emacs vi_normal vi_insert], event: { until: [ { send: menu name: completion_menu }, { send: menunext } ] } }
        { name: history_menu,          modifier: control, keycode: char_r,    mode: [emacs vi_normal vi_insert], event: { send: menu name: history_menu } }
        { name: next_page,             modifier: control, keycode: char_x,    mode: emacs, event: { until: [ { send: historyhintcomplete }, { send: menupagenext } ] } }
        { name: undo_or_previous_page, modifier: control, keycode: char_z,    mode: emacs, event: { until: [ { send: menupageprevious }, { send: undo } ] } }
        { name: escape,                modifier: none,    keycode: escape,     mode: emacs, event: { send: esc } }
        { name: cancel_command,        modifier: control, keycode: char_c,    mode: emacs, event: { send: ctrlc } }
        { name: clear_screen,          modifier: control, keycode: char_l,    mode: emacs, event: { send: clearscreen } }
        { name: search_history,        modifier: control, keycode: char_q,    mode: emacs, event: { send: searchhistory } }
        { name: open_command_editor,   modifier: control, keycode: char_o,    mode: emacs, event: { send: openeditor } }
        { name: move_up,               modifier: none,    keycode: up,        mode: emacs, event: { until: [ { send: historyhintupordown }, { send: up } ] } }
        { name: move_down,             modifier: none,    keycode: down,      mode: emacs, event: { until: [ { send: historyhintupordown }, { send: down } ] } }
        { name: move_end,              modifier: none,    keycode: end,       mode: emacs, event: { send: movetolineend } }
        { name: move_home,             modifier: none,    keycode: home,      mode: emacs, event: { send: movetolinestart } }
        { name: move_word_right,       modifier: control, keycode: right,     mode: emacs, event: { send: movewordright } }
        { name: move_word_left,        modifier: control, keycode: left,      mode: emacs, event: { send: movewordleft } }
        { name: delete_word,           modifier: control, keycode: backspace, mode: emacs, event: { send: backspaceword } }
        { name: yank,                  modifier: control, keycode: char_y,    mode: emacs, event: { send: paste } }
    ]
}

# ==============================================================================
# CATPPUCCIN MOCHA COLOR THEME
# ==============================================================================
def catppuccin_mocha [] {
    {
        separator:                   "#45475a"
        leading_trailing_space_bg:   { attr: n }
        header:                      { fg: "#cba6f7" attr: b }
        empty:                       "#89b4fa"
        bool:                        { |b| if $b { "#a6e3a1" } else { "#f38ba8" } }
        int:                         "#cba6f7"
        filesize:                    { |b|
            if $b == 0b     { "#6c7086" }
            else if $b < 1mb { "#94e2d5" }
            else if $b < 1gb { "#89b4fa" }
            else             { "#f38ba8" }
        }
        duration:                    "#f9e2af"
        date:                        { (date now) - $in |
            if $in < 1hr   { { fg: "#f38ba8" attr: b } }
            else if $in < 6hr   { "#f38ba8" }
            else if $in < 1day  { "#f9e2af" }
            else if $in < 3day  { "#a6e3a1" }
            else if $in < 1wk   { { fg: "#a6e3a1" attr: b } }
            else if $in < 6wk   { "#94e2d5" }
            else                { "#6c7086" }
        }
        range:                       "#f9e2af"
        float:                       "#f9e2af"
        string:                      "#a6e3a1"
        nothing:                     "#6c7086"
        binary:                      "#f5c2e7"
        cell-path:                   "#cdd6f4"
        row_index:                   { fg: "#b4befe" attr: b }
        record:                      { fg: "#94e2d5" }
        list:                        { fg: "#89b4fa" }
        block:                       { fg: "#cba6f7" }
        hints:                       "#6c7086"
        search_result:               { fg: "#f38ba8" bg: "#313244" }
        shape_and:                   { fg: "#cba6f7" attr: b }
        shape_binary:                { fg: "#f5c2e7" attr: b }
        shape_block:                 { fg: "#89b4fa" attr: b }
        shape_bool:                  "#a6e3a1"
        shape_closure:               { fg: "#94e2d5" attr: b }
        shape_custom:                "#a6e3a1"
        shape_datetime:              { fg: "#94e2d5" attr: b }
        shape_directory:             "#94e2d5"
        shape_external:              "#94e2d5"
        shape_external_resolved:     "#a6e3a1"
        shape_externalarg:           { fg: "#a6e3a1" attr: b }
        shape_filepath:              "#94e2d5"
        shape_flag:                  { fg: "#89b4fa" attr: b }
        shape_float:                 { fg: "#f9e2af" attr: b }
        shape_garbage:               { fg: "#ffffff" bg: "#f38ba8" attr: b }
        shape_glob_interpolation:    { fg: "#94e2d5" attr: b }
        shape_globpattern:           { fg: "#94e2d5" attr: b }
        shape_int:                   { fg: "#cba6f7" attr: b }
        shape_internalcall:          { fg: "#94e2d5" attr: b }
        shape_keyword:               { fg: "#cba6f7" attr: b }
        shape_list:                  { fg: "#89b4fa" attr: b }
        shape_literal:               "#89b4fa"
        shape_match_pattern:         "#a6e3a1"
        shape_matching_brackets:     { attr: u }
        shape_nothing:               "#6c7086"
        shape_operator:              "#f9e2af"
        shape_or:                    { fg: "#cba6f7" attr: b }
        shape_pipe:                  { fg: "#cba6f7" attr: b }
        shape_range:                 { fg: "#f9e2af" attr: b }
        shape_record:                { fg: "#94e2d5" attr: b }
        shape_redirection:           { fg: "#cba6f7" attr: b }
        shape_signature:             { fg: "#a6e3a1" attr: b }
        shape_string:                "#a6e3a1"
        shape_string_interpolation:  { fg: "#94e2d5" attr: b }
        shape_table:                 { fg: "#89b4fa" attr: b }
        shape_vardecl:               { fg: "#89b4fa" attr: u }
        shape_variable:              "#cba6f7"
    }
}

# ==============================================================================
# ALIASES
# ==============================================================================
alias ll = ls -la
alias la = ls -a
alias v  = nvim
alias g  = git
alias lg = lazygit
alias cat = bat --style=plain
alias top = btop
alias myip = (http get https://ipinfo.io/json)

# Nix
alias nrs   = (nix run home-manager -- switch --flake ~/.config/home-manager#operator)
alias nup   = (cd ~/.config/home-manager; nix flake update; nix run home-manager -- switch --flake '.#operator')

# System
alias snap  = (sudo snapper -c root create --description)
alias ops   = (incus list)
alias kali  = (incus launch images:kali/current $"kali-(date now | format date '%s')" --ephemeral --profile ephemeral-ops)

# ==============================================================================
# WATCHDOG-ARBITRAGE — Secure OSINT ingestion (fixes from v2)
# Reads QUTE_URL from environment; proxies via sovereign_proxy file.
# DNS leak prevention: uses socks5h (DNS through proxy) not socks5.
# ==============================================================================
def watchdog-arbitrage [
    --model(-m): string = "llama3.1"  # Ollama model to use
] {
    let target_url = ($env | get -i QUTE_URL | default "")
    if ($target_url | is-empty) {
        print "[-] Error: QUTE_URL environment variable is not set."
        return
    }

    let target_graph = ($env.HOME | path join "logseq_graph" "journals")
    mkdir $target_graph
    let timestamp = (date now | format date "%Y_%m_%d")
    let target_file = ($target_graph | path join $"($timestamp).md")

    print $"[+] Arbitrage target: ($target_url)"

    # ── FIXED: Proxy routing with socks5h (DNS over proxy, prevents leaks) ────
    let proxy_file = ($env.HOME | path join ".cache" "sovereign_proxy")
    let proxy_arg: list<string> = (
        if ($proxy_file | path exists) {
            let p = (open $proxy_file | str trim)
            if ($p | is-not-empty) { ["--proxy" $p] } else { [] }
        } else { [] }  # FIXED: explicit empty list, not missing else branch
    )

    print $"[+] Proxy args: ($proxy_arg | str join ' ')"

    # ── FIXED: curl with socks5h to prevent clearnet DNS leaks ────────────────
    let raw_html = (
        if ($proxy_arg | is-empty) {
            ^curl -sL --max-time 15 $target_url
        } else {
            ^curl -sL --proxy ($proxy_arg | get 1) --max-time 15 $target_url
        }
    )

    # Strip HTML tags with basic sed-equivalent
    let raw_content = ($raw_html | str replace --all --regex '<[^>]*>' ' ' | str replace --all --regex '\s+' ' ' | str trim)

    if ($raw_content | is-empty) {
        print "[-] No content retrieved — check URL and proxy settings."
        return
    }

    print $"[+] Sending ($raw_content | str length) bytes to Ollama ($model)..."

    # ── FIXED: Local Ollama is isolated from proxy — direct loopback call ─────
    let query_payload = ({
        model: $model
        prompt: $"You are a cybersecurity OSINT analyst. Extract threat vectors, IOCs, technical summaries, and intelligence from:\n\n($raw_content)"
        stream: false
    } | to json)

    let ai_response = (
        ^curl -sS -X POST http://127.0.0.1:11434/api/generate
            -H "Content-Type: application/json"
            -d $query_payload
        | from json
        | get response
    )

    let tags = ["whycare" "osint" "capture"]
    let formatted_tags = ($tags | each { |t| $"#($t)" } | str join " ")

    let markdown_entry = $"
- **Sovereign OSINT Arbitrage**
  - **Timestamp**: (date now | format date \"%Y-%m-%d %H:%M:%S\")
  - **Source**: [($target_url)](($target_url))
  - **Tags**: ($formatted_tags)
  - **Model**: ($model)
  - **Analysis**:
($ai_response | lines | each { |l| $"    - ($l)" } | str join \"\n\")
"
    $markdown_entry | save --append $target_file
    print $"[+] Ingestion complete → ($target_file)"
}

# ==============================================================================
# WATCHDOG-SUMMARIZE — Highlight text analysis (fixes from v2)
# ==============================================================================
def watchdog-summarize [
    --model(-m): string = "llama3.1"
    --clipboard(-c)     # Also write to Wayland clipboard
] {
    let text = ($env | get -i QUTE_SELECTED_TEXT | default "")
    if ($text | is-empty) {
        print "[-] QUTE_SELECTED_TEXT is empty."
        return
    }

    let target_graph = ($env.HOME | path join "logseq_graph" "journals")
    mkdir $target_graph
    let target_file = ($target_graph | path join $"(date now | format date \"%Y_%m_%d\").md")

    let query_payload = ({
        model: $model
        prompt: $"Provide a concise cybersecurity summary of the following text. Highlight any IOCs, CVEs, or actionable intelligence:\n\n($text)"
        stream: false
    } | to json)

    print $"[+] Summarizing (($text | str length)) chars with ($model)..."

    # FIXED: Loopback call explicitly bypasses any proxy environment
    let summary = (
        ^curl -sS -X POST http://127.0.0.1:11434/api/generate
            -H "Content-Type: application/json"
            -d $query_payload
        | from json
        | get response
    )

    if $clipboard {
        # Write to Wayland clipboard
        $summary | ^wl-copy
        print "[+] Summary copied to clipboard ✓"
    }

    let entry = $"
- **Sovereign Highlight Analysis**
  - **Timestamp**: (date now | format date \"%Y-%m-%d %H:%M:%S\")
  - **Characters analyzed**: ($text | str length)
  - **Model**: ($model)
  - **Summary**: ($summary)
"
    $entry | save --append $target_file
    print $"[+] Summary saved → ($target_file)"
    print ""
    print "── SUMMARY ──────────────────────────────────────────────────────"
    print $summary
}

# ==============================================================================
# AI PIPELINE COMMANDS
# ==============================================================================

# Analyze any structured nushell data with local LLM
def ai-analyze [
    context?: string  # Optional context hint for the model
    --model(-m): string = "llama3.1"
] {
    let data = ($in | to json)
    let prompt = if ($context | is-empty) {
        $"Analyze this data for security anomalies, privilege escalation patterns, or suspicious activity:\n\n($data)"
    } else {
        $"Context: ($context)\n\nAnalyze this data:\n\n($data)"
    }

    let payload = ({ model: $model, prompt: $prompt, stream: false } | to json)

    ^curl -sS -X POST http://127.0.0.1:11434/api/generate \
        -H "Content-Type: application/json" \
        -d $payload
    | from json
    | get response
    | print $in
}

# Example: ps | ai-analyze "look for privilege escalation"
# Example: ls -la | ai-analyze --model codellama:13b

# Analyze Incus container logs
def ai-container-logs [name: string, --lines(-n): int = 200, --model(-m): string = "llama3.1"] {
    incus exec $name -- journalctl -n $lines --no-pager
    | ai-analyze $"Forensic analysis of Incus container '($name)': look for lateral movement, data exfiltration, privilege escalation" --model $model
}

# Analyze running process list
def ai-ps [--model(-m): string = "llama3.1"] {
    ps | ai-analyze "Identify suspicious processes, unexpected root processes, or anomalous resource usage" --model $model
}

# Analyze network connections
def ai-net [--model(-m): string = "llama3.1"] {
    ^ss -anp
    | lines
    | ai-analyze "Identify suspicious network connections, unexpected listeners, or exfiltration channels" --model $model
}

# ==============================================================================
# RECON COMMANDS
# ==============================================================================

# Quick target recon — runs nmap in background, saves to ~/recon/
def recon [target: string, --full(-f)] {
    let outdir = ($env.HOME | path join "recon" $"(date now | format date \"%Y%m%d_%H%M%S\")_($target | str replace '/' '_')")
    mkdir $outdir

    let flags = if $full {
        ["-sV" "-sC" "-O" "--script=vuln" "-oN" ($outdir | path join "full.nmap")]
    } else {
        ["-sV" "--script=default" "-oN" ($outdir | path join "default.nmap")]
    }

    print $"[*] Starting recon on ($target) → ($outdir)"
    print $"[*] Flags: ($flags | str join ' ')"

    # Background nmap
    ^bash -c $"nmap ($flags | str join ' ') ($target) &"
    print $"[*] Nmap running in background. Monitor: tail -f ($outdir | path join 'default.nmap')"
    $outdir
}

# Incus ephemeral ops launcher
def kops [
    image?: string = "images:kali/current"
    --name(-n): string = ""
    --cpu(-c): int = 4
    --mem(-m): string = "8GB"
] {
    let container_name = if ($name | is-empty) {
        $"ops-(date now | format date '%s')"
    } else {
        $name
    }

    print $"[+] Launching ephemeral container: ($container_name)"

    ^incus launch $image $container_name \
        --ephemeral \
        --profile ephemeral-ops \
        -c $"limits.cpu=($cpu)" \
        -c $"limits.memory=($mem)"

    sleep 2sec
    ^incus exec $container_name -- /bin/bash
}

# ==============================================================================
# SYSTEM MONITORING COMMANDS
# ==============================================================================

# Live hardware stats (AMD RX 480 + Intel X299)
def hw-stats [] {
    let cpu = (open /proc/stat | lines | first | split row " " | skip 1 | take 10 | each { |x| $x | into int })
    let mem = (open /proc/meminfo | lines | take 3 | each { |l| $l | parse "{key}: {val} {unit}" | first })
    let gpu_busy = (
        if ("/sys/class/drm/card0/device/gpu_busy_percent" | path exists) {
            open /sys/class/drm/card0/device/gpu_busy_percent | str trim
        } else { "N/A" }
    )
    let vram_used = (
        if ("/sys/class/drm/card0/device/mem_info_vram_used" | path exists) {
            open /sys/class/drm/card0/device/mem_info_vram_used | str trim | into int | $in / 1073741824 | math round --precision 2
        } else { 0 }
    )
    let vram_total = (
        if ("/sys/class/drm/card0/device/mem_info_vram_total" | path exists) {
            open /sys/class/drm/card0/device/mem_info_vram_total | str trim | into int | $in / 1073741824 | math round --precision 2
        } else { 8 }
    )

    {
        "CPU cores": 12
        "GPU load": $"($gpu_busy)%"
        "VRAM": $"($vram_used) / ($vram_total) GiB"
        "Ollama": (if (^curl -fs http://localhost:11434/api/tags | complete | get exit_code) == 0 { "ONLINE" } else { "OFFLINE" })
        "Containers": (^incus list --format csv | lines | length)
    }
}

# Quick OPSEC check
def opsec-check [] {
    print "── OPSEC STATUS ─────────────────────────────────────────────────"

    # VPN check
    let vpn = (open /proc/net/dev | lines | any { |l| $l =~ "tun0|wg0|tailscale0" })
    if $vpn { print "✓ VPN tunnel interface detected" } else { print "⚠ No VPN tunnel interface" }

    # Tor check
    let tor = (^bash -c "timeout 0.5 bash -c 'echo > /dev/tcp/127.0.0.1/9050' 2>/dev/null && echo ok || echo no" | str trim) == "ok"
    if $tor { print "✓ Tor SOCKS5 listening on :9050" } else { print "⚠ Tor SOCKS5 not active" }

    # Ollama check
    let ollama_ok = (^curl -fs http://localhost:11434/api/tags | complete | get exit_code) == 0
    if $ollama_ok { print "✓ Ollama API responding" } else { print "⚠ Ollama not responding" }

    # Snapper baseline
    let snaps = (^snapper -c root list --output-fields number,date,description | lines | length)
    print $"✓ ($snaps) BTRFS snapshots available"

    # Containers
    let containers = (^incus list --format csv | lines)
    print $"  Containers: ($containers | length) running"
    $containers | each { |c| print $"    ↳ ($c)" }

    print "─────────────────────────────────────────────────────────────────"
}
