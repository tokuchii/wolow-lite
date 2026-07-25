#!/usr/bin/env bash
# WOLOW Agent - Setup Script (Linux/macOS)
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
echo "   WOLOW Agent - One-Click Setup"
echo "  ============================================"
echo ""

# Check Python 3
echo "  [1/5] Checking Python..."
if ! command -v python3 &>/dev/null; then
    echo "  [!] Python 3 is not installed or not in PATH."
    echo ""
    echo "  Install it:"
    echo "    macOS:  brew install python3"
    echo "    Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "    Fedora/RHEL: sudo dnf install python3 python3-pip"
    echo ""
    exit 1
fi
python3 --version
echo ""

# Install dependencies
echo "  [2/5] Installing dependencies..."
pip3 install -r requirements.txt --quiet 2>/dev/null
echo "      Done."
echo ""

# Generate token
echo "  [3/5] Generating authentication token..."
python3 generate_token.py
echo ""

# Auto-start on boot
echo "  [4/5] Setting up auto-start on boot..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_PATH="$(which python3)"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: launchd LaunchAgent
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
        <string>${SCRIPT_DIR}/agent.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
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
    # Linux: systemd service
    if command -v systemctl &>/dev/null; then
        sudo tee /etc/systemd/system/wolow-agent.service > /dev/null <<SERVICE
[Unit]
Description=WOLOW Lite PC Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${PYTHON_PATH} ${SCRIPT_DIR}/agent.py
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
    fi
fi
echo ""

# Done
echo "  [5/5] Setup complete!"
echo ""
echo "  ============================================"
echo ""
echo "  Starting WOLOW agent now..."
echo "  It will auto-start on next boot."
echo ""
echo "  ============================================"
echo ""

python3 agent.py
