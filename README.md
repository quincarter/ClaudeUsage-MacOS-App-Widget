# Claude Usage & Peak Time Tracking for macOS

A native macOS menu bar app and WidgetKit desktop suite built with **SwiftUI** and **Swift 6** for tracking Claude usage across multiple accounts and monitoring Claude's global peak hours in real time.

>[!NOTE]
>### 💡 Why Claude Usage?
> **Are you a Claude user? Do you have one or multiple accounts?**
>
> If you rely heavily on Claude for coding, research, or daily workflows, you've almost certainly hit that dreaded mid-flow roadblock: suddenly Anthropic gouges your session limits or throttles response speeds during **weekday peak traffic hours** right when you need it most.
>
> I built **Claude Usage** to take the guesswork out of rate limits. Whether you manage a personal Claude Pro account, an enterprise workspace, heavy Claude Code agent sessions, or direct Anthropic API keys, this app gives you complete, real-time visibility over:
> - **Peak Hour Horizon**: Real-time tracking of Claude's global peak traffic windows (**Weekdays 5:00 AM – 11:00 AM PT / 8:00 AM – 2:00 PM ET**) so you know if you're invoking during high-traffic throttled windows.
> - **Live Session & Weekly Limits**: Instant visibility into your 5-hour rolling session limit, 7-day volume cap, and exact clock-based reset times (e.g., `"Resets at 5:30 PM today"` and `"Weekly: 95% (Fri 6:00 AM)"`).
> - **Multiple Interfaces**: Seamless access via a full **macOS Desktop Dashboard**, a lightweight **Menu Bar Popover**, and native **Desktop Widgets across all sizes (Small, Medium, Large)** directly on your desktop wallpaper or Notification Center.

<p align="center">
  <img src="assets/screenshots/app-dashboard.png" alt="Claude Usage Main Dashboard" width="820" />
</p>

---

## 📸 Desktop Widgets & Menu Bar

Monitor your active accounts and peak status at a glance from your macOS Desktop or Notification Center.

<p align="center">
  <img src="assets/screenshots/widget-large.png" alt="Large Desktop Widget (Off-Peak)" width="340" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/screenshots/menubar-popup.png" alt="Menu Bar Popover" width="310" />
</p>

<p align="center">
  <img src="assets/screenshots/widget-medium.png" alt="Medium Desktop Widget" width="460" />
  <br><br>
  <img src="assets/screenshots/widget-small.png" alt="Small Desktop Widget" width="220" />
</p>

| Size | Focus | Key Information |
| :--- | :--- | :--- |
| **Large Widget** | Comprehensive multi-account overview | Live 5h limits with clock-based reset times (`Resets at 5:30 PM today`), 7-day weekly cap, spend & token meters, 24h illuminated daylight timeline, and regional reference pills. |
| **Medium Widget** | Daylight horizon & side-by-side accounts | Visual peak horizon bar, current time indicator needle, and primary & secondary account usage cards. |
| **Small Widget** | Compact glanceability | Peak status badge, countdown timer, and primary account quota meter. |
| **Menu Bar Extra** | Quick access popover | Live menu bar icon, 1-click usage synchronization, and fast dashboard access (`⌘O`). |

---

## ⚡️ Peak Hours Active State

During Claude's weekday peak traffic windows (**Monday–Friday, 5:00 AM – 11:00 AM PT**), the desktop widgets and application automatically switch into **Peak Active** mode. Status indicators turn red, the daylight needle tracks inside the illuminated peak band, and active countdowns display exactly when standard response speeds and limits resume.

<p align="center">
  <img src="assets/screenshots/app-dashboard-peak.png" alt="Claude Usage Main Dashboard in Peak Active State" width="820" />
</p>

<p align="center">
  <img src="assets/screenshots/widget-large-peak.png" alt="Large Desktop Widget in Peak Active State" width="340" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/screenshots/widget-small-peak.png" alt="Small Desktop Widget in Peak Active State" width="220" />
</p>

<p align="center">
  <img src="assets/screenshots/widget-medium-peak.png" alt="Medium Desktop Widget in Peak Active State" width="460" />
</p>

---

## ✨ Features

- **Peak Window Detection**: Accurately tracks Claude's peak window (**Weekdays Monday–Friday, 5:00 AM to 11:00 AM Pacific Time**). Weekends are automatically recognized as off-peak all day.
- **Regional Timezone Horizon**: Dynamically converts peak windows for your local device timezone and key regions:
  - **Pacific Time (PT)**: 5:00 AM – 11:00 AM
  - **Eastern Time (ET)**: 8:00 AM – 2:00 PM
  - **Greenwich Mean Time (GMT / UTC)**: 1:00 PM – 7:00 PM
  - **Central European Time (CET)**: 2:00 PM – 8:00 PM
- **Multi-Account Monitoring**:
  - **Claude.ai Web Sessions**: Live synchronization of 5-hour rolling session limit (`five_hour`) and 7-day weekly volume cap (`seven_day`), including surface breakdown (Claude Code, Artifacts, Web Chat).
  - **Clock-Based Reset Times**: Shows exact reset times like `"Resets at 5:30 PM today"` and `"Weekly: 95% (Fri 6:00 AM)"`.
  - **Anthropic API**: Track token usage (input/output/total), spend ($ USD), and rate limit headers.
  - **Local Rolling Window Tracker**: Privacy-first, local message tracker with quick "+1 Prompt" button and reset countdowns.
- **Keychain Security**: All sensitive API keys and session tokens are encrypted in the native macOS Keychain.
- **Instant Cross-Process Sync**: WidgetKit timelines automatically redraw whenever accounts refresh or usage updates in the app.

---

## 🛠 Tech Stack & Architecture

- **Platform**: macOS 14.0+ (Sonoma, Sequoia)
- **UI Framework**: SwiftUI & WidgetKit
- **Language**: Swift 6 (Strict Concurrency Checking)
- **Project Generator**: [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`)
- **Shared Framework**: `ClaudeUsageShared.framework` linking models, services, and shared UI components across the host app, widgets, and tests.

---

## 🚀 Quick Start

### 1. Prerequisites
Ensure you have Xcode 15+ installed. If you wish to regenerate the project file from `project.yml`:
```bash
brew install xcodegen
```

### 2. Generate and Open Project
```bash
xcodegen generate
open ClaudeUsage.xcodeproj
```

### 3. Run Unit Tests & Screenshot Generation
```bash
xcodebuild test -project ClaudeUsage.xcodeproj -scheme ClaudeUsageTests
```

### 4. Build & Install
```bash
xcodebuild build -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug
```
Copy `ClaudeUsage.app` to `/Applications/` to enable WidgetKit discovery in macOS desktop widget gallery.

---

## 📄 License
MIT License. Feel free to use, modify, and distribute.
