//
//  MainViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa
//import FermentrackProcessManagerProtocol

class MainViewController: NSViewController, ServerObserver {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        AppDelegate.shared.observer = self
    }
    
    @IBOutlet var containerView: NSView!
        
    private func handleProcessManagerNotLoaded() {
        self.loadWelcomeViewController()
    }
    
    func didChangeStatus(_ newStatus: ServerStatus) {
        switch newStatus {
        case .installed:
            loadContentViewController(identifier: StatusViewController.storyboardSceneID)
        case .notInstalled:
            loadContentViewController(identifier: WelcomeViewController.storyboardSceneID)
        case .checking:
                break;
        }
    }
    
    func didChangeFermentrackInstallDirURL(_ url: URL) {
        
    }
            
    public func loadContentViewController(identifier: NSStoryboard.SceneIdentifier) {
        let viewController = NSStoryboard.main!.instantiateController(withIdentifier: identifier) as! NSViewController
        let oldChildViewController = self.children.first!
        self.addChild(viewController)
        
        // stupid work arounds for autolayout issues
        viewController.view.frame = oldChildViewController.view.frame
        viewController.view.layoutSubtreeIfNeeded()
        
        viewController.view.translatesAutoresizingMaskIntoConstraints = true
        viewController.view.autoresizingMask = [.width, .height]
        
        self.transition(from: oldChildViewController, to: viewController, options: []) {
            oldChildViewController.removeFromParent()
//            viewController.view.layer?.backgroundColor = NSColor.red.cgColor
        }
    }
    
    private func loadWelcomeViewController() {
        loadContentViewController(identifier: WelcomeViewController.storyboardSceneID)
    }
    
    private func loadManageViewController() {
        
    }
    
}
//
