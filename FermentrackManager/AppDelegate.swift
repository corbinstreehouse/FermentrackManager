//
//  AppDelegate.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/28/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

enum ServerStatus {
    case checking
    case installed
    case notInstalled
}

protocol ServerObserver {
    func didChangeStatus(_ newStatus: ServerStatus)
    func didChangeFermentrackInstallDirURL(_ url: URL)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // TODO: an option on what repo to start with using mine for now
    public var fermentrackRepoURL: URL = URL(string: "https://github.com/corbinstreehouse/fermentrack.git")!

    public var serverStatus: ServerStatus = .checking {
        didSet {
            observer?.didChangeStatus(serverStatus)
        }
    }
    
    public var observer: ServerObserver?

    private var _fermentrackInstallDirURL: URL
    public var fermentrackInstallDirURL: URL {
        get {
            return _fermentrackInstallDirURL
        }
        set(newValue) {
            if _fermentrackInstallDirURL != newValue {
                processManager?.setFermentrackHomeURL(newValue)
                observer?.didChangeFermentrackInstallDirURL(newValue)
            }
        }
    }

    public static var shared: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    private var serverConnection: NSXPCConnection?
    private var processManager: FermentrackProcessManagerProtocol?
    
    
    override init() {
        // default install location
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        _fermentrackInstallDirURL = appSupportDir.appendingPathComponent("Fermentrack")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startServerConnection()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func startServerConnection() {
        if let oldConnection = serverConnection {
            oldConnection.invalidate()
        }
        serverConnection = NSXPCConnection(machServiceName: "com.redwoodmonkey.FermentrackProcessManager", options:[.privileged])
        
//        serverConnection?.invalidationHandler = {
//            self.handleProcessManagerNotLoaded()
//        }
        
        serverConnection!.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        serverConnection!.resume()
        requestLoad()
    }
    
    private func handleProcessManagerNotLoaded() {
        serverStatus = .notInstalled
    }
    
    private func handleProcessManagerLoaded(fermentrackHomeURL: URL?) {
        if let u = fermentrackHomeURL {
            _fermentrackInstallDirURL = u
        }
        serverStatus = .installed
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
            processManager.load(withReply: { (fermentrackHomeURL: URL?) in
                DispatchQueue.main.async {
                    self.handleProcessManagerLoaded(fermentrackHomeURL: fermentrackHomeURL)
                }
            })
        } else {
            self.handleProcessManagerNotLoaded()
        }
    }

}

