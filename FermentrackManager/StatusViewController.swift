//
//  StatusViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {
    
    class var storyboardSceneID: NSStoryboard.SceneIdentifier {
        get {
            return "StatusViewController"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
        
    override func viewWillAppear() {
    }
    
    override func viewDidDisappear() {
    }
    
    @IBAction func btnManualInstallClicked(_ button: NSButton) {
        mainViewController.loadContentViewController(identifier: ManualInstallViewController.storyboardSceneID)
    }
    
    @IBAction func btStatusClicked(_ button: NSButton) {
        mainViewController.loadContentViewController(identifier: StatusViewController.storyboardSceneID, backwards: true)
    }
    
    @objc dynamic var appDelegate: AppDelegate {
        get {
            return AppDelegate.shared
        }
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "webServerStatus" {
            return ["appDelegate.isWebServerRunning"]
        } else {
            return super.keyPathsForValuesAffectingValue(forKey: key)
        }
    }
    
    @objc dynamic var webServerStatus: NSAttributedString {
        get {
            if AppDelegate.shared.isWebServerRunning {
                return NSAttributedString(string: "Running", attributes: [NSAttributedString.Key.foregroundColor : NSColor.systemGreen])
            } else {
                return NSAttributedString(string: "Stopped", attributes: [NSAttributedString.Key.foregroundColor : NSColor.systemRed])
            }
        }
    }
}
