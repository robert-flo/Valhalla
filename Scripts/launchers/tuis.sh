#!/usr/bin/env bash
# RaVN TUI/custom launchers — uses local icons from ~/.local/share/applications/icons/
# Re-run via: bash ~/Work/RaVN/dev/Scripts/launchers/install_launchers.sh

ICON_DIR="$HOME/.local/share/applications/icons"

ravn_launcher_install 'Antigravity CLI' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e agy'\''' 'Antigravity CLI.png' '--comment=Antigravity TUI Client' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_tui_install 'Disk Usage' 'dua i' 'float' "$ICON_DIR/Disk Usage.png"
ravn_tui_install 'Docker' 'lazydocker' 'tile' "$ICON_DIR/Docker.png"
ravn_launcher_install 'Grok Build' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e grok'\''' 'Grok AI.png' '--comment=Grok Build CLI / xAI Agent' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'Herdr' 'xdg-terminal-exec --app-id=TUI.tile -e herdr' 'utilities-terminal' '--comment=Herdr CLI Tool' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'Hermes Desktop' 'hermes desktop' 'Hermes.png' '--comment=Hermes Desktop Application' '--categories=Development;'
ravn_launcher_install 'Hermes TUI' 'kitty --class=hermes-tui --title="Hermes Agent" -e hermes --tui' 'Hermes.png' '--comment=Hermes Terminal Agent' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'Hermes Web' 'sh -c '\''~/.hermes/hermes-agent/venv/bin/hermes dashboard'\''' 'Hermes.png' '--comment=Hermes Web Dashboard'
ravn_tui_install 'MiMoCode TUI' 'mimo' 'tile' "$ICON_DIR/mimo.png"
ravn_tui_install 'Qwen Code TUI' 'qwen' 'tile' "$ICON_DIR/Qwen ai.png"
ravn_tui_install 'OpenClaude TUI' 'openclaude' 'tile' "$ICON_DIR/Claude AI.png"
ravn_tui_install 'OpenClaw TUI' 'openclaw tui --session main' 'tile' "$ICON_DIR/OpenClaw.png"
ravn_launcher_install 'OpenCode Desktop' 'sh -c '\''cd "$HOME/src" && exec opencode-desktop %U'\''' 'OpenCode.png' '--comment=OpenCode Desktop Application' '--categories=Development;' '--mimetype=x-scheme-handler/opencode;' '--startupwmclass=opencode-desktop'
ravn_launcher_install 'OpenCode TUI' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e opencode'\''' 'OpenCode.png' '--comment=OpenCode Terminal UI Agent' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'OpenCode Web' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e opencode web'\''' 'OpenCode.png' '--comment=OpenCode Web Agent Interface' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'command-code' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e cmd'\''' 'command-code.png' '--comment=Command Code - Coding agent that continuously learns your taste of writing code' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_launcher_install 'lyricify' 'kitty --class=lyricify --title="Lyricify" -e lyricify' 'spotify' '--name=Lyricify' '--comment=Terminal tool to display synced Spotify lyrics' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;' '--startupnotify=false'
ravn_launcher_install 'ncdu' 'kitty --class=ncdu --title="Disk Usage Analyzer" -e ncdu' 'ncdu.png' '--name=Terminal Disk Usage Analizer' '--comment=Check disk space usage in kitty terminal' '--genericname=Disk Usage Analyzer' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;' '--startupnotify=false'
ravn_launcher_install 'omp TUI' 'sh -c '\''cd "$HOME/src" && exec xdg-terminal-exec --app-id=TUI.tile -e omp'\''' 'omp.png' '--name=oh my pi · the harness' '--comment=omp Terminal UI Agent' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;'
ravn_tui_install 'Zero TUI' 'zero' 'tile' "$ICON_DIR/zero.png"
ravn_launcher_install 'Codex TUI' 'sh -c '\''exec xdg-terminal-exec --app-id=TUI.tile -e codex --dangerously-bypass-approvals-and-sandbox'\''' "$ICON_DIR/ChatGPT.png" '--comment=Codex CLI — AI coding agent (bypass approvals)' '--categories=ConsoleOnly;TUI;Utility;' '--keywords=tui;terminal;cli;codex;ai;'
