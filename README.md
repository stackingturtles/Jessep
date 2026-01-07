# Jessep

A macOS menu bar app for monitoring your Claude Max plan usage limits.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Real-time Usage Monitoring** - Track your Claude usage across all limits
- **Multiple Limit Types** - Session (5-hour), weekly (all models), and Sonnet-only limits
- **Configurable Alerts** - Get notified when approaching or hitting limits
- **Usage Prediction** - See estimated time until you'll hit your limit
- **Reset Notifications** - Know when your limits reset
- **Dark Theme** - Matches Claude's UI design

## Screenshots

*Coming soon*

## Installation

### Download

Download the latest DMG from [Releases](https://github.com/stackingturtles/jessep/releases).

1. Open the DMG file
2. Drag Jessep to your Applications folder
3. Launch Jessep from Applications
4. Click the chart icon in your menu bar

### Homebrew (coming soon)

```bash
brew install --cask jessep
```

## Requirements

- macOS 13.0 (Ventura) or later
- One of:
  - [Claude Code](https://claude.ai/claude-code) installed and logged in
  - Manual OAuth token entry (see Settings)

## How It Works

Jessep reads your Claude OAuth token from:

1. **Claude Code's keychain** (automatic) - If you have Claude Code installed and logged in
2. **Manual entry** (fallback) - Enter your token in Settings

The app then polls the Claude usage API to display your current limits.

## Configuration

Access settings via the gear icon in the popover or Cmd+,.

### General

| Setting | Description | Default |
|---------|-------------|---------|
| Launch at Login | Start Jessep when you log in | Off |
| Refresh Interval | How often to check usage | 5 minutes |
| Menu Bar Style | Icon, percentage, or dynamic colour | Icon |

### Notifications

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Notifications | Show desktop notifications | On |
| Warning Threshold | Percentage to trigger warning | 65% |
| Alert on Reset | Notify when limits reset | On |

## Manual Token Entry

If you don't have Claude Code installed:

1. Open [claude.ai](https://claude.ai) in your browser
2. Open Developer Tools (Cmd+Option+I)
3. Go to the Network tab
4. Filter by "usage"
5. Find the request to `/api/oauth/usage`
6. Copy the Bearer token from the Authorization header
7. Paste it in Jessep Settings > Authentication

## Building from Source

### Requirements

- Xcode 15.0+
- macOS 13.0+

### Build

```bash
# Clone the repository
git clone https://github.com/stackingturtles/jessep.git
cd jessep

# Open in Xcode
open Jessep.xcodeproj

# Or build from command line
xcodebuild -scheme Jessep -configuration Debug build
```

### Run Tests

```bash
xcodebuild test -scheme Jessep -destination 'platform=macOS'
```

## FAQ

### Why "Jessep"?

It's a play on "usage" - like "check your usage" became "Jessep" (just check).

### Is this official?

No, this is an unofficial tool. The Claude usage API is undocumented and may change.

### Is my token secure?

Yes. Tokens are stored in the macOS Keychain and never leave your device except to call the Claude API.

### Can I use this without Claude Code?

Yes! Use manual token entry in Settings.

### The app shows "offline" - what's wrong?

This means the app is using cached data because it couldn't reach the API. Check your internet connection.

## Privacy

- No data is collected or transmitted except to Claude's API
- All data stays on your device
- Tokens are stored securely in the macOS Keychain

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgements

- [Claude](https://claude.ai) by Anthropic
- [Claude Code](https://claude.ai/claude-code) for the inspiration and keychain integration

---

Made with care for Claude users by [Stacking Turtles](https://stackingturtles.io)
