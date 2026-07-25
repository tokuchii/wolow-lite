# WOLOW Lite

**Remote PC Control via Wake-on-LAN**

Wake up, shut down, reboot, sleep, or lock your PC from your phone — anywhere on your local network.

---

## Quick Start

### Step 1: Set up your PC

| OS | How to install |
|----|----------------|
| **Windows** | Right-click `setup.bat` → **Run as administrator** |
| **Linux / macOS** | Run `sudo bash setup.sh` in terminal |

The setup script will:
- Install the WOLOW agent (Python server on your PC)
- Generate an authentication token
- Open required firewall ports
- Register auto-start on boot

When complete, it will display your **agent token** — copy it.

### Step 2: Install the mobile app

| Platform | File |
|----------|------|
| **Android** | `android/WOLOW-Lite.apk` — transfer to your phone and install |
| **iPhone / iPad** | Build from source on a Mac with Xcode (see below) |
| **Windows PC** | `windows/wolow_lite.exe` — run directly |
| **Web browser** | Open `web/index.html` (agent-only, no WoL) |

### Step 3: Connect

1. Open the WOLOW app on your phone
2. Tap **+** → **Scan Network**
3. Select your PC from the list
4. Done — tap the power button to wake your PC

---

## What's Included

```
WOLOW-Lite/
├── android/
│   └── WOLOW-Lite.apk          # Android app (install on phone)
├── windows/
│   ├── wolow_lite.exe           # Windows desktop app
│   └── ...                      # Support files
├── web/
│   └── index.html               # Web version (open in browser)
├── pc-agent/
│   ├── agent.py                 # PC agent (runs on your computer)
│   ├── actions.py               # Platform-specific actions
│   ├── config.py                # Configuration loader
│   ├── config.example.yaml      # Example config
│   ├── generate_token.py        # Token generator
│   ├── requirements.txt         # Python dependencies
│   └── setup.bat                # Windows agent-only setup
├── setup.bat                    # Full Windows setup (WinRM + agent)
├── setup.sh                     # Full Linux/macOS setup
└── README.md                    # This file
```

---

## Platform Details

### Android
- **File:** `android/WOLOW-Lite.apk`
- **How to install:**
  1. Transfer the APK to your phone (USB, email, cloud drive, etc.)
  2. Open the file on your phone
  3. If prompted, enable "Install from unknown sources"
  4. Tap Install
- **Requirements:** Android 5.0+

### Windows
- **File:** `windows/wolow_lite.exe`
- **How to run:** Double-click `wolow_lite.exe`
- **Note:** The Windows app can also act as a controller for other PCs on your network

### Web
- **File:** `web/index.html`
- **How to use:** Open in any modern browser
- **Limitations:** WoL magic packets don't work in browsers — agent HTTP actions (reboot, shutdown, etc.) work fine

### iOS / iPadOS (build from source)
Building for iOS requires a Mac with Xcode:
```bash
# On a Mac with Flutter + Xcode installed:
cd wolow-lite
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode and archive
```

### Linux / macOS (build from source)
```bash
cd wolow-lite
flutter build linux --release   # or flutter build macos --release
```

---

## PC Agent

The agent is a lightweight Python server that runs on your PC and executes remote commands.

### Requirements
- Python 3.8+
- pip (usually included with Python)

### Manual setup (if not using setup.bat/setup.sh)
```bash
cd pc-agent
pip install -r requirements.txt
python generate_token.py        # creates config.yaml with a token
python agent.py                 # starts the agent
```

### Configuration
Edit `pc-agent/config.yaml`:
```yaml
server:
  host: "0.0.0.0"
  port: 8220
  token: "your-token-here"

logging:
  level: "INFO"
```

### Supported actions
| Action | Description |
|--------|-------------|
| `reboot` | Restart the PC |
| `shutdown` | Shut down the PC |
| `sleep` | Put the PC to sleep |
| `hibernate` | Hibernate the PC (Windows/Linux only) |
| `lock` | Lock the screen |

---

## Network Requirements

- Phone/controller and PC must be on the **same local network** (WiFi or Ethernet)
- WoL requires the PC's network card to support Wake-on-LAN (most desktops do)
- Ports used:
  - **9** (UDP) — Wake-on-LAN magic packets
  - **8220** (TCP) — Agent HTTP API
  - **8221** (UDP) — Agent discovery

---

## Troubleshooting

### "Cannot connect — is the agent running?"
1. Make sure `agent.py` is running on the PC
2. Check that port 8220 is not blocked by firewall/antivirus
3. Verify phone and PC are on the same WiFi network

### "Authentication failed"
- The token must match between the app and `pc-agent/config.yaml`
- Run `python generate_token.py` to generate a new token

### Wake-on-LAN not working
1. Enable WoL in your PC's BIOS/UEFI settings
2. Enable WoL in your network adapter settings (Device Manager → Network adapter → Properties → Power Management)
3. Make sure fast startup is disabled in Windows Power Options

### Android: "App not installed"
- Uninstall any previous version first
- Make sure "Install from unknown sources" is enabled

---

## License

WOLOW Lite — Free for personal use.
