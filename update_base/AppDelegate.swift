//
//  AppDelegate.swift
//  update_base
//
//  Created by rausNT.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createCustomMainMenu()
        updateWindowTitle()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func createCustomMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu(title: "Application")
        mainMenu.addItem(appMenuItem)
        
        let aboutMenuItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        appMenuItem.submenu?.addItem(aboutMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    
    func updateWindowTitle() {
        if let window = NSApplication.shared.windows.first {
            window.title = "Обновлятель баз Game Stick Lite 4k"
        }
    }
}






