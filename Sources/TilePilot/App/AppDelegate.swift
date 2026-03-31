import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar item manually via AppKit (reliable, no SwiftUI scene dependency)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "TilePilot") {
                img.isTemplate = true
                button.image = img
            } else {
                // Fallback if SF Symbol fails
                button.title = "⊞"
            }
        }
        
        rebuildMenu()

        if !appState.hasCompletedOnboarding || !AXIsProcessTrusted() {
            if !appState.hasCompletedOnboarding {
                TilePilotLogger.info("First launch, showing onboarding")
            } else {
                TilePilotLogger.warning("Accessibility permission not granted")
                promptForAccessibility()
            }
        } else {
            TilePilotLogger.info("Accessibility permission granted, \(appState.config.layouts.count) layouts loaded")
        }
        
        // Rebuild menu when config changes
        NotificationCenter.default.addObserver(forName: .init("TilePilotConfigReloaded"), object: nil, queue: .main) { [weak self] _ in
            self?.rebuildMenu()
        }
    }
    
    func rebuildMenu() {
        let menu = NSMenu()
        
        let sortedLayouts = appState.config.layouts.keys.sorted()
        for name in sortedLayouts {
            let displayName = name.replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
            
            let item = NSMenuItem(title: displayName, action: #selector(layoutClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            
            if let layout = appState.config.layouts[name], !layout.hotkey.isEmpty {
                let symbols = HotkeyManager.displayString(for: layout.hotkey)
                item.title = "\(displayName)  \(symbols)"
            }
            
            if appState.activeLayoutName == name {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        if !sortedLayouts.isEmpty {
            menu.addItem(.separator())
        }
        
        let restoreItem = NSMenuItem(title: "Restore Previous", action: #selector(restoreClicked), keyEquivalent: "")
        restoreItem.target = self
        restoreItem.isEnabled = appState.hasSnapshot
        menu.addItem(restoreItem)
        
        menu.addItem(.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        
        let editItem = NSMenuItem(title: "Edit Config...", action: #selector(editConfigClicked), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)
        
        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadClicked), keyEquivalent: "r")
        reloadItem.target = self
        reloadItem.keyEquivalentModifierMask = .command
        menu.addItem(reloadItem)
        
        menu.addItem(.separator())
        
        let quitItem = NSMenuItem(title: "Quit TilePilot", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func layoutClicked(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        appState.applyLayout(named: name)
        rebuildMenu()
    }
    
    @objc func restoreClicked() {
        appState.restorePrevious()
        rebuildMenu()
    }
    
    @objc func settingsClicked() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func editConfigClicked() {
        let configPath = ConfigLoader.configFilePath.path
        if let editor = ProcessInfo.processInfo.environment["EDITOR"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [editor, configPath]
            try? process.run()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
        }
    }
    
    @objc func reloadClicked() {
        appState.reloadConfig()
        rebuildMenu()
    }
    
    @objc func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.hotkeyManager.unregisterAll()
        appState.configLoader.stopWatching()
        appState.displayManager.stopObserving()
    }

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "TilePilot Needs Accessibility Access"
        alert.informativeText = "TilePilot needs accessibility permissions to move and resize windows. Please grant access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
