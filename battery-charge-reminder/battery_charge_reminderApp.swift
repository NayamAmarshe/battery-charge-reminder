//
//  battery_charge_reminderApp.swift
//  battery-charge-reminder
//
//  Created by Mayank Sharma on 15/02/24.
//

import SwiftUI

@main
struct battery_charge_reminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
    
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(BatteryMonitor.shared)
//        }
//    }
}
