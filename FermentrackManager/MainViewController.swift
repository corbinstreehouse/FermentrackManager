//
//  MainViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa
//import FermentrackProcessManagerProtocol

class MainViewController: NSViewController {
    
    private var serverConnection: NSXPCConnection?
    private var processManager: FermentrackProcessManagerProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Figure out which view we should show
        // If the XPC service is installed and running, then we are installed and good to go!
        // Otherwise, we aren't..
        
        startServerConnection()
        requestLoad()
    }
    
    private func startServerConnection() {
        serverConnection = NSXPCConnection(serviceName: "com.redwoodmonkey.FermentrackProcessManager")
        
        serverConnection!.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        serverConnection!.resume()
    }

    private var isLoaded = false
    private var fermentrackHomeURL: URL?
    @IBOutlet var containerView: NSView!
    
    private func requestLoad() {
        isLoaded = false
        processManager = serverConnection!.remoteObjectProxyWithErrorHandler { error in
            // This means the service isn't installed yet, so we go to the setup panel
            DispatchQueue.main.async {
                self.handleProcessManagerNotLoaded()
            }
            //print("Received error:", error)
        } as? FermentrackProcessManagerProtocol

        if let processManager = processManager {
            processManager.load(withReply: { (fermentrackHomeURL: URL?) in
                DispatchQueue.main.async {
                    self.handleProcessManagerLoaded(fermentrackHomeURL)
                }
            })
        } else {
            self.handleProcessManagerNotLoaded()
        }
    }
    
    private func handleProcessManagerNotLoaded() {
        self.loadWelcomeViewController()

    }
    
    private func handleProcessManagerLoaded(_ fermentrackHomeURL: URL?) {
        self.isLoaded = true
        // If we get a reply then we are loaded..
        self.fermentrackHomeURL = fermentrackHomeURL
        self.loadManageViewController()
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
