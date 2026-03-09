# CCusageBar

macOS メニューバーに Claude Code の使用量（5時間 / 週間リミット）を常時表示する Swift アプリ。

外部依存ゼロ。Foundation + AppKit + Security のみ使用。

## 表示イメージ

```
メニューバー: 🟢 5h:32% ▓▓▓░░░░░ | 7d:58% ▓▓▓▓▓░░░
```

ドロップダウンでは詳細情報とリセット時刻を確認できます。

## 前提条件

- macOS 13+
- Swift 5.9+ (Xcode 15+ に同梱)
- Claude Code CLI がインストール済みで `/login` 完了済み

## ビルド & 起動

```bash
swift build -c release
.build/release/CCusageBar
```

開発時:

```bash
swift run
```

## インストール

```bash
swift build -c release
cp .build/release/CCusageBar /usr/local/bin/
```

## 自動起動（LaunchAgent）

```bash
cp com.claude.usage-monitor.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claude.usage-monitor.plist
```

停止:

```bash
launchctl unload ~/Library/LaunchAgents/com.claude.usage-monitor.plist
```

## インジケーター

| 範囲 | 絵文字 | 意味 |
|------|--------|------|
| 0-49% | 🟢 | 余裕あり |
| 50-79% | 🟡 | 注意 |
| 80-100% | 🔴 | 危険 |

## トラブルシューティング

- **No Token / Error**: `claude /login` でログインしてください
- **Keychain アクセスプロンプト**: 初回起動時に Keychain アクセス許可ダイアログが出る場合があります。「許可」をクリックしてください
