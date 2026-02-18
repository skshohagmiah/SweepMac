# SweepMac

A free, open-source macOS disk cleaning app built with Swift and SwiftUI. Scans your system for space-hogging files, shows a visual breakdown of disk usage, and lets you clean categories with one click.

No subscriptions. No ads. No telemetry.

## Features

- **Disk Usage Overview** — Donut chart showing used vs free space with color-coded health indicators
- **11 Scan Categories** — System Caches, Application Logs, Trash, Xcode, iOS Backups, Docker, node_modules, Homebrew Cache, Mail Attachments, Large Files, and old Downloads
- **File Inspector** — Browse individual files per category, sorted by size, with select/deselect for granular control
- **One-Click Cleaning** — Clean individual categories or all safe categories at once
- **Safe by Default** — Files are moved to Trash (recoverable), system-critical paths are blocklisted, confirmation dialog before every delete
- **Native macOS UI** — Sidebar navigation, SF Symbols, Swift Charts, glassmorphism cards, dark mode support

## Screenshots

*Coming soon*

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)

## Installation

### Download

Grab the latest `.app` from [Releases](../../releases) and drag it to your Applications folder.

> Since the app is not notarized, you may need to right-click → Open → Open on first launch to bypass Gatekeeper.

### Build from Source

```bash
git clone https://github.com/skshohagmiah/SweepMac.git
cd SweepMac
xcodebuild -project SweepMac.xcodeproj -scheme SweepMac -configuration Release build
```

Or open `SweepMac.xcodeproj` in Xcode and press Cmd+R.

## Permissions

SweepMac works best with **Full Disk Access** enabled. Without it, some categories (Mail Attachments, certain Library folders) won't be scannable.

To grant access:

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click **+** and add SweepMac
3. Restart the app

The app will guide you through this on first launch if access is missing.

## What It Scans

| Category | Paths | Safe to Auto-Clean |
|---|---|---|
| System Caches | `~/Library/Caches/`, `/Library/Caches/` | Yes |
| Application Logs | `~/Library/Logs/`, `/Library/Logs/` | Yes |
| Trash | `~/.Trash/` | Yes |
| Xcode | DerivedData, Archives, Device Support, Simulators | Yes |
| iOS Backups | `~/Library/Application Support/MobileSync/Backup/` | Yes |
| Docker | `~/Library/Containers/com.docker.docker/` | Yes |
| node_modules | Scans Projects, Developer, Documents, Desktop | Yes |
| Homebrew Cache | `~/Library/Caches/Homebrew/` | Yes |
| Mail Attachments | `~/Library/Mail/` | Manual review |
| Large Files | Files > 500 MB in home directory | Manual review |
| Downloads | Files older than 30 days in `~/Downloads/` | Manual review |

## Safety

SweepMac is designed to never cause harm:

- **Blocklisted paths** — `/System/`, `/usr/`, `/bin/`, `/sbin/`, `/Applications/` and other critical paths are hardcoded as untouchable
- **Trash by default** — Deleted files go to Trash so you can recover them. Permanent delete is opt-in via Settings
- **Confirmation dialogs** — Every clean action requires explicit user confirmation
- **No root access** — The app only operates within user-accessible directories

## Project Structure

```
SweepMac/
├── SweepMac/
│   ├── SweepMacApp.swift           # App entry point
│   ├── Models/
│   │   ├── DiskInfo.swift          # Disk usage data model
│   │   ├── CleanCategory.swift     # Category definitions and metadata
│   │   └── FileItem.swift          # Individual file model
│   ├── ViewModels/
│   │   ├── DiskScannerVM.swift     # Scan orchestration and state
│   │   ├── CleanerVM.swift         # Cleaning logic and confirmation flow
│   │   └── SettingsVM.swift        # User preferences with persistence
│   ├── Views/
│   │   ├── MainView.swift          # NavigationSplitView layout
│   │   ├── OverviewView.swift      # Disk chart + category cards grid
│   │   ├── DiskChartView.swift     # Swift Charts donut chart
│   │   ├── CategoryDetailView.swift# File inspector with selection
│   │   ├── CleanConfirmSheet.swift # Confirmation dialog
│   │   ├── OnboardingView.swift    # Full Disk Access setup guide
│   │   └── SettingsView.swift      # Preferences panel
│   ├── Services/
│   │   ├── DiskScanner.swift       # Async file system scanning
│   │   ├── Cleaner.swift           # Safe file deletion
│   │   └── PermissionChecker.swift # Full Disk Access detection
│   └── Utils/
│       ├── ByteFormatter.swift     # Human-readable file sizes
│       └── SafePathValidator.swift # System path blocklist
└── SweepMac.xcodeproj/
```

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Charts | Swift Charts |
| File System | Foundation FileManager APIs |
| Architecture | MVVM |
| Concurrency | Swift Concurrency (async/await, actors) |
| Min Target | macOS 14.0 (Sonoma) |

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Build and test: `xcodebuild -scheme SweepMac build`
5. Commit: `git commit -m "Add my feature"`
6. Push: `git push origin feature/my-feature`
7. Open a Pull Request

### Ideas for Contributions

- App icon design
- Time Machine local snapshot cleanup
- Scheduled scans with notifications
- Menu bar widget for quick access
- Homebrew cask formula
- Sparkle auto-update integration
- Localization / multi-language support

## License

MIT License. See [LICENSE](LICENSE) for details.
