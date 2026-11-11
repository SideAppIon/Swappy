import Foundation

enum Fmt {
    static func bytes(_ b: UInt64) -> String { bytes(Double(b)) }

    static func bytes(_ b: Double) -> String {
        let units = L10n.pick(Strings.byteUnits)
        var v = max(b, 0)
        var i = 0
        while v >= 1000, i < units.count - 1 { v /= 1024; i += 1 }
        let digits = i >= 3 ? (v < 10 ? 2 : 1) : (i == 0 || v >= 10 ? 0 : 1)
        return number(v, digits) + " " + units[i]
    }

    static func number(_ v: Double, _ digits: Int) -> String {
        v.formatted(.number.precision(.fractionLength(digits)).locale(L10n.locale))
    }

    static func rate(_ bytesPerSecond: Double) -> String { L("per.s", bytes(bytesPerSecond)) }
    static func perDay(_ bytesPerDay: Double) -> String { L("per.day", bytes(bytesPerDay)) }
    static func percent(_ f: Double) -> String { "\(Int((min(max(f, 0), 1) * 100).rounded())) %" }
    static func watts(_ w: Double) -> String { number(w, 1) + " W" }
    static func celsius(_ t: Double) -> String { number(t, 0) + " °C" }

    static func duration(_ seconds: TimeInterval) -> String {
        let u = L10n.pick(Strings.timeUnits)
        let s = Int(max(seconds, 0))
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d) \(u[0]) \(h) \(u[1])" }
        if h > 0 { return "\(h) \(u[1]) \(m) \(u[2])" }
        return "\(m) \(u[2])"
    }
}
