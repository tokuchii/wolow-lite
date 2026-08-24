Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "cmd /c ""C:\Users\kdrak\wolow-lite\pc_agent\setup.bat""", 0, True
WshShell.Popup "WOLOW Agent setup complete. Agent is running silently.", 5, "WOLOW Lite", 64
