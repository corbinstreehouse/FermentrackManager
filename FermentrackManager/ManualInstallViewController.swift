//
//  ManualInstallViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class ManualInstallViewController: StatusViewController {
    
    private func runInInstaller(code: (_ installer: FermentrackInstaller) throws -> Void) {
        let installer = FermentrackInstaller()
        do {
            try code(installer)
        } catch {
            // show the exceptiopn message
            NSApp.presentError(error, modalFor: self.view.window!, delegate: nil, didPresent: nil, contextInfo: nil)
        }
    }
    
    @IBAction func btnInstallRedisClicked(_ sender: NSButton) {
        runInInstaller { (installer) in
            try installer.installRedis()
        }
    }
    
    @IBAction func btnInstallLaunchDaemonClicked(_ sender: NSButton) {
        runInInstaller { (installer) in
            appDelegate.stopWebServer()
            
            try installer.installDaemon()
            // Reload after
            appDelegate.startServerConnection()
        }
    }

    @objc dynamic var processManagerStatus: NSAttributedString {
        get {
            if appDelegate.isProcessManagerInstalled {
                return NSAttributedString(string: "Installed", attributes: [NSAttributedString.Key.foregroundColor: NSColor.systemGreen])
            } else {
                return NSAttributedString(string: "Not installed", attributes: [NSAttributedString.Key.foregroundColor: NSColor.systemRed])
            }
        }
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "processManagerStatus" {
            return ["appDelegate.isProcessManagerInstalled"]
        } else {
            return super.keyPathsForValuesAffectingValue(forKey: key)
        }
    }
    
    @IBAction func btnChangeHomeDirectoryClicked(_ sender: NSButton) {
        let openPanel = NSOpenPanel.init()
        openPanel.directoryURL = appDelegate.fermentrackHomeURL
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.begin { (response) in
            if response == .OK {
                self.appDelegate.fermentrackHomeURL = openPanel.url!
            }
        }
    }
    
    @IBAction func btnBackClicked(_ button: NSButton) {
        if appDelegate.isProcessManagerSetup {
            mainViewController.loadStatusViewController(backwards: true)
        } else {
            mainViewController.loadWelcomeViewController(backwards: true)
        }
    }
}
