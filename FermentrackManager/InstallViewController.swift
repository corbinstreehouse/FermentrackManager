//
//  InstallViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class InstallViewController: NSViewController {
    
    static let installViewControllerID: NSStoryboard.SceneIdentifier = "InstallViewController"
    @IBOutlet var statusTextView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private var installer: FermentrackInstaller?
    
    
    private func startInstall() {
        // TODO: an option on where to install it...but does it matter?
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
        let installURL = appSupportDir.appendingPathComponent("Fermentrack")
        // TODO: an option on what repo to start with using mine for now
        let fermentrackRepoURL = URL(string: "https://github.com/corbinstreehouse/fermentrack.git")

        installer = FermentrackInstaller(installURL: installURL, repoURL: fermentrackRepoURL!, statusHandler: { (s: NSAttributedString) in
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
