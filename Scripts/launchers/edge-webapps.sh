#!/usr/bin/env bash
# RaVN alt-browser webapps — second accounts / separate browser profiles
# Re-run via: bash ~/Work/RaVN/dev/Scripts/launchers/install_launchers.sh
#
# Syntax:
#   ravn_browser_webapp_install 'Name' 'URL' 'icon.png'
#   ravn_browser_webapp_install 'Name' 'URL' 'icon.png' 'microsoft-edge-stable' '--profile-directory=Profile 2'
#
# Defaults (override per session if needed):
#   RAVN_ALT_BROWSER=microsoft-edge-stable

RAVN_ALT_BROWSER="${RAVN_ALT_BROWSER:-microsoft-edge-stable}"

# Second WhatsApp account via Edge (separate from omarchy-launch-webapp WhatsApp)
ravn_browser_webapp_install 'WhatsApp 2' 'https://web.whatsapp.com/' 'WhatsApp.png'

# Second X account via Edge (separate from omarchy-launch-webapp X)
ravn_browser_webapp_install 'X 2' 'https://x.com/home' 'X.png'

# Examples for additional second-account apps:
# ravn_browser_webapp_install 'Gmail Work' 'https://mail.google.com/' 'Gmail.png' "$RAVN_ALT_BROWSER" '--profile-directory=Profile 2'
# ravn_browser_webapp_install 'Discord 2' 'https://discord.com/channels/@me' 'Discord.png' 'brave-browser' '--profile-directory=Work'