import AppKit
import Darwin

struct AppUsage: Identifiable {
    let id: String
    var name: String
    var app: NSRunningApplication?
    var compressed: UInt64 = 0      // memory living in the compressor / swap
    var footprint: UInt64 = 0
    var processes: Int = 0
    var swapEstimate: UInt64 = 0
}

/// Per-process compressed memory, grouped by owning app. Not thread-safe: use from a single queue.
final class ProcessScanner {
    private struct Info { var responsible: pid_t; var name: String }
    private var cache: [pid_t: Info] = [:]
    private let available = sw_ledger_init() == 0

    func scan(running: [NSRunningApplication], swapUsed: UInt64) -> [AppUsage] {
        guard available else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let n = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        guard n > 0 else { return [] }

        var apps: [pid_t: NSRunningApplication] = [:]
        for a in running { apps[a.processIdentifier] = a }

        var groups: [String: AppUsage] = [:]
        var seen = Set<pid_t>()
        var totalCompressed: UInt64 = 0

        for pid in pids[0..<min(n, pids.count)] where pid > 0 {
            var c: Int64 = 0, f: Int64 = 0
            guard sw_ledger_get(pid, &c, &f) == 0, c > 0 || f > 0 else { continue }
            seen.insert(pid)
            let compressed = UInt64(max(c, 0)), footprint = UInt64(max(f, 0))
            totalCompressed += compressed

            let info: Info
            if let cached = cache[pid] {
                info = cached
            } else {
                info = Info(responsible: sw_responsible_pid(pid), name: Self.name(of: pid))
                cache[pid] = info
            }

            let key: String, name: String
            var app: NSRunningApplication?
            if let a = apps[info.responsible] ?? apps[pid] {
                key = "app:\(a.processIdentifier)"
                name = a.localizedName ?? info.name
                app = a
            } else {
                name = info.responsible == pid ? info.name : (cache[info.responsible]?.name ?? Self.name(of: info.responsible))
                key = "proc:\(name)"
            }
            var g = groups[key] ?? AppUsage(id: key, name: name, app: app)
            g.compressed += compressed
            g.footprint += footprint
            g.processes += 1
            groups[key] = g
        }
        if cache.count > seen.count + 200 { cache = cache.filter { seen.contains($0.key) } }

        var result = groups.values.filter { $0.compressed >= 1 << 20 }.sorted { $0.compressed > $1.compressed }
        if result.count > 40 { result.removeSubrange(40...) }
        if totalCompressed > 0 {
            for i in result.indices {
                result[i].swapEstimate = UInt64(Double(swapUsed) * Double(result[i].compressed) / Double(totalCompressed))
            }
        }
        return result
    }

    private static func name(of pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 4096)
        if proc_name(pid, &buf, UInt32(buf.count)) > 0 {
            let s = String(cString: buf)
            if !s.isEmpty { return s }
        }
        if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 {
            let s = (String(cString: buf) as NSString).lastPathComponent
            if !s.isEmpty { return s }
        }
        return pid == 0 ? "kernel_task" : "PID \(pid)"
    }
}
