//
//  ContentView.swift
//  battery-charge-reminder
//
//  Created by Nayam Amarshe on 15/02/24.
//

import SwiftUI
import UserNotifications
import IOKit.ps
import Cocoa

struct ContentView: View {
    @StateObject private var batteryMonitor = BatteryMonitor.shared
    
    private func quitApp() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        NSApplication.shared.terminate(nil)
    }
    
    var body: some View {
        VStack {
            Label("Battery Charge Reminder", systemImage: "minus.plus.batteryblock.stack.fill")
                .font(.headline)
                .padding()
            
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text("Minimum Threshold: \(batteryMonitor.minThreshold, specifier: "%.f")%")
                    Slider(value: $batteryMonitor.minThreshold, in: 1...(batteryMonitor.maxThreshold > 2 ? batteryMonitor.maxThreshold - 1: batteryMonitor.maxThreshold), step: 1){_ in
                        print(batteryMonitor.minThreshold)
                    }.padding()
                }

                VStack(alignment: .leading) {
                    Text("Maximum Threshold: \(batteryMonitor.maxThreshold, specifier: "%.f")%")
                    Slider(value: $batteryMonitor.maxThreshold, in: (batteryMonitor.minThreshold < 99 ? batteryMonitor.minThreshold + 1 : batteryMonitor.minThreshold)...100, step: 1) {_ in
                        print(batteryMonitor.maxThreshold)
                    }.padding()
                }

                VStack(alignment: .leading) {
                    Text("Reminder Frequency: \(Int(batteryMonitor.reminderFrequency)) minutes")
                    Slider(value: $batteryMonitor.reminderFrequency, in: 1...60, step: 1).padding()
                }
                
                Button(action: quitApp) {
                    Label("Quit", systemImage: "xmark.circle")
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 300, height:350)
    }
}

#Preview {
    ContentView()
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    
    func openNotificationSettings() {
        // Check if the app has a valid bundle identifier
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            // Create the URL using the bundle identifier (id parameter)
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleIdentifier)")
            
            // Safely open the URL using NSWorkspace
            if let validURL = url {
                NSWorkspace.shared.open(validURL)
            }
        }
    }
    
    func showAlertToGuideUserToSystemPreferences() {
        // Dispatch to the main queue
        DispatchQueue.main.async {
            // Create a custom alert using NSAlert
            let alert = NSAlert()
            alert.messageText = "Notification Permissions Denied"
            alert.informativeText = "Please enable notification permissions for this app in System Preferences."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            // Safely unwrap NSApp.mainWindow
            if let mainWindow = NSApp.mainWindow {
                alert.beginSheetModal(for: mainWindow) { response in
                    if response == .alertFirstButtonReturn {
                        // Open Notification settings for your app in System Preferences
                        self.openNotificationSettings()
                    }
                }
            } else {
                // If no main window is available, display the alert in a different way
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open Notification settings for your app in System Preferences
                    self.openNotificationSettings()
                }
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                // Handle the error
                print("Notification authorization error: \(error.localizedDescription)")
                self.showAlertToGuideUserToSystemPreferences()
            } else {
                if granted {
                    print("Notification authorization granted")
                } else {
                    print("Notification authorization denied")
                }
            }
        }
        
        // Create a status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "minus.plus.batteryblock.stack.fill", accessibilityDescription: nil)
            button.action = #selector(togglePopover(_:))
        }
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        
        // Set the content view of the popover
        let contentView = ContentView()
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Start battery monitoring
        BatteryMonitor.shared.startMonitoring()
        
        // Request authorization for notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
            if success {
                print("Notification authorization granted.")
            } else if let error = error {
                print("Notification authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()
    
    private let defaults = UserDefaults.standard
    
    @Published var minThreshold: Double {
        didSet {
            saveSettings()
        }
    }
    @Published var maxThreshold: Double {
        didSet {
            saveSettings()
        }
    }
    @Published var reminderFrequency: Double {
        didSet {
            saveSettings()
        }
    }
    
    private init() {
        self.minThreshold = defaults.double(forKey: "minThreshold")
        self.maxThreshold = defaults.double(forKey: "maxThreshold")
        self.reminderFrequency = defaults.double(forKey: "reminderFrequency")
        
        // Set default values if not previously set
        if self.minThreshold == 0 {
            self.minThreshold = 20 // Default minimum threshold
        }
        if self.maxThreshold == 0 {
            self.maxThreshold = 80 // Default maximum threshold
        }
        if self.reminderFrequency == 0 {
            self.reminderFrequency = 5 // Default reminder frequency (minutes)
        }
    }
    
    func saveSettings() {
        defaults.set(minThreshold, forKey: "minThreshold")
        defaults.set(maxThreshold, forKey: "maxThreshold")
        defaults.set(reminderFrequency, forKey: "reminderFrequency")
        self.batteryLevelDidChange()
    }
    
    func startMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }
    
    func isLaptopCharging() -> Bool {
        if let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() as? [[String: Any]] {
            for source in powerSourcesInfo {
                if source[kIOPSIsPresentKey] as? Bool == true {
                    if let currentType = source[kIOPSTypeKey] as? String,
                       currentType == kIOPSInternalBatteryType {
                        if let isCharging = source[kIOPSIsChargingKey] as? Bool {
                            print("is Charging \(isCharging)")
                            return isCharging
                        }
                    }
                }
            }
        }
        print("is NOT Charging")
        return false
    }
    
    @objc func batteryLevelDidChange() {
        let currentLevel = getCurrentBatteryLevel()
        print("currentLevel: \(currentLevel)")
        let notificationIdentifier = "BatteryReminder"
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        
        if currentLevel < Int(minThreshold) && !isLaptopCharging() {
            ReminderNotification.scheduleNotification(title: "Low Battery \(currentLevel)%!", body: "Please plug in your charger.", frequency: TimeInterval(reminderFrequency * 60), identifier: notificationIdentifier)
        } else if currentLevel > Int(maxThreshold) && isLaptopCharging() {
            ReminderNotification.scheduleNotification(title: "High Battery \(currentLevel)%!", body: "Please unplug your charger.", frequency: TimeInterval(reminderFrequency * 60), identifier: notificationIdentifier)
        }
    }
    
    private func getCurrentBatteryLevel() -> Int {
        if let batteryInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() as? [[String: Any]] {
            for source in batteryInfo {
                if source[kIOPSIsPresentKey] as? Bool == true {
                    if let currentCapacity = source[kIOPSCurrentCapacityKey] as? Int,
                       let maxCapacity = source[kIOPSMaxCapacityKey] as? Int {
                        return (currentCapacity * 100) / maxCapacity
                    }
                }
            }
        }
        return 0
    }
}

struct ReminderNotification {
    static func scheduleNotification(title: String, body: String, frequency: TimeInterval, identifier: String) {
        print("Sending notification")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: frequency, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
