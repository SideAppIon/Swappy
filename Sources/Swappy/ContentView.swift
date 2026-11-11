import SwiftUI

enum Palette {
    static let accentA = Color(red: 0.16, green: 0.74, blue: 0.82)
    static let accentB = Color(red: 0.42, green: 0.42, blue: 0.98)
    static let gradient = LinearGradient(colors: [accentA, accentB], startPoint: .leading, endPoint: .trailing)
    static let good = Color(red: 0.20, green: 0.74, blue: 0.45)
    static let warn = Color(red: 0.96, green: 0.62, blue: 0.14)
    static let bad = Color(red: 0.93, green: 0.30, blue: 0.30)
    static let pink = Color(red: 0.90, green: 0.38, blue: 0.68)
    static let track = Color.primary.opacity(0.09)

    static func level(_ f: Double) -> Color { f > 0.9 ? bad : (f > 0.75 ? warn : accentA) }
    static func pressure(_ level: Int32) -> Color { level >= 4 ? bad : (level >= 2 ? warn : good) }
}

enum Page: String { case swap, cpu, gpu, ram, ssd }

struct Card<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.055)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

/// A card that opens a detail page.
struct TapCard<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: Content
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Card { content }
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.accentB.opacity(hovered ? 0.55 : 0), lineWidth: 1.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .scaleEffect(hovered ? 1.018 : 1)
        .shadow(color: Palette.accentB.opacity(hovered ? 0.22 : 0), radius: 10, y: 3)
        .animation(Motion.quick, value: hovered)
        .onHover { hovered = $0 }
        .help(L("tile.help"))
    }
}

struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).kerning(0.6)
    }
}

struct ContentView: View {
    @EnvironmentObject var monitor: Monitor
    @EnvironmentObject var settings: Settings
    @State private var page: Page?
    @State private var revealed = false

    init(page: Page? = nil) { _page = State(initialValue: page) }

    var body: some View {
        ZStack(alignment: .top) {
            if let page {
                DetailView(page: page, snap: monitor.snap, detail: monitor.detail) { go(nil) }
                    .padding(14)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 10) {
                    header.reveal(0)
                    SwapCard(snap: monitor.snap, history: monitor.history) { go(.swap) }.reveal(1)
                    TileRow(snap: monitor.snap, detail: monitor.detail) { go($0) }
                    MemoryStrip(snap: monitor.snap) { go(.ram) }.reveal(6)
                    AppList(apps: monitor.apps, swapUsed: monitor.snap.swapUsed).reveal(7)
                    footer.reveal(8)
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .environment(\.revealed, revealed)
        .onAppear { revealed = monitor.isOpen }
        .onChange(of: monitor.isOpen) { revealed = $0 }
        .id(settings.language)
    }

    private func go(_ target: Page?) {
        withAnimation(Motion.page) { page = target }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Palette.gradient)
                .rotationEffect(.degrees(revealed ? 0 : -180))
                .animation(Motion.reveal(1), value: revealed)
            Text("Swappy").font(.system(size: 16, weight: .semibold, design: .rounded))
            Spacer()
            PressureBadge(level: monitor.snap.pressure)
            Menu {
                Picker(L("set.theme"), selection: $settings.theme) {
                    ForEach(Theme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker(L("set.bar"), selection: $settings.barMode) {
                    ForEach(BarMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker(L("set.lang"), selection: $settings.language) {
                    Text(L("lang.system")).tag("")
                    Divider()
                    ForEach(Array(L10n.codes.enumerated()), id: \.offset) { i, code in
                        Text(L10n.names[i]).tag(code)
                    }
                }
                Toggle(L("set.login"), isOn: $settings.launchAtLogin)
                Divider()
                Button(L("set.quit")) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("set.title"))
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "network").foregroundStyle(.tertiary)
            Text(L("net")).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "arrow.down").foregroundStyle(Palette.accentA)
            Text(Fmt.rate(monitor.snap.netIn)).monospacedDigit()
            Image(systemName: "arrow.up").foregroundStyle(Palette.accentB).padding(.leading, 6)
            Text(Fmt.rate(monitor.snap.netOut)).monospacedDigit()
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 6)
    }
}

struct PressureBadge: View {
    let level: Int32
    var body: some View {
        let color = Palette.pressure(level)
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(L(level >= 4 ? "mem.crit" : (level >= 2 ? "mem.warn" : "mem.ok")))
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
        .animation(Motion.value, value: level)
        .help(L("mem.help"))
    }
}

// MARK: - Swap

struct SwapStatus {
    let text: String, color: Color, writing: Bool
    init(_ snap: SystemSnapshot) {
        if snap.swapWriteRate > 20 * 1024 * 1024 { (text, color, writing) = (L("st.heavy"), Palette.bad, true) }
        else if snap.swapWriteRate > 512 * 1024 { (text, color, writing) = (L("st.writing"), Palette.warn, true) }
        else if snap.swapUsed == 0 { (text, color, writing) = (L("st.unused"), Palette.good, false) }
        else { (text, color, writing) = (L("st.idle"), Palette.good, false) }
    }
}

struct SwapCard: View {
    let snap: SystemSnapshot
    let history: [HistoryPoint]
    let open: () -> Void

    var body: some View {
        let status = SwapStatus(snap)
        TapCard(action: open) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Caption(L("swap.title"))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: status.writing ? "arrow.down.to.line.compact" : "leaf.fill")
                            .font(.system(size: 9, weight: .bold))
                            .pulse(status.writing)
                        Text(status.text).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(status.color)
                    .animation(Motion.value, value: status.text)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Fmt.bytes(snap.swapUsed))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .rolling(Fmt.bytes(snap.swapUsed))
                        .fixedSize()
                    Text(L("swap.of", Fmt.bytes(snap.swapTotal)))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                Bar(fraction: snap.swapFraction, fill: AnyShapeStyle(Palette.gradient)).frame(height: 6)
                Sparkline(points: history, ceiling: Double(max(snap.swapTotal, 1)))
                    .frame(height: 30)
                    .help(L("hist.help"))
                HStack(alignment: .top, spacing: 0) {
                    Stat(title: L("swap.written", Fmt.duration(snap.uptime)), value: Fmt.bytes(snap.swapWritten))
                    Stat(title: L("swap.avg"), value: "≈ " + Fmt.perDay(snap.swapWrittenPerDay))
                    Stat(title: L("swap.now"), value: Fmt.rate(snap.swapWriteRate))
                }
                .help(L("swap.written.help", Fmt.duration(snap.uptime)))
                HStack(spacing: 3) {
                    Image(systemName: "questionmark.circle.fill")
                    Text(L("swap.why"))
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.accentB)
            }
        }
    }
}

struct Stat: View {
    let title: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                .rolling(value)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 4)
    }
}

struct Bar: View {
    let fraction: Double
    let fill: AnyShapeStyle
    @Environment(\.revealed) private var revealed

    var body: some View {
        // Grows from zero when the window opens, then glides between values.
        let f = revealed ? min(max(fraction, 0), 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule().fill(fill)
                    .frame(width: max(geo.size.height, geo.size.width * f))
                    .opacity(f > 0 ? 1 : 0)
            }
            .animation(Motion.value, value: f)
        }
    }
}

/// Segmented bar; values are relative weights.
struct StackedBar: View {
    let segments: [(Double, Color)]
    @Environment(\.revealed) private var revealed

    var body: some View {
        GeometryReader { geo in
            let total = max(segments.reduce(0) { $0 + $1.0 }, 1e-9)
            HStack(spacing: 1.5) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, s in
                    if s.0 / total > 0.004 {
                        Rectangle().fill(s.1).frame(width: max(1, (geo.size.width - 6) * s.0 / total))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.value, value: segments.map(\.0))
            .clipShape(Capsule())
            .scaleEffect(x: revealed ? 1 : 0, anchor: .leading)
            .animation(Motion.value, value: revealed)
        }
    }
}

struct Sparkline: View {
    let points: [HistoryPoint]
    let ceiling: Double
    @Environment(\.revealed) private var revealed

    var body: some View {
        GeometryReader { geo in
            if points.count > 1, let last = points.last {
                let start = last.time - Monitor.historyWindow
                let top = max(ceiling, points.map(\.swapUsed).max() ?? 1)
                let pts = points.map { p in
                    CGPoint(x: geo.size.width * (p.time - start) / Monitor.historyWindow,
                            y: (geo.size.height - 2) * (1 - p.swapUsed / top) + 1)
                }
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        pts.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Palette.accentB.opacity(0.28), Palette.accentB.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(revealed ? 1 : 0)
                    .animation(Motion.reduced ? nil : .easeOut(duration: 0.6).delay(0.55), value: revealed)
                    Path { path in
                        path.move(to: pts[0])
                        pts.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .trim(from: 0, to: revealed ? 1 : 0)
                    .stroke(Palette.gradient, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .animation(Motion.reduced ? nil : .easeOut(duration: 0.8).delay(0.2), value: revealed)
                }
            } else {
                Text(L("hist.wait")).font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Resource tiles

struct TileRow: View {
    let snap: SystemSnapshot
    let detail: DetailSnapshot
    let open: (Page) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Tile(icon: "cpu", title: L("cpu"), value: Fmt.percent(snap.cpu), fraction: snap.cpu) { open(.cpu) }.reveal(2)
            Tile(icon: "display", title: L("gpu"), value: detail.gpuUtilization.map(Fmt.percent) ?? "—",
                 fraction: detail.gpuUtilization ?? 0) { open(.gpu) }.reveal(3)
            Tile(icon: "memorychip", title: L("ram"), value: Fmt.percent(snap.memFraction),
                 fraction: snap.memFraction, color: Palette.pressure(snap.pressure)) { open(.ram) }.reveal(4)
            Tile(icon: "internaldrive", title: L("ssd"), value: Fmt.percent(snap.diskFraction),
                 fraction: snap.diskFraction) { open(.ssd) }.reveal(5)
        }
    }
}

struct Ring: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 5
    @Environment(\.revealed) private var revealed

    var body: some View {
        let f = revealed ? min(max(fraction, 0.001), 1) : 0.001
        ZStack {
            Circle().stroke(Palette.track, lineWidth: lineWidth)
            Circle().trim(from: 0, to: f)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.reduced ? nil : .spring(response: 0.8, dampingFraction: 0.75), value: f)
                .animation(Motion.value, value: color)
        }
    }
}

struct Tile: View {
    let icon: String, title: String, value: String
    let fraction: Double
    var color: Color?
    let action: () -> Void

    var body: some View {
        TapCard(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Ring(fraction: fraction, color: color ?? Palette.level(fraction))
                    Image(systemName: icon).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(width: 42, height: 42)
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                    .rolling(value)
                HStack(spacing: 2) {
                    Text(title).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Memory strip

struct MemorySegment: Identifiable {
    let id: String
    let bytes: UInt64
    let color: Color
    var name: String { L("ram.\(id)") }
    var note: String { L("ram.\(id).d") }

    static func all(_ s: SystemSnapshot) -> [MemorySegment] {
        [MemorySegment(id: "app", bytes: s.memApp, color: Palette.accentB),
         MemorySegment(id: "wired", bytes: s.memWired, color: Palette.warn),
         MemorySegment(id: "comp", bytes: s.memCompressed, color: Palette.pink),
         MemorySegment(id: "cache", bytes: s.memCached, color: Palette.accentA),
         MemorySegment(id: "free", bytes: s.memFree, color: Color.primary.opacity(0.22))]
    }
}

struct MemoryStrip: View {
    let snap: SystemSnapshot
    let open: () -> Void

    var body: some View {
        let segments = MemorySegment.all(snap)
        TapCard(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Caption(L("ram").uppercased())
                    Spacer()
                    Text(L("x.of.y", Fmt.bytes(snap.memUsed), Fmt.bytes(snap.memTotal)))
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                }
                StackedBar(segments: segments.map { (Double($0.bytes), $0.color) }).frame(height: 7)
                HStack(alignment: .top, spacing: 4) {
                    ForEach(segments) { seg in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                Circle().fill(seg.color).frame(width: 5, height: 5)
                                Text(seg.name).font(.system(size: 9)).foregroundStyle(.secondary)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(height: 12)
                            Text(Fmt.bytes(seg.bytes)).font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit().rolling(Fmt.bytes(seg.bytes)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Apps

struct AppList: View {
    let apps: [AppUsage]
    let swapUsed: UInt64

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Caption(L(swapUsed > 0 ? "apps.title" : "apps.title.c"))
                    Spacer()
                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.tertiary)
                        .help(L("apps.info"))
                }
                if apps.isEmpty {
                    Text(L("apps.wait")).font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            let top = Double(apps.first?.compressed ?? 1)
                            ForEach(apps) { app in
                                AppRow(app: app, fraction: Double(app.compressed) / top, showSwap: swapUsed > 0)
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }
                        // Rows glide to their new place when the ranking changes.
                        .animation(Motion.value, value: apps.map(\.id))
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct AppRow: View {
    let app: AppUsage
    let fraction: Double
    let showSwap: Bool
    @State private var hovered = false
    @State private var confirming = false

    private var canQuit: Bool {
        guard let a = app.app else { return false }
        return a.activationPolicy == .regular && a.bundleIdentifier != "com.apple.finder"
    }

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if let icon = app.app?.icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "gearshape.2.fill").font(.system(size: 13)).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 24, height: 24)

            if confirming {
                confirmation
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                info
                    .transition(.opacity)
                if canQuit && hovered {
                    Button { withAnimation(Motion.quick) { confirming = true } } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .help(L("quit.help", app.name))
                }
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(confirming ? Palette.bad.opacity(0.12) : Color.primary.opacity(hovered ? 0.06 : 0)))
        .animation(Motion.quick, value: hovered)
        .onHover { hovered = $0 }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                if app.processes > 1 {
                    Text("×\(app.processes)").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 4)
                Text((showSwap ? "≈ " : "") + Fmt.bytes(showSwap ? app.swapEstimate : app.compressed))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    .rolling(Fmt.bytes(showSwap ? app.swapEstimate : app.compressed))
            }
            Bar(fraction: fraction, fill: AnyShapeStyle(Palette.gradient)).frame(height: 3)
            Text(L("apps.row", Fmt.bytes(app.compressed), Fmt.bytes(app.footprint)))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    /// Quitting another app always needs an explicit second click.
    private var confirmation: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("quit.ask", app.name)).font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Text(L("quit.warn")).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(L("cancel")) { withAnimation(Motion.quick) { confirming = false } }
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            Button(L("quit.yes")) {
                withAnimation(Motion.quick) { confirming = false }
                app.app?.terminate()
            }
            .controlSize(.small)
            .tint(Palette.bad)
            .buttonStyle(.borderedProminent)
        }
    }
}
