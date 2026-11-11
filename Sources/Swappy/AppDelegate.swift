import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let monitor = Monitor()
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var lastTitle = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "Swappy")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(monitor).environmentObject(settings))

        monitor.onSample = { [weak self] in self?.updateStatus($0) }
        settings.$theme.sink { [weak self] in self?.apply(theme: $0) }.store(in: &cancellables)
        settings.$barMode.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            self.updateStatus(self.monitor.snap)
        }.store(in: &cancellables)
        settings.$language.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            self.lastTitle = "\u{0}"
            self.updateStatus(self.monitor.snap)
        }.store(in: &cancellables)
        monitor.start()
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            snapshot(to: CommandLine.arguments[i + 1])
        }
        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
        }
    }

    private func apply(theme: Theme) {
        switch theme {
        case .system: popover.appearance = nil
        case .light: popover.appearance = NSAppearance(named: .aqua)
        case .dark: popover.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func updateStatus(_ s: SystemSnapshot) {
        let title: String
        switch settings.barMode {
        case .swap: title = " " + Fmt.bytes(s.swapUsed)
        case .swapAndMemory: title = " " + Fmt.bytes(s.swapUsed) + " · " + Fmt.percent(s.memFraction)
        case .icon: title = ""
        }
        // Redraw the menu bar only when the text actually changes.
        guard title != lastTitle else { return }
        lastTitle = title
        statusItem.button?.title = title
        statusItem.button?.toolTip = L("tip.swap", Fmt.bytes(s.swapUsed), Fmt.bytes(s.swapTotal))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let screenHeight = button.window?.screen?.visibleFrame.height ?? 800
            popover.contentSize = NSSize(width: 380, height: min(740, screenHeight - 24))
            monitor.setOpen(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.setOpen(false)
    }

    /// Developer aid: `Swappy --snapshot out.png` renders the window offscreen (light + dark) and quits.
    private func snapshot(to path: String) {
        monitor.setOpen(true)
        let args = CommandLine.arguments
        let page = args.firstIndex(of: "--page").flatMap { $0 + 1 < args.count ? Page(rawValue: args[$0 + 1]) : nil }
        if let i = args.firstIndex(of: "--lang"), i + 1 < args.count { L10n.override = args[i + 1] }
        let size = NSSize(width: 380, height: 740)
        let windows = [NSAppearance.Name.aqua, .darkAqua].map { name -> NSWindow in
            let w = NSWindow(contentRect: NSRect(origin: NSPoint(x: -5000, y: -5000), size: size),
                             styleMask: [.borderless], backing: .buffered, defer: false)
            w.appearance = NSAppearance(named: name)
            w.contentView = NSHostingView(rootView: ContentView(page: page).environmentObject(monitor).environmentObject(settings)
                .background(Color(nsColor: .windowBackgroundColor)))
            w.setContentSize(size)
            w.orderFrontRegardless()
            return w
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            for (w, suffix) in zip(windows, ["light", "dark"]) {
                guard let v = w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-\(suffix).png")))
            }
            NSApp.terminate(nil)
        }
    }
}
