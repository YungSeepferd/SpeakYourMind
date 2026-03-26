# SpeakYourMind - Testing Setup

## Quick Start

### Install
```bash
./install.sh
```
This builds the release version and installs to `~/Applications/SpeakYourMind.app`

### Run
```bash
open ~/Applications/SpeakYourMind.app
```

### View Live Logs
Open a new terminal and run:
```bash
./view-logs.sh
```
Press `Ctrl+C` to stop streaming.

### Export Logs for Reporting
After testing, export logs to share:
```bash
./export-logs.sh
```
This saves a timestamped file: `speakyourmind-logs-YYYYMMDD-HHMMSS.txt`

### Uninstall/Clean
```bash
./clean.sh
```
Removes build artifacts and installed app.

---

## Logging

All application events are logged via OSLog with subsystem `com.speakyourmind.app`.

### Log Levels
- **DEBUG** - Detailed diagnostic information
- **INFO** - Normal operational events
- **WARN** - Potential issues
- **ERROR** - Error conditions
- **FAULT** - Critical failures

### View All App Logs (System)
```bash
log show --predicate 'subsystem == "com.speakyourmind.app"' --last 24h --style compact
```

### Filter by Level
```bash
# Errors only
log show --predicate 'subsystem == "com.speakyourmind.app"' --last 2h --style compact | grep ERROR

# Warnings and errors
log show --predicate 'subsystem == "com.speakyourmind.app"' --last 2h --style compact | grep -E "(ERROR|WARN)"
```

---

## Testing Checklist

When testing, focus on:

1. **Recording** - Press hotkey, speak, verify transcription
2. **Injection** - Text appears in target app
3. **Overlay** - Panel shows correctly
4. **Settings** - Changes persist
5. **Menu Bar** - Icon updates on state change
6. **Hotkeys** - Both overlay and instant record work
7. **Edge Trigger** - If enabled, corner detection works

Check logs for:
- `[ERROR]` entries
- `[WARN]` patterns
- Unexpected behavior traces

---

## Report Issues

When reporting issues, include:
1. Steps to reproduce
2. Expected vs actual behavior
3. Exported log file from `./export-logs.sh`
4. macOS version
5. App version (1.0)

---

## Architecture Notes

- **Logger.swift** - Centralized logging utility (Utils/)
- All services use `Logger.shared` instead of `print()`
- Logs are system-wide (visible via `log` command)
- No log file rotation (manual export needed)
