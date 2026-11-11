import Darwin
import Foundation
import IOKit

struct GPUInfo: Identifiable {
    var id: String { name }
    var name: String
    var utilization: Double?    // 0…1
    var vramUsed: UInt64?
    var vramTotal: UInt64?
}

/// Everything shown on the detail pages. Sampled only while the window is open.
struct DetailSnapshot {
    var cores: [Double] = []
    var loadAvg: [Double] = []
    var cpuPower: Double?
    var gpuPower: Double?
    var systemPower: Double?
    var cpuTemp: Double?
    var gpuTemp: Double?
    var fans: [Double] = []
    var thermal: Int = 0
    var gpus: [GPUInfo] = []
    var diskReadRate: Double = 0
    var diskWriteRate: Double = 0
    var diskReadTotal: UInt64 = 0
    var diskWriteTotal: UInt64 = 0
    var swapFileCount: Int = 0
    var swapFileBytes: UInt64 = 0

    var gpuUtilization: Double? { gpus.compactMap(\.utilization).max() }
}

/// Facts that never change while the app runs.
enum Hardware {
    static let cpuName: String = sysctlString("machdep.cpu.brand_string")
        .replacingOccurrences(of: "(R)", with: "").replacingOccurrences(of: "(TM)", with: "")
        .replacingOccurrences(of: " CPU", with: "")
    static let physicalCores = sysctlInt("hw.physicalcpu")
    static let logicalCores = sysctlInt("hw.logicalcpu")
    /// (performance, efficiency) on Apple Silicon, nil on Intel.
    static let coreKinds: (Int, Int)? = {
        guard sysctlInt("hw.nperflevels") >= 2 else { return nil }
        return (sysctlInt("hw.perflevel0.physicalcpu"), sysctlInt("hw.perflevel1.physicalcpu"))
    }()
    static let diskModel: String = {
        for cls in ["IONVMeController", "IOAHCIBlockStorageDevice"] {
            var iter: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(cls), &iter) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iter) }
            while case let entry = IOIteratorNext(iter), entry != 0 {
                defer { IOObjectRelease(entry) }
                for key in ["Model Number", "Model"] {
                    if let s = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? String, !s.isEmpty {
                        return s.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        return ""
    }()

    private static func sysctlInt(_ name: String) -> Int {
        var v: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname(name, &v, &size, nil, 0) == 0 ? Int(v) : 0
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "" }
        return String(cString: buf)
    }
}

/// Not thread-safe: use from a single queue.
final class DetailSampler {
    private let host = mach_host_self()
    private var prevCores: [(UInt64, UInt64)] = []     // (busy, total)
    private var prevDisk: (time: TimeInterval, read: UInt64, write: UInt64)?
    private var swapFiles: (time: TimeInterval, count: Int, bytes: UInt64)?
    private var sensorKey: [String: String] = [:]      // sensor kind → SMC key that works on this Mac ("" = none)

    func reset() {
        prevCores = []
        prevDisk = nil
    }

    func sample() -> DetailSnapshot {
        var d = DetailSnapshot()
        let now = ProcessInfo.processInfo.systemUptime
        d.cores = coreUsage()

        var load = [Double](repeating: 0, count: 3)
        if getloadavg(&load, 3) == 3 { d.loadAvg = load }
        d.thermal = ProcessInfo.processInfo.thermalState.rawValue

        d.cpuPower = sensor("cpuPower", ["PCPT"])
        d.systemPower = sensor("sysPower", ["PSTR"])
        let igpu = sensor("igpuPower", ["PCPG"]), dgpu = sensor("dgpuPower", ["PG0R"])
        if igpu != nil || dgpu != nil { d.gpuPower = (igpu ?? 0) + (dgpu ?? 0) }
        d.cpuTemp = sensor("cpuTemp", ["TC0P", "TCXC", "Tp09", "Tp0T", "Tp01", "Te05"], valid: 1...130)
        d.gpuTemp = sensor("gpuTemp", ["TG0P", "TGDD", "Tg05", "Tg0D"], valid: 1...130)
        if let n = sensor("fanCount", ["FNum"]), n >= 1 {
            for i in 0..<min(Int(n), 4) {
                var rpm = 0.0
                if sw_smc_read("F\(i)Ac", &rpm) == 0 { d.fans.append(rpm) }
            }
        }

        d.gpus = gpus()

        let (r, w) = diskTotals()
        d.diskReadTotal = r
        d.diskWriteTotal = w
        if let p = prevDisk, now > p.time, r >= p.read, w >= p.write {
            d.diskReadRate = Double(r - p.read) / (now - p.time)
            d.diskWriteRate = Double(w - p.write) / (now - p.time)
        }
        prevDisk = (now, r, w)

        if swapFiles == nil || now - swapFiles!.time > 20 {
            var count = 0
            var bytes: UInt64 = 0
            let dir = "/System/Volumes/VM"
            for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where name.hasPrefix("swapfile") {
                count += 1
                var st = stat()
                if stat(dir + "/" + name, &st) == 0 { bytes += UInt64(st.st_size) }
            }
            swapFiles = (now, count, bytes)
        }
        d.swapFileCount = swapFiles?.count ?? 0
        d.swapFileBytes = swapFiles?.bytes ?? 0
        return d
    }

    private func sensor(_ kind: String, _ keys: [String], valid: ClosedRange<Double> = 0...100_000) -> Double? {
        var v = 0.0
        if let known = sensorKey[kind] {
            return !known.isEmpty && sw_smc_read(known, &v) == 0 && valid.contains(v) ? v : nil
        }
        for key in keys where sw_smc_read(key, &v) == 0 && valid.contains(v) {
            sensorKey[kind] = key
            return v
        }
        sensorKey[kind] = ""
        return nil
    }

    private func coreUsage() -> [Double] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var current: [(UInt64, UInt64)] = []
        for i in 0..<Int(cpuCount) {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            let system = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            let idle = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            let nice = UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            current.append((user + system + nice, user + system + nice + idle))
        }
        defer { prevCores = current }
        guard prevCores.count == current.count else { return current.map { _ in 0 } }
        return zip(current, prevCores).map { c, p in
            c.1 > p.1 && c.0 >= p.0 ? min(1, Double(c.0 - p.0) / Double(c.1 - p.1)) : 0
        }
    }

    private func gpus() -> [GPUInfo] {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iter) }
        var result: [GPUInfo] = []
        while case let entry = IOIteratorNext(iter), entry != 0 {
            defer { IOObjectRelease(entry) }
            let search = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            func parentProperty(_ key: String) -> Any? {
                IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key as CFString, kCFAllocatorDefault, search)
            }
            var name = ""
            if let data = parentProperty("model") as? Data {
                name = String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
            } else if let s = parentProperty("model") as? String {
                name = s
            }
            if name.isEmpty { name = "GPU" }

            let stats = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] ?? [:]
            func number(_ keys: [String]) -> Double? {
                for k in keys { if let n = stats[k] as? NSNumber { return n.doubleValue } }
                return nil
            }
            var gpu = GPUInfo(name: name)
            if let u = number(["Device Utilization %", "GPU Activity(%)", "Device Utilization % at cur p-state"]) {
                gpu.utilization = min(max(u / 100, 0), 1)
            }
            if let used = number(["vramUsedBytes", "In use system memory"]) { gpu.vramUsed = UInt64(max(used, 0)) }
            if let total = parentProperty("VRAM,totalMB") as? NSNumber { gpu.vramTotal = total.uint64Value << 20 }

            if let i = result.firstIndex(where: { $0.name == name }) {
                // Some GPUs register two accelerators; keep the busier reading.
                if (gpu.utilization ?? -1) > (result[i].utilization ?? -1) { result[i].utilization = gpu.utilization }
                result[i].vramUsed = max(result[i].vramUsed ?? 0, gpu.vramUsed ?? 0)
            } else {
                result.append(gpu)
            }
        }
        return result
    }

    private func diskTotals() -> (UInt64, UInt64) {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iter) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iter) }
        var read: UInt64 = 0, write: UInt64 = 0
        while case let entry = IOIteratorNext(iter), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let stats = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (read, write)
    }
}
