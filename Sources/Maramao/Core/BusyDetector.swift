import AppKit
import CoreAudio
import CoreMediaIO
import MaramaoCore

/// Reads, on demand, whether the user is probably in a call or presenting.
/// Every signal is device state or window geometry: no permission prompt.
///
/// - Microphone: `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device.
/// - Camera: `kCMIODevicePropertyDeviceIsRunningSomewhere` on every video device.
/// - Presenting: the frontmost app is a presentation, video or call app and one of its
///   windows covers a whole screen (`CGWindowListCopyWindowInfo` bounds and owner PID are
///   readable without Screen Recording; titles are not needed).
@MainActor
enum BusyDetector {
    static func current() -> BusySignals {
        BusySignals(
            microphoneInUse: isMicrophoneInUse(),
            cameraInUse: isCameraInUse(),
            presenting: isPresenting()
        )
    }

    // MARK: - Microphone

    static func isMicrophoneInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return false }

        var running = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        let runningStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &running)
        return runningStatus == noErr && running != 0
    }

    // MARK: - Camera

    static func isCameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var dataSize = UInt32(0)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return false
        }
        let count = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        var dataUsed = UInt32(0)
        let status = devices.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return OSStatus(-1) }
            return CMIOObjectGetPropertyData(system, &address, 0, nil, dataSize, &dataUsed, base)
        }
        guard status == noErr else { return false }

        for device in devices where device != 0 {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            var running = UInt32(0)
            var used = UInt32(0)
            let result = CMIOObjectGetPropertyData(
                device, &runningAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running
            )
            if result == noErr, running != 0 { return true }
        }
        return false
    }

    // MARK: - Fullscreen presentation

    static func isPresenting() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              PresentationDetector.isPresentationApp(bundleID: app.bundleIdentifier) else {
            return false
        }
        let pid = Int(app.processIdentifier)
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else {
            return false
        }
        var windows: [CGRect] = []
        for window in info {
            guard let owner = window[kCGWindowOwnerPID as String] as? Int, owner == pid,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Quartz coordinates (top-left origin) to Cocoa, like `NSScreen.frame`.
            windows.append(NSScreen.cocoaRect(fromQuartz: bounds))
        }
        return PresentationDetector.coversAScreen(windows: windows, screens: NSScreen.screens.map(\.frame))
    }
}
