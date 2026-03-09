# CCusageBar

A native macOS menu bar application that displays Claude Code usage limits (5-hour / 7-day) in real time.

![Platform](https://img.shields.io/badge/platform-macOS%2013+-blue.svg)
![Swift](https://img.shields.io/badge/swift-5.9+-orange.svg)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen.svg)

## Features

- **Menu Bar Integration** - Always-visible usage percentages with Core Graphics rendered color progress bars.
- **Real-time Monitoring** - Polls the Anthropic usage API every 120 seconds with manual refresh option.
- **Color Indicators** - Green / Yellow / Red indicators based on usage thresholds.
- **Reset Time Display** - Shows when each limit resets in the dropdown detail view.
- **Quick Access** - One-click to open the Claude usage page in the browser.
- **Dark/Light Mode** - Progress bars automatically adapt to the system appearance.
- **Zero Dependencies** - Uses only Foundation, AppKit, and Security frameworks. No third-party packages.

## Menu Bar UX

| State | Menu Bar Display |
|-------|-----------------|
| Low usage | `🟢 5h:10% [green bar] \| 7d:6% [green bar]` |
| Moderate usage | `🟡 5h:55% [orange bar] \| 7d:40% [green bar]` |
| High usage | `🔴 5h:85% [red bar] \| 7d:70% [orange bar]` |
| Error | `⚠️ Claude: Error` |

The dropdown menu displays:

- **Open Usage Page** - Opens Claude usage settings in the browser
- **5-Hour detail** - Current percentage, progress bar, and reset time
- **Weekly detail** - Current percentage, progress bar, and reset time
- **Last updated** - Timestamp of the last successful fetch
- **Refresh Now** - Manually trigger an API refresh

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ (Xcode 15+)
- Claude Code CLI installed and logged in (`/login` completed)

## Build

### Xcode

```bash
open CCusageBar.xcodeproj
```

Xcode で `Cmd+B` (ビルド) or `Cmd+R` (実行)。

### コマンドライン

```bash
xcodebuild -scheme CCusageBar -configuration Release build
```

### project.yml を変更した場合

```bash
xcodegen generate
```

## Install

1. Xcode で **Product → Archive** → **Distribute App** → Export で `.app` を取得
2. `CCusageBar.app` を `/Applications/` にコピー
3. Spotlight や Launchpad から起動可能

または Release ビルド後に直接コピー:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/CCusageBar-*/Build/Products/Release/CCusageBar.app /Applications/
```

## Usage

1. `CCusageBar.app` を起動 - macOS メニューバーに表示されます（Dock には表示されません）。
2. Usage percentages and color progress bars are displayed at all times.
3. Click the menu bar item to see detailed usage with reset times.
4. Click **Open Usage Page** to view the full usage dashboard.
5. Click **Refresh Now** to manually update, or wait for the 120-second auto-refresh.

## Auto-Start

**方法 1: macOS ログイン項目（推奨）**

システム設定 → 一般 → ログイン項目 → 「+」 → `/Applications/CCusageBar.app` を追加

**方法 2: LaunchAgent**

```bash
cp com.claude.usage-monitor.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claude.usage-monitor.plist
```

To stop:

```bash
launchctl unload ~/Library/LaunchAgents/com.claude.usage-monitor.plist
```

## Configuration

| Constant | Default | Description |
|----------|---------|-------------|
| `refreshInterval` | `120` sec | API polling interval |
| `barLength` | `8` | Progress bar width (characters in dropdown) |

OAuth token is read from macOS Keychain (`Claude Code-credentials` service) at runtime. No credentials are stored in the application.

## Color Thresholds

| Range | Indicator | Meaning |
|-------|-----------|---------|
| 0-49% | 🟢 Green | Comfortable |
| 50-79% | 🟡 Yellow | Caution |
| 80-100% | 🔴 Red | Critical |

## Troubleshooting

- **Error / No Token** - Run `claude /login` to authenticate Claude Code CLI.
- **Keychain access prompt** - Click "Allow" when macOS asks for Keychain access on first launch.
- **Stale data** - Click "Refresh Now" or restart the app.

## License

MIT
