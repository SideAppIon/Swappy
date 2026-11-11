import SwiftUI
import WidgetKit

// The widget is sandboxed and can't see the app's data, so it reads the same kernel counters itself.

struct SwapEntry: TimelineEntry {
    let date: Date
    let snap: SystemSnapshot
}

struct SwapProvider: TimelineProvider {
    private static func entry() -> SwapEntry {
        SwapEntry(date: Date(), snap: SystemSampler().sample(detailed: false))
    }

    func placeholder(in context: Context) -> SwapEntry { Self.entry() }

    func getSnapshot(in context: Context, completion: @escaping (SwapEntry) -> Void) {
        completion(Self.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwapEntry>) -> Void) {
        // macOS decides the real cadence; the app also nudges the widget when swap changes.
        completion(Timeline(entries: [Self.entry()], policy: .after(Date().addingTimeInterval(300))))
    }
}

private enum Tint {
    static let a = Color(red: 0.16, green: 0.74, blue: 0.82)
    static let b = Color(red: 0.42, green: 0.42, blue: 0.98)
    static let gradient = LinearGradient(colors: [a, b], startPoint: .leading, endPoint: .trailing)
    static let good = Color(red: 0.20, green: 0.74, blue: 0.45)
    static let warn = Color(red: 0.96, green: 0.62, blue: 0.14)
    static let bad = Color(red: 0.93, green: 0.30, blue: 0.30)
    static func pressure(_ level: Int32) -> Color { level >= 4 ? bad : (level >= 2 ? warn : good) }
}

private struct WBar: View {
    let fraction: Double
    let fill: AnyShapeStyle
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(fill)
                    .frame(width: max(geo.size.height, geo.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: 5)
    }
}

private struct SwapBlock: View {
    let snap: SystemSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down.circle.fill").foregroundStyle(Tint.gradient)
                Text(L("w.swap")).fontWeight(.semibold)
                Spacer(minLength: 0)
                Circle().fill(Tint.pressure(snap.pressure)).frame(width: 7, height: 7)
            }
            .font(.system(size: 13))
            Spacer(minLength: 0)
            Text(Fmt.bytes(snap.swapUsed))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(L("swap.of", Fmt.bytes(snap.swapTotal)))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .minimumScaleFactor(0.6).lineLimit(1)
            WBar(fraction: snap.swapFraction, fill: AnyShapeStyle(Tint.gradient))
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 9, weight: .semibold))
                Text("≈ " + Fmt.perDay(snap.swapWrittenPerDay))
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .minimumScaleFactor(0.7).lineLimit(1)
        }
    }
}

private struct WRow: View {
    let label: String, value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Text(value).fontWeight(.semibold).monospacedDigit().lineLimit(1)
        }
        .font(.system(size: 11))
    }
}

struct SwappyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SwapEntry

    var body: some View {
        let s = entry.snap
        Group {
            if family == .systemSmall {
                SwapBlock(snap: s)
            } else {
                HStack(spacing: 16) {
                    SwapBlock(snap: s).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(L("ram")).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(Fmt.percent(s.memFraction)).font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        WBar(fraction: s.memFraction, fill: AnyShapeStyle(Tint.pressure(s.pressure)))
                        Spacer(minLength: 0)
                        WRow(label: L("ram.app"), value: Fmt.bytes(s.memApp))
                        WRow(label: L("ram.comp"), value: Fmt.bytes(s.memCompressed))
                        WRow(label: L("ram.free"), value: Fmt.bytes(s.memFree + s.memCached))
                        WRow(label: L("swap.written", Fmt.duration(s.uptime)), value: Fmt.bytes(s.swapWritten))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SwappyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SwappyWidget", provider: SwapProvider()) { entry in
            SwappyWidgetView(entry: entry)
        }
        .configurationDisplayName(L("w.name"))
        .description(L("w.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SwappyWidgets: WidgetBundle {
    var body: some Widget { SwappyWidget() }
}
