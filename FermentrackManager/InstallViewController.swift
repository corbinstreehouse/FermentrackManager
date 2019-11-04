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
    
    private var installer: FermentrackInstaller?
    
    
    private func startInstall() {
        let installURL = AppDelegate.shared.fermentrackInstallDirURL
        let fermentrackRepoURL = AppDelegate.shared.fermentrackRepoURL

        installer = FermentrackInstaller(installURL: installURL, repoURL: fermentrackRepoURL, statusHandler: { (s: NSAttributedString) in
            self.statusTextView.textStorage?.append(s)
            self.statusTextView.scrollToEndOfDocument(nil)
        })
        installer!.startFullAutomatedInstall()
    }
    
    override func viewWillAppear() {
        if installer == nil {
            DispatchQueue.main.async {
                self.startInstall()
            }
        }
    }
    
}
