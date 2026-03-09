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
            updatedItem.title = "⚠️ Fetch failed"
            return
        }

        let fivePct = usage.fiveHour?.utilization
        let weekPct = usage.sevenDay?.utilization

        // Menu bar title
        statusItem.button?.title = formatTitle(fivePct: fivePct, weekPct: weekPct)

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

    // MARK: - Formatting

    private func formatTitle(fivePct: Double?, weekPct: Double?) -> String {
        let fiveStr = fivePct.map { String(format: "%.0f%%", $0) } ?? "--"
        let fiveBar = makeBar(pct: fivePct ?? 0)
        let weekStr = weekPct.map { String(format: "%.0f%%", $0) } ?? "--"
        let weekBar = makeBar(pct: weekPct ?? 0)
        let worst = max(fivePct ?? 0, weekPct ?? 0)
        let icon = colorIndicator(pct: worst)
        return "\(icon) 5h:\(fiveStr) \(fiveBar) | 7d:\(weekStr) \(weekBar)"
    }

    private func formatDetail(label: String, pct: Double?, resetsAt: String?) -> String {
        guard let pct else { return "⚪ \(label):   N/A" }
        let icon = colorIndicator(pct: pct)
        let bar = makeBar(pct: pct)
        let resetStr = resetsAt.flatMap { formatResetTime($0) }.map { "  (resets \($0))" } ?? ""
        return "\(icon) \(label):   \(String(format: "%.1f%%", pct))  \(bar)\(resetStr)"
    }

    private func makeBar(pct: Double) -> String {
        let clamped = max(0, min(100, pct))
        let filled = Int((clamped / 100.0 * Double(Constants.barLength)).rounded())
        return String(repeating: Constants.barFilled, count: filled)
             + String(repeating: Constants.barEmpty, count: Constants.barLength - filled)
    }

    private func colorIndicator(pct: Double) -> String {
        if pct >= 80 { return "🔴" }
        if pct >= 50 { return "🟡" }
        return "🟢"
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
