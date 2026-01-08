// LifeOpsWatchApp.swift
// Apple Watch app entry point

import SwiftUI

@main
struct LifeOpsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTimelineView()
        }
    }
}
