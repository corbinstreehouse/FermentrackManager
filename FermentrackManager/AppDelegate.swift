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
}

// Kind of also my model for now
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
    private var ignoreProcessManager = false
    @objc dynamic public var fermentrackInstallDirURL: URL {
        didSet(newValue) {
            if (!ignoreProcessManager) {
                processManager?.setFermentrackHomeURL(newValue)
            }
            UserDefaults.standard.set(newValue, forKey: installLocationDefaultsKey)
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
    
    fileprivate let installLocationDefaultsKey = "FermentrackInstallationDirectory"
    
    override init() {
        if let lastInstallLocationURL = UserDefaults.standard.url(forKey: installLocationDefaultsKey) {
            fermentrackInstallDirURL = lastInstallLocationURL
        } else {
            // default install location
            let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            fermentrackInstallDirURL = appSupportDir.appendingPathComponent("Fermentrack")
        }
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

//        serverConnection = NSXPCConnection(machServiceName: "com.redwoodmonkey.FermentrackProcessManager", options:[])
        serverConnection!.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        serverConnection!.resume()
        requestLoad()
    }
    
    private func handleProcessManagerNotLoaded() {
        serverStatus = .notInstalled
    }
    
    @objc dynamic var isWebServerRunning: Bool = false
    
    private func handleProcessManagerLoaded(fermentrackHomeURL: URL?, isWebServerRunning: Bool) {
        if let u = fermentrackHomeURL {
                ignoreProcessManager = true
            fermentrackInstallDirURL = u
            ignoreProcessManager = false
        }
        serverStatus = .installed
        self.isWebServerRunning = isWebServerRunning
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
            processManager.load(withReply: { (fermentrackHomeURL: URL?, isWebServerRunning: Bool) in
                DispatchQueue.main.async {
                    self.handleProcessManagerLoaded(fermentrackHomeURL: fermentrackHomeURL, isWebServerRunning: isWebServerRunning)
                }
            })
        } else {
            self.handleProcessManagerNotLoaded()
        }
    }

}

