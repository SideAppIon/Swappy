import AppKit
import Combine
import WidgetKit

struct HistoryPoint {
    let time: TimeInterval
    let swapUsed: Double
}

/// Drives sampling. Idle (window closed): a few sysctls every 10 s.
/// Window open: full refresh incl. per-process scan every 2 s.
final class Monitor: ObservableObject {
    @Published private(set) var snap = SystemSnapshot()
    @Published private(set) var apps: [AppUsage] = []
    @Published private(set) var detail = DetailSnapshot()
    @Published private(set) var history: [HistoryPoint] = []

    var onSample: ((SystemSnapshot) -> Void)?

    private let queue = DispatchQueue(label: "swappy.sampler", qos: .utility)
    private let sampler = SystemSampler()
    private let scanner = ProcessScanner()
    private let detailSampler = DetailSampler()
    private var widgetState: (time: TimeInterval, swap: UInt64) = (0, 0)
    private var timer: DispatchSourceTimer?
    @Published private(set) var isOpen = false
    private var busy = false

    static let historyWindow: TimeInterval = 600

    func start() {
        schedule()
    }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }
        isOpen = open
        if !open { apps = [] }
        schedule()
    }

    private func schedule() {
        timer?.cancel()
        let interval: Double = isOpen ? 2 : 10
        let t = DispatchSource.makeTimerSource(queue: .main)
        // Generous leeway lets macOS coalesce our wakeups with other timers.
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(Int(interval * 250)))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        guard !busy else { return }
        busy = true
        let open = isOpen
        let running = open ? NSWorkspace.shared.runningApplications : []
        queue.async { [sampler, scanner, detailSampler] in
            let s = sampler.sample(detailed: open)
            var detail: DetailSnapshot?
            if open { detail = detailSampler.sample() } else { detailSampler.reset() }
            let apps = open ? scanner.scan(running: running, swapUsed: s.swapUsed) : nil
            DispatchQueue.main.async {
                self.busy = false
                self.history.append(HistoryPoint(time: s.time, swapUsed: Double(s.swapUsed)))
                if let first = self.history.firstIndex(where: { s.time - $0.time <= Self.historyWindow }), first > 0 {
                    self.history.removeFirst(first)
                }
                self.snap = s
                if let apps, self.isOpen { self.apps = apps }
                if let detail { self.detail = detail }
                self.refreshWidgets(s)
                self.onSample?(s)
            }
        }
    }

    /// Widgets sample on their own schedule; nudge them when swap moved noticeably (at most once a minute).
    private func refreshWidgets(_ s: SystemSnapshot) {
        let delta = s.swapUsed > widgetState.swap ? s.swapUsed - widgetState.swap : widgetState.swap - s.swapUsed
        guard s.time - widgetState.time > 60, delta > 64 << 20 || s.time - widgetState.time > 900 else { return }
        widgetState = (s.time, s.swapUsed)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
