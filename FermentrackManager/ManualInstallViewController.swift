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
    
    @IBAction func installRedisBtnClicked(_ sender: NSButton) {
        runInInstaller { (installer) in
            try installer.installRedis()
        }
    }
    
    @IBAction func installLauncDaemon(_ sender: NSButton) {
        runInInstaller { (installer) in
            try installer.installDaemon()
        }
    }

    @IBAction func changeHomeDirectory(_ sender: NSButton) {
        
    }
}
