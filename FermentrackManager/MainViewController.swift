//
//  MainViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa
//import FermentrackProcessManagerProtocol

public class MainViewController: NSViewController {
    
    @IBOutlet var containerView: NSView!
        
    public override func viewDidLoad() {
        appDelegate.mainViewController = self
    }
    
    func handleProcessManagerNotLoaded() {
        loadWelcomeViewController()
    }
    
    func handleProcessManagerIsLoaded() {
        loadContentViewController(identifier: StatusViewController.storyboardSceneID)
    }
          
    public func loadContentViewController(identifier: NSStoryboard.SceneIdentifier, backwards: Bool = false) {
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
//            viewController.view.layer?.backgroundColor = NSColor.red.cgColor
        }
    }
    
    private func loadWelcomeViewController() {
        loadContentViewController(identifier: WelcomeViewController.storyboardSceneID)
    }
    
    private func loadManageViewController() {
        loadContentViewController(identifier: ManualInstallViewController.storyboardSceneID)
    }
    
}

extension NSViewController {
    public var mainViewController: MainViewController {
        let mvc = self.parent as! MainViewController
        return mvc
    }

}
