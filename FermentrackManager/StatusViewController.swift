//
//  StatusViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    static let storyboardSceneID: NSStoryboard.SceneIdentifier = "StatusViewController"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @objc dynamic var fermentrackHomePath: String {
        get {
            return AppDelegate.shared.fermentrackInstallDirURL.path
        }
        set (value) {
//            AppDelegate.shared.fermentrackInstallDirURL = URL(fileURLWithPath: value)
        }
    }

    
}
