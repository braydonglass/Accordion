import Foundation
import IOKit.hid

/// Reads the hinge angle of a MacBook in degrees.
/// The sensor shows up as a HID device on the sensor usage page (0x20), usage 0x8A.
final class LidAngleSensor {
    private let manager: IOHIDManager
    private let device: IOHIDDevice

    init?() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDPrimaryUsagePageKey: 0x20,
            kIOHIDPrimaryUsageKey: 0x8A,
        ] as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first(where: { Self.readAngle(from: $0) != nil })
        else { return nil }
        self.manager = manager
        self.device = device
    }

    deinit {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func readAngle() -> Double? {
        Self.readAngle(from: device)
    }

    /// Feature report 1 is three bytes: the report ID, then the angle as a little-endian UInt16.
    private static func readAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        let degrees = Int(report[2]) << 8 | Int(report[1])
        return degrees <= 360 ? Double(degrees) : nil
    }
}
