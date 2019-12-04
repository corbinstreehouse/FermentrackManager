//
//  StatusViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    @IBAction func btnManualInstallClicked(_ button: NSButton) {
        mainViewController.loadManualInstallViewController()
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
    
    @IBAction @objc func btnStartOrStopWebServerClicked(_ button: NSButton) {
        if button.tag == 0 {
            appDelegate.stopWebServer()
        } else {
            appDelegate.startWebServer() {
                
            }
        }
        
    }
    
}
