//
//  AppDelegate.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/28/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

extension NSViewController {
    // for bindings
    @objc dynamic var appDelegate: AppDelegate {
        get {
            return AppDelegate.shared
        }
    }
}

// Kind of also my model for now
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, FermentrackProcessManagerClientProtocol {
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            print("Server error:" + error.localizedDescription)
        }
    }

    // TODO: an option on what repo to start with using mine for now
    public var fermentrackRepoURL: URL = URL(string: "https://github.com/corbinstreehouse/fermentrack.git")!

    @objc var isProcessManagerInstalled = false
    
    weak var mainViewController: MainViewController!
    
    private var ignoreProcessManager = false
    @objc dynamic public var fermentrackHomeURL: URL? {
        didSet {
            if (!ignoreProcessManager && fermentrackHomeURL != nil) {
                processManager?.setFermentrackHomeURL(fermentrackHomeURL!, userName: NSUserName())
            }
        }
    }
    
    @objc var fermentrackHostURL: URL {
        // Maybe make this a little more configuraable?
        if let host = Host.current().name {
            return URL(string: "http://\(host):8000")!
        } else {
            return URL(string: "http://localhost:8000")!
        }
    }
    
    public static var shared: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    private var serverConnection: NSXPCConnection?
    private var processManager: FermentrackProcessManagerProtocol?
    
    func defaultFermentrackInstallDir() -> URL {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportDir.appendingPathComponent("Fermentrack")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startServerConnection()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    public func startServerConnection() {
        if let oldConnection = serverConnection {
            oldConnection.invalidate()
        }
        serverConnection = NSXPCConnection(machServiceName: "com.redwoodmonkey.FermentrackProcessManager", options:[.privileged])
        serverConnection!.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        serverConnection!.exportedInterface = NSXPCInterface(with: FermentrackProcessManagerClientProtocol.self)
        serverConnection!.exportedObject = self
        serverConnection!.resume()
        requestLoad()
    }
    
    func webServerRunningChanged(_ newValue: Bool) {
        DispatchQueue.main.async {
            self.isWebServerRunning = newValue
        }
    }
    
    private func handleProcessManagerNotLoaded() {
        isProcessManagerInstalled = false
        mainViewController.handleProcessManagerNotLoaded()
    }
    
    func startWebServer() {
        processManager?.startWebServer()
    }
    
    func stopWebServer() {
        processManager?.stopWebServer()
    }
    
    @objc dynamic var isWebServerRunning: Bool = false
    @objc dynamic var shouldReloadOnChanges: Bool = true {
        didSet {
            if !ignoreProcessManager {
                processManager?.setShouldReloadOnChanges(shouldReloadOnChanges)
            }
        }
    }
    
    @objc dynamic var isProcessManagerSetup: Bool = false {
        didSet {
            if !ignoreProcessManager {
                self.processManager?.markSetupComplete(isSetupComplete: isProcessManagerSetup) {
                    // done!
                }
            }
        }
    }
    
    private func handleProcessManagerLoaded(isSetup: Bool, fermentrackHomeURL: URL?, isWebServerRunning: Bool, shouldReloadOnChanges: Bool) {
        ignoreProcessManager = true
        
        isProcessManagerInstalled = true
        self.isWebServerRunning = isWebServerRunning
        self.shouldReloadOnChanges = shouldReloadOnChanges
        self.fermentrackHomeURL = fermentrackHomeURL
        self.isProcessManagerSetup = isSetup
        
        ignoreProcessManager = false
        
        mainViewController.handleProcessManagerIsLoaded()
    }

    private func requestLoad() {
        processManager = serverConnection!.remoteObjectProxyWithErrorHandler { error in
            // This means the service isn't installed yet, so we go to the setup panel
            DispatchQueue.main.async {
                self.handleProcessManagerNotLoaded()
            }
            print("Mach service probably not installed, received error:", error)
        } as? FermentrackProcessManagerProtocol

        if let processManager = processManager {
            processManager.load(withReply: { (isSetup: Bool, fermentrackHomeURL: URL?, isWebServerRunning: Bool, shouldReloadOnChanges: Bool) in
                DispatchQueue.main.async {
                    self.handleProcessManagerLoaded(isSetup: isSetup, fermentrackHomeURL: fermentrackHomeURL, isWebServerRunning: isWebServerRunning, shouldReloadOnChanges: shouldReloadOnChanges)
                }
            })
        } else {
            self.handleProcessManagerNotLoaded()
        }
    }

}

