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
    
    @objc dynamic var isInstalling = false
    @objc dynamic var didSuccessfulInstall = false

    private func startInstall() {
        isInstalling = true
        let fermentrackHomeURL = AppDelegate.shared.fermentrackHomeURL!
        let fermentrackRepoURL = AppDelegate.shared.fermentrackRepoURL

        let installer = FermentrackInstaller(installURL: fermentrackHomeURL, repoURL: fermentrackRepoURL, statusHandler: { (s: NSAttributedString) in
            self.statusTextView.textStorage?.append(s)
            self.statusTextView.scrollToEndOfDocument(nil)
        })
        didSuccessfulInstall = installer.doFullAutomatedInstall()
        isInstalling = false
        
        if didSuccessfulInstall {
            // Open the URL to show the user if it worked..
            
        }
    }
    
    override func viewWillAppear() {
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
