# Claude Usage & Peak Time Tracking macOS App and Widget Suite

A native macOS application, Menu Bar companion, and WidgetKit desktop widget suite built with SwiftUI and Swift 6 for tracking Claude usage across multiple accounts and monitoring Claude's global peak usage windows.

## Features

- **Peak Window Detection**: Accurately tracks Claude's peak window (Weekdays Monday–Friday, 5:00 AM to 11:00 AM Pacific Time). Weekends are recognized as completely off-peak.
- **Regional Timezone Support**: Converts peak windows dynamically for:
  - Pacific Time (PT): 5:00 AM – 11:00 AM
  - Eastern Time (ET): 8:00 AM – 2:00 PM
  - Greenwich Mean Time (GMT / UTC): 1:00 PM – 7:00 PM
  - Central European Time (CET): 2:00 PM – 8:00 PM
  - User's Local Timezone
- **24-Hour Visual Day Timeline**: Displays an illuminated daylight track highlighting the peak window with a live needle indicator at your current time.
- **Multi-Account Tracking**:
  - **Anthropic API**: Track token usage (input/output/total), spend ($ USD), and rate limit headers.
  - **Claude.ai Web Session**: Monitor active organization & subscription tier (Pro, Team, Enterprise, Free).
  - **5-Hour Rolling Window Tracker**: Privacy-first, local message tracker with quick "+1 Prompt" button and reset countdowns.
- **Keychain Security**: All sensitive API keys and session tokens are encrypted in the macOS Keychain.
- **Widgets for Desktop & Notification Center**:
  - **Small**: Peak status badge, countdown timer, and primary account quota meter.
  - **Medium**: 24-hour visual peak timeline scrubber and side-by-side account cards.
  - **Large**: Full dashboard with multi-account list and regional timezone quick-reference pills.
- **Menu Bar Extra**: Popover in the macOS menu bar for rapid glanceability and 1-click invocation tracking.

## Quick Start

### Opening in Xcode
```bash
open ClaudeUsage.xcodeproj
```

### Running Tests
```bash
xcodebuild test -project ClaudeUsage.xcodeproj -scheme ClaudeUsageTests
```

### Building the App & Widgets
```bash
xcodebuild build -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug
```
