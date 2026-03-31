import Foundation
import AppKit
import ApplicationServices

extension AXUIElement {

    /// Get all windows for this application element
    func windows() -> [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(self, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else { return nil }
        return windows
    }

    /// Get/set window position
    var position: CGPoint? {
        get {
            var value: AnyObject?
            guard AXUIElementCopyAttributeValue(self, kAXPositionAttribute as CFString, &value) == .success,
                  let axValue = value else { return nil }
            var point = CGPoint.zero
            AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
            return point
        }
        set {
            guard var point = newValue else { return }
            guard let axValue = AXValueCreate(.cgPoint, &point) else { return }
            AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, axValue)
        }
    }

    /// Get/set window size
    var size: CGSize? {
        get {
            var value: AnyObject?
            guard AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &value) == .success,
                  let axValue = value else { return nil }
            var size = CGSize.zero
            AXValueGetValue(axValue as! AXValue, .cgSize, &size)
            return size
        }
        set {
            guard var size = newValue else { return }
            guard let axValue = AXValueCreate(.cgSize, &size) else { return }
            AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, axValue)
        }
    }

    /// Check if window is minimized
    var isMinimized: Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXMinimizedAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    /// Get window title
    var title: String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Raise window to front
    @discardableResult
    func raise() -> Bool {
        AXUIElementPerformAction(self, kAXRaiseAction as CFString) == .success
    }

    /// Get the role of this element (e.g. "AXWindow")
    var role: String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Get the subrole (e.g. "AXStandardWindow")
    var subrole: String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXSubroleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    /// Check if window is in full screen mode
    var isFullScreen: Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(self, "AXFullScreen" as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }
}
