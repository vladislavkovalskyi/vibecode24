import Foundation
import IOKit
import IOKit.ps

public struct BatteryState: Equatable, Sendable {
    public let percent: Int
    public let onBattery: Bool
    public let charging: Bool

    public init(percent: Int, onBattery: Bool, charging: Bool) {
        self.percent = percent
        self.onBattery = onBattery
        self.charging = charging
    }
}

public enum SystemSensors {
    /// Nil on a Mac without a battery.
    public static func battery() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return BatteryState(percent: Int((Double(current) / Double(max) * 100).rounded()),
                                onBattery: providing == kIOPSBatteryPowerValue,
                                charging: (description[kIOPSIsChargingKey] as? Bool) ?? false)
        }
        return nil
    }

    /// Reads `AppleClamshellState` from IOPMrootDomain. Nil on a Mac without a lid.
    public static func isLidClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString,
                                                          kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue
    }

    public static var isThermalCritical: Bool {
        ProcessInfo.processInfo.thermalState == .critical
    }
}
