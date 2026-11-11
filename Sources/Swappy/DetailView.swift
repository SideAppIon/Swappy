import SwiftUI

struct DetailView: View {
    let page: Page
    let snap: SystemSnapshot
    let detail: DetailSnapshot
    let back: () -> Void
    @State private var shown = false

    private var title: (String, String) {
        switch page {
        case .swap: return (L("swap.name"), "arrow.up.arrow.down.circle.fill")
        case .cpu: return (L("cpu"), "cpu")
        case .gpu: return (L("gpu"), "display")
        case .ram: return (L("ram"), "memorychip")
        case .ssd: return (L("ssd"), "internaldrive")
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: back) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(L("back")).font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .keyboardShortcut(.cancelAction)
                Spacer()
                Image(systemName: title.1).font(.system(size: 14)).foregroundStyle(Palette.gradient)
                Text(title.0).font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            ScrollView {
                VStack(spacing: 10) {
                    switch page {
                    case .swap: SwapDetail(snap: snap, detail: detail)
                    case .cpu: CPUDetail(snap: snap, detail: detail)
                    case .gpu: GPUDetail(detail: detail)
                    case .ram: RAMDetail(snap: snap)
                    case .ssd: SSDDetail(snap: snap, detail: detail)
                    }
                }
            }
        }
        // Bars and rings on the page fill in right after it slides into view.
        .environment(\.revealed, shown)
        .onAppear { shown = true }
    }
}

// MARK: - Building blocks

struct Block<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                Caption(title)
                content
            }
        }
        .reveal(1)
    }
}

struct Row: View {
    let label: String
    let value: String
    var color: Color?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                .rolling(value)
                .foregroundStyle(color ?? .primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct BigValue: View {
    let value: String
    let note: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                .rolling(value).fixedSize()
            Text(note).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }
}

struct LegendRow: View {
    let color: Color, name: String, note: String?, value: String, share: Double?
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9).padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 12, weight: .medium))
                if let note {
                    Text(note).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                if let share { Text(Fmt.percent(share)).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit() }
            }
        }
    }
}

// MARK: - Swap

struct SwapDetail: View {
    let snap: SystemSnapshot
    let detail: DetailSnapshot

    var body: some View {
        Block(title: L("sw.state")) {
            BigValue(value: Fmt.bytes(snap.swapUsed), note: L("swap.of", Fmt.bytes(snap.swapTotal)))
            Bar(fraction: snap.swapFraction, fill: AnyShapeStyle(Palette.gradient)).frame(height: 6)
            Row(label: L("sw.used"), value: Fmt.bytes(snap.swapUsed))
            Row(label: L("sw.reserved"), value: Fmt.bytes(snap.swapTotal))
            if detail.swapFileCount > 0 {
                Row(label: L("ssd.swapfiles"), value: L("ssd.files", Fmt.bytes(detail.swapFileBytes), detail.swapFileCount))
            }
        }
        Block(title: L("why.title")) {
            let paragraphs = [
                L("why.1"),
                L("why.2", Fmt.bytes(snap.memCompressed + snap.swapUsed), Fmt.bytes(snap.memCompressed), Fmt.bytes(snap.swapUsed)),
                L("why.3", Fmt.bytes(snap.swapTotal), max(detail.swapFileCount, 1)),
                L("why.4"),
            ]
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, text in
                Text(text).font(.system(size: 12)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 11)).foregroundStyle(Palette.warn)
                Text(L("why.tip")).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        Block(title: L("sw.writes")) {
            Row(label: L("sw.since", Fmt.duration(snap.uptime)), value: Fmt.bytes(snap.swapWritten))
            Row(label: L("sw.avg"), value: "≈ " + Fmt.perDay(snap.swapWrittenPerDay))
            Row(label: L("swap.now"), value: Fmt.rate(snap.swapWriteRate), color: SwapStatus(snap).writing ? Palette.warn : nil)
            Divider()
            Row(label: L("sw.rsince"), value: Fmt.bytes(snap.swapRead))
            Row(label: L("sw.rnow"), value: Fmt.rate(snap.swapReadRate))
        }
    }
}

// MARK: - CPU

struct CPUDetail: View {
    let snap: SystemSnapshot
    let detail: DetailSnapshot

    private var coreSummary: String {
        if let (p, e) = Hardware.coreKinds { return L("cpu.pe", p, e) }
        if Hardware.logicalCores != Hardware.physicalCores { return L("cpu.threads", Hardware.physicalCores, Hardware.logicalCores) }
        return L("cpu.count", Hardware.physicalCores)
    }

    var body: some View {
        Block(title: L("cpu.load")) {
            BigValue(value: Fmt.percent(snap.cpu), note: Hardware.cpuName)
            StackedBar(segments: [(snap.cpuUser, Palette.accentB), (snap.cpuSystem, Palette.warn),
                                  (max(1 - snap.cpu, 0), Color.primary.opacity(0.14))]).frame(height: 7)
            LegendRow(color: Palette.accentB, name: L("cpu.user"), note: nil, value: Fmt.percent(snap.cpuUser), share: nil)
            LegendRow(color: Palette.warn, name: L("cpu.system"), note: nil, value: Fmt.percent(snap.cpuSystem), share: nil)
            LegendRow(color: Color.primary.opacity(0.22), name: L("cpu.idle"), note: nil, value: Fmt.percent(max(1 - snap.cpu, 0)), share: nil)
        }
        Block(title: L("cpu.cores")) {
            Text(coreSummary).font(.system(size: 11)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 6) {
                ForEach(Array(detail.cores.enumerated()), id: \.offset) { i, load in
                    HStack(spacing: 6) {
                        Text("\(i + 1)").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                            .monospacedDigit().frame(width: 16, alignment: .trailing)
                        Bar(fraction: load, fill: AnyShapeStyle(Palette.level(load))).frame(height: 6)
                        Text(Fmt.percent(load)).font(.system(size: 10, weight: .semibold, design: .rounded))
                            .monospacedDigit().frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        Block(title: L("pwr.title")) {
            if let w = detail.cpuPower { Row(label: L("pwr.cpu"), value: Fmt.watts(w)) }
            if let w = detail.systemPower { Row(label: L("pwr.sys"), value: Fmt.watts(w)) }
            if let t = detail.cpuTemp { Row(label: L("temp"), value: Fmt.celsius(t), color: t > 95 ? Palette.bad : nil) }
            Row(label: L("thermal"), value: L("th.\(min(max(detail.thermal, 0), 3))"),
                color: detail.thermal >= 2 ? Palette.bad : (detail.thermal == 1 ? Palette.warn : Palette.good))
            if !detail.fans.isEmpty {
                Row(label: L("fans"), value: detail.fans.map { L("rpm", Fmt.number($0, 0)) }.joined(separator: " · "))
            }
            if detail.cpuPower == nil && detail.systemPower == nil && detail.cpuTemp == nil {
                Text(L("sensor.none")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        Card {
            VStack(spacing: 9) {
                if detail.loadAvg.count == 3 {
                    Row(label: L("loadavg"), value: detail.loadAvg.map { Fmt.number($0, 2) }.joined(separator: " / "))
                }
                Row(label: L("uptime"), value: Fmt.duration(snap.uptime))
            }
        }
    }
}

// MARK: - GPU

struct GPUDetail: View {
    let detail: DetailSnapshot

    var body: some View {
        if detail.gpus.isEmpty {
            Card { Text(L("gpu.none")).font(.system(size: 12)).foregroundStyle(.secondary) }
        }
        ForEach(detail.gpus) { gpu in
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    Text(gpu.name).font(.system(size: 13, weight: .semibold))
                    if let u = gpu.utilization {
                        BigValue(value: Fmt.percent(u), note: L("gpu.util"))
                        Bar(fraction: u, fill: AnyShapeStyle(Palette.level(u))).frame(height: 6)
                    } else {
                        Text(L("gpu.idle")).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let used = gpu.vramUsed, used > 0 {
                        Row(label: L("gpu.vram"),
                            value: gpu.vramTotal.map { L("x.of.y", Fmt.bytes(used), Fmt.bytes($0)) } ?? Fmt.bytes(used))
                    }
                }
            }
        }
        Block(title: L("pwr.title")) {
            if let w = detail.gpuPower { Row(label: L("pwr.gpu"), value: Fmt.watts(w)) }
            if let w = detail.systemPower { Row(label: L("pwr.sys"), value: Fmt.watts(w)) }
            if let t = detail.gpuTemp { Row(label: L("temp"), value: Fmt.celsius(t), color: t > 95 ? Palette.bad : nil) }
            if detail.gpuPower == nil && detail.systemPower == nil && detail.gpuTemp == nil {
                Text(L("sensor.none")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Memory

struct RAMDetail: View {
    let snap: SystemSnapshot

    var body: some View {
        let segments = MemorySegment.all(snap)
        Block(title: L("ram.breakdown")) {
            BigValue(value: Fmt.bytes(snap.memUsed), note: L("x.of.y", L("ram.used").lowercased(), Fmt.bytes(snap.memTotal)))
            StackedBar(segments: segments.map { (Double($0.bytes), $0.color) }).frame(height: 9)
            ForEach(segments) { seg in
                LegendRow(color: seg.color, name: seg.name, note: seg.note, value: Fmt.bytes(seg.bytes),
                          share: Double(seg.bytes) / Double(max(snap.memTotal, 1)))
            }
            Divider()
            Row(label: L("ram.pressure"), value: L("pr.\(snap.pressure >= 4 ? 4 : (snap.pressure >= 2 ? 2 : 1))"),
                color: Palette.pressure(snap.pressure))
        }
        Block(title: L("ram.compression")) {
            let packed = snap.memCompressed + snap.swapUsed
            Row(label: L("ram.stored"), value: Fmt.bytes(snap.compressorStored))
            Row(label: L("ram.inram"), value: Fmt.bytes(snap.memCompressed))
            Row(label: L("ram.ondisk"), value: Fmt.bytes(snap.swapUsed))
            if packed > 0, snap.compressorStored > 0 {
                Row(label: L("ram.ratio"), value: "× " + Fmt.number(Double(snap.compressorStored) / Double(packed), 1))
            }
        }
    }
}

// MARK: - Disk

struct SSDDetail: View {
    let snap: SystemSnapshot
    let detail: DetailSnapshot

    var body: some View {
        let used = snap.diskTotal > snap.diskFree ? snap.diskTotal - snap.diskFree : 0
        Block(title: L("ssd.space")) {
            BigValue(value: Fmt.bytes(snap.diskFree), note: L("x.of.y", L("ssd.free").lowercased(), Fmt.bytes(snap.diskTotal)))
            Bar(fraction: snap.diskFraction, fill: AnyShapeStyle(Palette.level(snap.diskFraction))).frame(height: 6)
            if !Hardware.diskModel.isEmpty { Row(label: L("ssd.model"), value: Hardware.diskModel) }
            Row(label: L("ssd.capacity"), value: Fmt.bytes(snap.diskTotal))
            Row(label: L("ssd.used"), value: Fmt.bytes(used))
            Row(label: L("ssd.free"), value: Fmt.bytes(snap.diskFree))
            if detail.swapFileCount > 0 {
                Row(label: L("ssd.swapfiles"), value: L("ssd.files", Fmt.bytes(detail.swapFileBytes), detail.swapFileCount))
            }
        }
        Block(title: L("ssd.activity")) {
            Row(label: L("ssd.rnow"), value: Fmt.rate(detail.diskReadRate))
            Row(label: L("ssd.wnow"), value: Fmt.rate(detail.diskWriteRate))
        }
        Block(title: L("ssd.wear", Fmt.duration(snap.uptime))) {
            Row(label: L("ssd.wtotal"), value: Fmt.bytes(detail.diskWriteTotal))
            if detail.diskWriteTotal > 0 {
                let share = min(Double(snap.swapWritten) / Double(detail.diskWriteTotal), 1)
                Row(label: L("ssd.wswap"), value: "\(Fmt.bytes(snap.swapWritten)) · \(Fmt.percent(share))")
                StackedBar(segments: [(share, Palette.accentB), (1 - share, Color.primary.opacity(0.14))]).frame(height: 6)
            }
            Row(label: L("ssd.rtotal"), value: Fmt.bytes(detail.diskReadTotal))
        }
    }
}
