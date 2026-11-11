import Darwin
import Foundation

struct SystemSnapshot {
    var time: TimeInterval = 0
    var cpu: Double = 0                 // 0…1
    var memTotal: UInt64 = 0
    var memApp: UInt64 = 0
    var memWired: UInt64 = 0
    var memCompressed: UInt64 = 0       // RAM occupied by the compressor
    var memCached: UInt64 = 0           // file cache + purgeable
    var compressorStored: UInt64 = 0    // original size of the data held by the compressor (RAM + swap)
    var cpuUser: Double = 0
    var cpuSystem: Double = 0
    var pressure: Int32 = 1             // 1 normal, 2 warning, 4 critical
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapWritten: UInt64 = 0         // bytes written to swap since boot
    var swapRead: UInt64 = 0
    var swapWriteRate: Double = 0       // bytes/s
    var swapReadRate: Double = 0
    var diskTotal: UInt64 = 0
    var diskFree: UInt64 = 0
    var netIn: Double = 0               // bytes/s
    var netOut: Double = 0
    var bootTime: TimeInterval = 0

    var memUsed: UInt64 { memApp + memWired + memCompressed }
    var memFree: UInt64 { memTotal > memUsed + memCached ? memTotal - memUsed - memCached : 0 }
    var uptime: TimeInterval { max(Date().timeIntervalSince1970 - bootTime, 1) }
    /// Average swap writes per day since startup (the plain total while uptime is under a day).
    var swapWrittenPerDay: Double { Double(swapWritten) / max(uptime / 86400, 1) }
    var memFraction: Double { memTotal > 0 ? Double(memUsed) / Double(memTotal) : 0 }
    var swapFraction: Double { swapTotal > 0 ? Double(swapUsed) / Double(swapTotal) : 0 }
    var diskFraction: Double { diskTotal > 0 ? Double(diskTotal - min(diskFree, diskTotal)) / Double(diskTotal) : 0 }
}

/// Reads cheap kernel counters. Not thread-safe: use from a single queue.
final class SystemSampler {
    private let host = mach_host_self()
    private let pageSize = UInt64(vm_kernel_page_size)
    private let memTotal = ProcessInfo.processInfo.physicalMemory
    private let bootTime: TimeInterval

    private var prevTicks: (UInt64, UInt64, UInt64)?    // (user, system, total)
    private var prevSwap: (time: TimeInterval, outs: UInt64, ins: UInt64)?
    private var prevNet: (time: TimeInterval, counters: [String: (UInt32, UInt32)])?
    private var disk: (time: TimeInterval, total: UInt64, free: UInt64)?
    private var lastCPU = (0.0, 0.0, 0.0)

    init() {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &tv, &size, nil, 0)
        bootTime = TimeInterval(tv.tv_sec)
    }

    /// `detailed` adds disk and network, which are only needed while the window is visible.
    func sample(detailed: Bool) -> SystemSnapshot {
        var s = SystemSnapshot()
        let now = ProcessInfo.processInfo.systemUptime
        s.time = now
        s.bootTime = bootTime
        s.memTotal = memTotal
        (s.cpu, s.cpuUser, s.cpuSystem) = cpuUsage()

        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let app = UInt64(vm.internal_page_count) &- UInt64(vm.purgeable_count)
            s.memApp = (UInt64(vm.internal_page_count) >= UInt64(vm.purgeable_count) ? app : 0) * pageSize
            s.memWired = UInt64(vm.wire_count) * pageSize
            s.memCompressed = UInt64(vm.compressor_page_count) * pageSize
            s.memCached = (UInt64(vm.external_page_count) + UInt64(vm.purgeable_count)) * pageSize
            s.compressorStored = vm.total_uncompressed_pages_in_compressor * pageSize
            s.swapWritten = vm.swapouts * pageSize
            s.swapRead = vm.swapins * pageSize
            if let p = prevSwap, now > p.time, vm.swapouts >= p.outs, vm.swapins >= p.ins {
                let dt = now - p.time
                s.swapWriteRate = Double((vm.swapouts - p.outs) * pageSize) / dt
                s.swapReadRate = Double((vm.swapins - p.ins) * pageSize) / dt
            }
            prevSwap = (now, vm.swapouts, vm.swapins)
        }

        var xsw = xsw_usage()
        var xsize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &xsw, &xsize, nil, 0) == 0 {
            s.swapTotal = xsw.xsu_total
            s.swapUsed = xsw.xsu_used
        }

        var level: Int32 = 1
        var lsize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &lsize, nil, 0) == 0 {
            s.pressure = level
        }

        if detailed {
            if disk == nil || now - disk!.time > 30 {
                let url = URL(fileURLWithPath: "/System/Volumes/Data")
                if let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
                   let total = v.volumeTotalCapacity, let free = v.volumeAvailableCapacityForImportantUsage {
                    disk = (now, UInt64(total), UInt64(max(free, 0)))
                }
            }
            (s.netIn, s.netOut) = networkRates(now: now)
        } else {
            prevNet = nil
        }
        if let d = disk {
            s.diskTotal = d.total
            s.diskFree = d.free
        }
        return s
    }

    private func cpuUsage() -> (Double, Double, Double) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return lastCPU }
        let t = info.cpu_ticks
        let user = UInt64(t.0) + UInt64(t.3), system = UInt64(t.1)
        let total = user + system + UInt64(t.2)
        defer { prevTicks = (user, system, total) }
        if let p = prevTicks, total > p.2, user >= p.0, system >= p.1 {
            let dt = Double(total - p.2)
            let u = Double(user - p.0) / dt, sy = Double(system - p.1) / dt
            lastCPU = (min(1, u + sy), u, sy)
        }
        return lastCPU
    }

    private func networkRates(now: TimeInterval) -> (Double, Double) {
        var counters: [String: (UInt32, UInt32)] = [:]
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifap) }
        var cur = ifap
        while let p = cur {
            defer { cur = p.pointee.ifa_next }
            guard let addr = p.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = p.pointee.ifa_data else { continue }
            let name = String(cString: p.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = (d.ifi_ibytes, d.ifi_obytes)
        }
        defer { prevNet = (now, counters) }
        guard let p = prevNet, now > p.time else { return (0, 0) }
        var din: UInt64 = 0, dout: UInt64 = 0
        for (name, c) in counters {
            guard let old = p.counters[name] else { continue }
            din += UInt64(c.0 &- old.0)      // 32-bit counters wrap; &- keeps the delta right
            dout += UInt64(c.1 &- old.1)
        }
        let dt = now - p.time
        return (Double(din) / dt, Double(dout) / dt)
    }
}
