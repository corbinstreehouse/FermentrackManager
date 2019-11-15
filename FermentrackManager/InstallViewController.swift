//
//  InstallViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class InstallViewController: NSViewController {
    
    static let sceneID: NSStoryboard.SceneIdentifier = "InstallViewController"
    @IBOutlet var statusTextView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @objc dynamic var isInstalling = false {
        didSet {
            appDelegate.isInstalling = isInstalling
        }
    }
    @objc dynamic var didSuccessfulInstall = false
    
    private func doInstall(withInstaller installer: FermentrackInstaller) {
        isInstalling = true
        didSuccessfulInstall = installer.doFullAutomatedInstall(withProcessManager: !appDelegate.isProcessManagerInstalled)
        isInstalling = false
        
        if didSuccessfulInstall {
            appDelegate.startWebServer()
            // maybe delay a second???..
            
            // Open the URL to show the user if it worked..
            NSWorkspace.shared.open(appDelegate.fermentrackHostURL)
        }
    }

    private func startInstall() {
        let fermentrackHomeURL = AppDelegate.shared.fermentrackHomeURL!
        let fermentrackRepoURL = AppDelegate.shared.fermentrackRepoURL

        let installer = FermentrackInstaller(installURL: fermentrackHomeURL, repoURL: fermentrackRepoURL, statusHandler: { (s: NSAttributedString) in
            let shouldScroll = self.statusTextView.visibleRect.maxY == self.statusTextView.bounds.maxY
            self.statusTextView.textStorage?.append(s)
            if shouldScroll {
                self.statusTextView.scrollToEndOfDocument(nil)
            }
        })

        if !installer.checkIfInstallDirectoryEmpty() {
            let a = NSAlert()
            a.messageText = "Install directory is not empty and the install will likely fail. Do you wish to continue?"
            a.addButton(withTitle: "Continue")
            a.addButton(withTitle: "Cancel")
            a.beginSheetModal(for: self.view.window!) { (modalResponse) in
                // Let the sheet close and do this on the next tick
                DispatchQueue.main.async {
                    if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
                        self.doInstall(withInstaller: installer)
                    } else {
                        self.mainViewController.loadWelcomeViewController(backwards: true)
                    }
                }
            }
        } else {
            doInstall(withInstaller: installer)
        }
    }
    
    override func viewDidAppear() {
        DispatchQueue.main.async {
            self.startInstall()
        }
    }
    
    @IBAction func backBtnClicked(_ sender: NSButton) {
        mainViewController.loadWelcomeViewController(backwards: true)
    }
    
    @IBAction func doneBtnClicked(_ sender: NSButton) {
        mainViewController.loadStatusViewController()
    }
}
