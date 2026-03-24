//
//  SmartRemoteApp.swift
//  SmartRemoteApp
//
//  Created by Aditya Bhadang on 21/05/25.
//

import SwiftUI

@main
struct WizRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                let size = NSSize(width: 600, height: 450)
                window.setContentSize(size)
                window.center()
                let defaultTitle = "Philips Wiz"
        let title = ProcessInfo.processInfo.environment["APP_TITLE"] ?? defaultTitle
        window.title = title
                window.styleMask.insert(.resizable) // Optional — remove to lock size
            }
        }
    }
}
