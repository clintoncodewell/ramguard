import Darwin
import Foundation

// Stateless helpers; the caller controls when to sample swap usage.
enum SwapUsage {
    static func fetchUsedBytes() -> UInt64? {
        // Read the kernel's swap counters in-process; never scan or open swap files.
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0,
              size == MemoryLayout<xsw_usage>.size else { return nil }
        return usage.xsu_used
    }

    static func formattedGB(_ usedBytes: UInt64?) -> String {
        guard let usedBytes else { return "—" }
        return String(format: "%.1f GB", Double(usedBytes) / 1_073_741_824)
    }
}
