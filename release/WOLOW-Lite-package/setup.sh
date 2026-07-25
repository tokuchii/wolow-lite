#!/usr/bin/env bash
# WOLOW Lite - PC Setup (Linux/macOS)
# Enables network access for the WOLOW agent and Wake-on-LAN.
set -e

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "  [!] This script requires administrator privileges."
    echo "  Re-running with sudo..."
    echo ""
    exec sudo "$0" "$@"
fi

echo ""
echo "  ============================================"
echo "   WOLOW Lite - PC Setup"
echo "  ============================================"
echo ""
echo "  This will configure your PC for remote control."
echo ""

# Detect OS
OS="$(uname -s)"

# --- Open firewall ports for the agent ---
echo "  [1/4] Configuring firewall..."

if [ "$OS" = "Linux" ]; then
    if command -v ufw &>/dev/null; then
        sudo ufw allow 8220/tcp 2>/dev/null || true
        sudo ufw allow 8221/udp 2>/dev/null || true
        echo "      Added ufw rules for ports 8220 (TCP) and 8221 (UDP)."
    elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --permanent --add-port=8220/tcp 2>/dev/null || true
        sudo firewall-cmd --permanent --add-port=8221/udp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        echo "      Added firewalld rules for ports 8220 (TCP) and 8221 (UDP)."
    else
        echo "      No firewall manager detected (ufw/firewalld). Skipping."
        echo "      If you have a firewall, manually allow ports 8220/tcp and 8221/udp."
    fi
elif [ "$OS" = "Darwin" ]; then
    echo "      macOS uses application-level firewall. No changes needed."
    echo "      The OS will prompt you to allow incoming connections when the agent starts."
fi
echo ""

# --- Check for agent dependencies ---
echo "  [2/4] Checking Python agent..."
if command -v python3 &>/dev/null; then
    echo "      Python 3 found: $(python3 --version 2>&1)"
else
    echo "      [!] Python 3 not found. Install it before running the agent."
    echo "         macOS:  brew install python3"
    echo "         Ubuntu/Debian: sudo apt install python3 python3-pip"
fi
echo ""

# --- Install and start agent ---
echo "  [3/4] Setting up WOLOW Agent..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="${SCRIPT_DIR}/pc_agent"

if [ ! -d "$AGENT_DIR" ]; then
    echo "      [!] pc_agent/ directory not found. Skipping agent setup."
else
    if command -v python3 &>/dev/null; then
        # Install dependencies
        echo "      Installing agent dependencies..."
        pip3 install -r "${AGENT_DIR}/requirements.txt" --quiet 2>/dev/null
        echo "      Dependencies installed."

        # Generate token (only if missing)
        if [ ! -f "${AGENT_DIR}/config.yaml" ]; then
            echo "      Generating authentication token..."
            python3 "${AGENT_DIR}/generate_token.py"
            echo ""
        else
            echo "      Config already exists, keeping existing token."
        fi

        # Open firewall ports for agent
        echo "      Opening firewall ports for agent..."
        if [ "$OS" = "Linux" ]; then
            if command -v ufw &>/dev/null; then
                sudo ufw allow 8220/tcp 2>/dev/null || true
                sudo ufw allow 8221/udp 2>/dev/null || true
                echo "      Added ufw rules for agent ports."
            elif command -v firewall-cmd &>/dev/null; then
                sudo firewall-cmd --permanent --add-port=8220/tcp 2>/dev/null || true
                sudo firewall-cmd --permanent --add-port=8221/udp 2>/dev/null || true
                sudo firewall-cmd --reload 2>/dev/null || true
                echo "      Added firewalld rules for agent ports."
            fi
        fi

        # Auto-start agent on boot
        PYTHON_PATH="$(which python3)"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            PLIST_PATH="$HOME/Library/LaunchAgents/com.wolow.agent.plist"
            mkdir -p "$HOME/Library/LaunchAgents"
            cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wolow.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>${PYTHON_PATH}</string>
        <string>${AGENT_DIR}/agent.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${AGENT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            launchctl load "$PLIST_PATH"
            echo "      Agent will auto-start on login (launchd)."
        else
            if command -v systemctl &>/dev/null; then
                sudo tee /etc/systemd/system/wolow-agent.service > /dev/null <<SERVICE
[Unit]
Description=WOLOW Lite PC Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=${AGENT_DIR}
ExecStart=${PYTHON_PATH} ${AGENT_DIR}/agent.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
                sudo systemctl daemon-reload
                sudo systemctl enable wolow-agent
                sudo systemctl start wolow-agent
                echo "      Agent will auto-start on boot (systemd)."
            else
                echo "      Warning: systemctl not found. Agent may need manual start."
                echo "      Run: cd pc_agent && python3 agent.py"
            fi
        fi

        # Start agent now
        echo "      Starting WOLOW agent now..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "      Agent is running via launchd."
        else
            echo "      Agent is running via systemd."
        fi
    else
        echo "      [!] Python 3 not found. Skipping agent setup."
        echo "      Install Python 3, then run: cd pc_agent && bash setup.sh"
    fi
fi
echo ""

# --- WoL info ---
echo "  [4/4] Wake-on-LAN reminder..."
echo ""
echo "  To enable Wake-on-LAN on this machine:"
echo ""
if [ "$OS" = "Linux" ]; then
    echo "    1. Enable WoL in your BIOS/UEFI settings"
    echo "    2. Enable WoL on your network interface:"
    echo "       sudo ethtool -s eth0 wol g    (replace eth0 with your interface)"
    echo "       To check: ethtool eth0 | grep 'Wake-on'"
    echo "    3. Make it persistent: add the ethtool command to /etc/rc.local"
elif [ "$OS" = "Darwin" ]; then
    echo "    1. Enable WoL in System Settings > Energy (or System Preferences > Energy Saver)"
    echo "    2. On Macs with T2/Apple Silicon: enable 'Allow wake from network'"
    echo "       in System Settings > Privacy & Security > Startup Disk"
fi
echo ""

echo "  ============================================"
echo "   Setup complete!"
echo "  ============================================"
echo ""
echo "  Next steps:"
echo "    1. Add this PC in the WOLOW mobile app"
echo "    2. Use the token printed above to connect"
echo ""
