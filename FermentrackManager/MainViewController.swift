//
//  MainViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

public class MainViewController: NSViewController {
    
    @IBOutlet var containerView: NSView!
        
    public override func viewDidLoad() {
        // I hate back pointers, but we need someway to communicate here
        appDelegate.mainViewController = self
    }
    
    func handleProcessManagerNotLoaded() {
        if !appDelegate.isInstalling {
            loadWelcomeViewController()
        }
    }
    
    func handleProcessManagerIsLoaded() {
        // Don't do anything if we are on the manual setup view controller or installing.
        if appDelegate.isInstalling || self.children.first as? ManualInstallViewController? != nil {
            return
        }
        if !appDelegate.isProcessManagerSetup {
            loadWelcomeViewController()
        } else {
            loadStatusViewController()
        }
    }
          
    fileprivate func loadContentViewController(identifier: NSStoryboard.SceneIdentifier, backwards: Bool = false) {
        let viewController = NSStoryboard.main!.instantiateController(withIdentifier: identifier) as! NSViewController
        let oldChildViewController = self.children.first!
        self.addChild(viewController)
        
        // stupid work arounds for autolayout issues
        viewController.view.frame = oldChildViewController.view.frame
        viewController.view.layoutSubtreeIfNeeded()
        
        viewController.view.translatesAutoresizingMaskIntoConstraints = true
        viewController.view.autoresizingMask = [.width, .height]
        
        self.transition(from: oldChildViewController, to: viewController, options: backwards ? [.slideRight] : [.slideLeft]) {
            oldChildViewController.removeFromParent()
        }
    }
    
    func loadWelcomeViewController(backwards: Bool = false) {
        loadContentViewController(identifier: WelcomeViewController.storyboardSceneID, backwards: backwards)
    }
    
    func loadStatusViewController(backwards: Bool = false) {
        loadContentViewController(identifier: StatusViewController.storyboardSceneID, backwards: backwards)
    }
    
    func loadInstallViewController() {
        loadContentViewController(identifier: InstallViewController.sceneID)
    }
    
    func loadManualInstallViewController() {
        loadContentViewController(identifier: ManualInstallViewController.storyboardSceneID)
    }
}

extension NSViewController {
    
    // Only good for first level children
    public var mainViewController: MainViewController {
        let mvc = self.parent as! MainViewController
        return mvc
    }

}
