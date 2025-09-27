import Foundation
import ApplicationServices
import AVFoundation
import AppKit
import Combine

enum SecurityPermission {
    case accessibility
    case microphone
    case appleEvents
}

struct PermissionStatus {
    let isGranted: Bool
    let message: String
}

class SecurityChecker: ObservableObject {
    static let shared = SecurityChecker()
    
    @Published var microphonePermissionGranted: Bool = false
    @Published var accessibilityPermissionGranted: Bool = false
    @Published var appleEventsPermissionGranted: Bool = false
    
    private init() {
        updateAllPermissions()
    }

    
    func updateAllPermissions() {
        microphonePermissionGranted = checkMicrophonePermission().isGranted
        accessibilityPermissionGranted = checkAccessibilityPermission().isGranted
        appleEventsPermissionGranted = checkAppleEventsPermission().isGranted
    }
    
    func checkAllPermissions() -> [SecurityPermission: PermissionStatus] {
        var statuses: [SecurityPermission: PermissionStatus] = [:]
        
        statuses[.accessibility] = checkAccessibilityPermission()
        statuses[.microphone] = checkMicrophonePermission()
        statuses[.appleEvents] = checkAppleEventsPermission()
        
        return statuses
    }
    
    func checkAccessibilityPermission() -> PermissionStatus {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary
        
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        
        return PermissionStatus(
            isGranted: isTrusted,
            message: isTrusted ? "Accessibility permission granted" : "Accessibility permission required"
        )
    }
    
    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return PermissionStatus(
                isGranted: true,
                message: "Microphone permission granted"
            )
        case .notDetermined:
            return PermissionStatus(
                isGranted: false,
                message: "Microphone permission required"
            )
        case .denied, .restricted:
            return PermissionStatus(
                isGranted: false,
                message: "Microphone permission denied"
            )
        @unknown default:
            return PermissionStatus(
                isGranted: false,
                message: "Unknown microphone permission status"
            )
        }
    }
    
    func checkAppleEventsPermission() -> PermissionStatus {
        // Try to control System Events with a simple command
        let script = """
        tell application "System Events"
            set frontProcess to first process
            return name of frontProcess
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if error == nil {
                Logger.log("Apple Events permission granted", log: Logger.general)
                return PermissionStatus(
                    isGranted: true,
                    message: "Apple Events permission granted"
                )
            }

            // Check for permission denied error
            if let errorNumber = error?[NSAppleScript.errorNumber] as? NSNumber,
               errorNumber.intValue == -1743 {
                Logger.log("Apple Events permission denied", log: Logger.general)
                return PermissionStatus(
                    isGranted: false,
                    message: "Apple Events permission required for clipboard operations"
                )
            }

            Logger.log("Apple Events check error: \(error ?? [:])", log: Logger.general, type: .error)
        }

        return PermissionStatus(
            isGranted: false,
            message: "Apple Events permission required for clipboard operations"
        )
    }

    func areAllPermissionsGranted() -> Bool {
        let statuses = checkAllPermissions()
        return statuses.values.allSatisfy { $0.isGranted }
    }
    
    func getMissingPermissions() -> [String] {
        let statuses = checkAllPermissions()
        return statuses
            .filter { !$0.value.isGranted }
            .map { $0.value.message }
    }

    func requestAccessibilityPermission() {
        Logger.log("Requesting Accessibility permission", log: Logger.general)
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            Logger.log("Accessibility permission granted", log: Logger.general)
        } else {
            Logger.log("Accessibility permission denied", log: Logger.general)
        }
        // Update the published property to trigger UI refresh
        DispatchQueue.main.async {
            self.updateAllPermissions()
        }
    }

    func requestMicrophonePermission() {
        Logger.log("Starting microphone permission request", log: Logger.general)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    Logger.log("Microphone permission granted by user", log: Logger.general)
                } else {
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    switch status {
                    case .authorized:
                        Logger.log("Microphone permission granted by user", log: Logger.general)
                    case .denied:
                        Logger.log("Microphone permission denied by user", log: Logger.general)
                    case .restricted:
                        Logger.log("Microphone permission restricted by system", log: Logger.general)
                    case .notDetermined:
                        Logger.log("Microphone permission not determined", log: Logger.general)
                    @unknown default:
                        Logger.log("Unknown microphone permission status", log: Logger.general)
                    }
                }
                // Update the published property to trigger UI refresh
                self.updateAllPermissions()
            }
        }
    }

    func requestAppleEventsPermission() {
        Logger.log("Requesting Apple Events permission", log: Logger.general)
        // Try to control System Events with a more specific command that will trigger the permission dialog
        let script = """
        tell application "System Events"
            tell process "System Settings"
                return name
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if error == nil {
                Logger.log("Apple Events permission granted", log: Logger.general)
            } else {
                Logger.log("Apple Events permission denied: \(error?.description ?? "unknown error")", log: Logger.general)
            }
        } else {
            Logger.log("Failed to create AppleScript object", log: Logger.general)
        }
        // Update the published property to trigger UI refresh
        DispatchQueue.main.async {
            self.updateAllPermissions()
        }
    }
}
