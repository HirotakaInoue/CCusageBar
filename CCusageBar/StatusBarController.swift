import AppKit
import Foundation

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let usageService = UsageService()
    private var timer: Timer?

    // Menu items for dynamic updates
    private let fiveHourItem = NSMenuItem(title: "⚪ 5-Hour:   Loading...",
                                          action: nil, keyEquivalent: "")
    private let weeklyItem = NSMenuItem(title: "⚪ Weekly:   Loading...",
                                        action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "Updated: --",
                                         action: nil, keyEquivalent: "")

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⏳ Claude ..."

        let menu = NSMenu()

        let openPageItem = NSMenuItem(title: "🌐 Open Usage Page",
                                      action: #selector(openUsagePage),
                                      keyEquivalent: "")
        openPageItem.target = self
        menu.addItem(openPageItem)

        menu.addItem(.separator())
        fiveHourItem.isEnabled = false
        weeklyItem.isEnabled = false
        updatedItem.isEnabled = false
        menu.addItem(fiveHourItem)
        menu.addItem(weeklyItem)

        menu.addItem(.separator())
        menu.addItem(updatedItem)

        let refreshItem = NSMenuItem(title: "↻ Refresh Now",
                                     action: #selector(manualRefresh),
                                     keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Initial fetch
        Task { await refresh() }
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval,
                                     repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private func refresh() async {
        let usage = await usageService.fetchUsage()
        updateUI(usage: usage)
    }

    private func updateUI(usage: UsageResponse?) {
        guard let usage else {
            statusItem.button?.title = "⚠️ Claude: Error"
            statusItem.button?.image = nil
            updatedItem.title = "⚠️ Fetch failed"
            return
        }

        let fivePct = usage.fiveHour?.utilization
        let weekPct = usage.sevenDay?.utilization

        // Menu bar: text + image bar
        updateStatusItemTitle(fivePct: fivePct, weekPct: weekPct)

        // Dropdown details
        fiveHourItem.title = formatDetail(label: "5-Hour",
                                          pct: fivePct,
                                          resetsAt: usage.fiveHour?.resetsAt)
        weeklyItem.title = formatDetail(label: "Weekly",
                                        pct: weekPct,
                                        resetsAt: usage.sevenDay?.resetsAt)

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        updatedItem.title = "Updated: \(formatter.string(from: Date()))"
    }

    // MARK: - Menu Bar Rendering

    private func updateStatusItemTitle(fivePct: Double?, weekPct: Double?) {
        let fiveStr = fivePct.map { String(format: "%.0f%%", $0) } ?? "--"
        let weekStr = weekPct.map { String(format: "%.0f%%", $0) } ?? "--"
        let worst = max(fivePct ?? 0, weekPct ?? 0)
        let icon = colorIndicator(pct: worst)

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]

        let result = NSMutableAttributedString()

        // Icon + 5h label
        result.append(NSAttributedString(string: "\(icon) 5h:\(fiveStr) ", attributes: attrs))
        // 5h bar image
        result.append(barImageAttachment(pct: fivePct ?? 0, color: barColor(pct: fivePct ?? 0)))
        // Separator + 7d label
        result.append(NSAttributedString(string: "  7d:\(weekStr) ", attributes: attrs))
        // 7d bar image
        result.append(barImageAttachment(pct: weekPct ?? 0, color: barColor(pct: weekPct ?? 0)))

        statusItem.button?.attributedTitle = result
        statusItem.button?.image = nil
    }

    private func barImageAttachment(pct: Double, color: NSColor) -> NSAttributedString {
        let barWidth: CGFloat = 48
        let barHeight: CGFloat = 10
        let cornerRadius: CGFloat = 2

        let image = NSImage(size: NSSize(width: barWidth, height: barHeight), flipped: false) { rect in
            // Background (empty bar)
            let bgColor: NSColor
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                bgColor = NSColor.white.withAlphaComponent(0.15)
            } else {
                bgColor = NSColor.black.withAlphaComponent(0.12)
            }
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            bgColor.setFill()
            bgPath.fill()

            // Filled portion
            let clamped = max(0, min(100, pct))
            let filledWidth = rect.width * CGFloat(clamped / 100.0)
            if filledWidth > 0 {
                let filledRect = NSRect(x: 0, y: 0, width: filledWidth, height: rect.height)
                let filledPath = NSBezierPath(roundedRect: filledRect, xRadius: cornerRadius, yRadius: cornerRadius)
                color.setFill()
                filledPath.fill()
            }
            return true
        }
        image.isTemplate = false

        let attachment = NSTextAttachment()
        attachment.image = image
        // Vertically center the bar relative to the text baseline
        attachment.bounds = CGRect(x: 0, y: -1, width: barWidth, height: barHeight)
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Colors

    private func barColor(pct: Double) -> NSColor {
        if pct >= 80 { return NSColor.systemRed }
        if pct >= 50 { return NSColor.systemOrange }
        return NSColor.systemGreen
    }

    private func colorIndicator(pct: Double) -> String {
        if pct >= 80 { return "🔴" }
        if pct >= 50 { return "🟡" }
        return "🟢"
    }

    // MARK: - Dropdown Formatting

    private func formatDetail(label: String, pct: Double?, resetsAt: String?) -> String {
        guard let pct else { return "⚪ \(label):   N/A" }
        let icon = colorIndicator(pct: pct)
        let bar = makeTextBar(pct: pct)
        let resetStr = resetsAt.flatMap { formatResetTime($0) }.map { "  (resets \($0))" } ?? ""
        return "\(icon) \(label):   \(String(format: "%.1f%%", pct))  \(bar)\(resetStr)"
    }

    private func makeTextBar(pct: Double) -> String {
        let clamped = max(0, min(100, pct))
        let filled = Int((clamped / 100.0 * Double(Constants.barLength)).rounded())
        return String(repeating: Constants.barFilled, count: filled)
             + String(repeating: Constants.barEmpty, count: Constants.barLength - filled)
    }

    private func formatResetTime(_ isoString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString)
        guard let date else { return nil }
        let display = DateFormatter()
        display.timeZone = .current
        if Calendar.current.isDateInToday(date) {
            display.dateFormat = "HH:mm"
        } else {
            display.dateFormat = "MM/dd HH:mm"
        }
        return display.string(from: date)
    }

    // MARK: - Actions

    @objc private func openUsagePage() {
        NSWorkspace.shared.open(Constants.usagePageURL)
    }

    @objc private func manualRefresh() {
        Task { await refresh() }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
