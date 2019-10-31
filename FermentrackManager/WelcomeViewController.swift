//
//  WelcomeViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class WelcomeViewController: NSViewController {
    public static let storyboardSceneID: NSStoryboard.SceneIdentifier = "WelcomeViewController"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    private var observerNote: NSObjectProtocol? = nil
    override func viewDidAppear() {
        super.viewDidAppear()
        weak var weakSelf   = self;

        observerNote = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: self.view.window, queue: nil) { (note) in
            weakSelf?.resetStatusChecksIfNeeded()
        }
        checkStatus()
    }
    
    override func viewDidDisappear() {
        if let o = observerNote {
            NotificationCenter.default.removeObserver(o)
            observerNote = nil
        }
    }
    
    private func resetStatusChecksIfNeeded() {
        // check again when we become key
        if pythonStatus == .notInstalled {
            pythonStatus = .notChecked
        }
        if xcodeStatus == .notInstalled {
            xcodeStatus = .notChecked
        }
        checkStatus()
    }
    
    @objc dynamic var pythonStatusMsg: String = "Checking..."
    @objc dynamic var pythonStatusColor: NSColor = NSColor.tertiaryLabelColor
    
    @objc dynamic var xcodeStatusMsg: String = "Checking..."
    @objc dynamic var xcodeStatusColor: NSColor = NSColor.tertiaryLabelColor
    
    @objc dynamic var installButtonEnabled: Bool {
        return xcodeStatus == .installed && pythonStatus == .installed
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "installButtonEnabled" {
            return ["xcodeStatusMsg", "pythonStatusMsg"]
        } else {
            return super.keyPathsForValuesAffectingValue(forKey: key)
        }
    }

    enum CheckStatus {
        case notChecked
        case notInstalled
        case installed
    }
    
    private func statusMsgAndColor(forStatus status: CheckStatus) -> (String, NSColor) {
        switch status {
        case .notChecked:
            return ("Checking...", NSColor.tertiaryLabelColor)
        case .notInstalled:
            return ("Not Installed!", NSColor.systemRed)
        case .installed:
            return ("Installed.", NSColor.systemGreen)
        }
    }
    
    private var pythonStatus: CheckStatus = .notChecked {
        didSet {
            (pythonStatusMsg, pythonStatusColor) = statusMsgAndColor(forStatus: pythonStatus)
        }
    }
    
    private var xcodeStatus: CheckStatus = .notChecked {
        didSet {
            (xcodeStatusMsg, xcodeStatusColor) = statusMsgAndColor(forStatus: pythonStatus)
        }
    }

    private func checkStatus() {
        checkPythonStatus()
        checkXcodeStatus()
    }
    
    private func checkPythonStatus() {
        if pythonStatus == .notChecked {
            if checkIfInstalled(processName: "python3") {
                pythonStatus = .installed
            } else {
                pythonStatus = .notInstalled
            }
        }
    }
    
    private func checkXcodeStatus() {
        if xcodeStatus == .notChecked {
            if checkIfInstalled(processName: "xcodebuild") {
                xcodeStatus = .installed
            } else {
                xcodeStatus = .notInstalled
            }
        }

    }
        
    func checkIfInstalled(processName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [processName]
        try! process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0 // 0 == success, 1 = not installed, not found by which.
        
    }
    
}
