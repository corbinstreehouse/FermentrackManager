//
//  StatusViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {
    
    @IBOutlet var appProxy: NSObjectController?

    class var storyboardSceneID: NSStoryboard.SceneIdentifier {
        get {
            return "StatusViewController"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
        
    override func viewWillAppear() {
        appProxy?.bind(NSBindingName.content, to: AppDelegate.shared, withKeyPath: "self", options: [:])
    }
    
    override func viewDidDisappear() {
        appProxy?.unbind(NSBindingName.content)
    }
    
    @objc dynamic public var fermentrackInstallDirURL: URL?

    @IBAction func btnManualInstallClicked(_ button: NSButton) {
        mainViewController.loadContentViewController(identifier: ManualInstallViewController.storyboardSceneID)
    }
    
    @IBAction func btStatusClicked(_ button: NSButton) {
        mainViewController.loadContentViewController(identifier: StatusViewController.storyboardSceneID, backwards: true)
    }
}
