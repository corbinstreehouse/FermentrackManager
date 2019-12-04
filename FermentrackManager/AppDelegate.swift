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

let useLocalManager = false // for debugging set to true
let repoDefaultAbsolutePath = "https://github.com/corbinstreehouse/fermentrack.git"

// Kind of also my model for now
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, FermentrackProcessManagerClientProtocol {
    func handleError(_ error: Error) {
        RunLoop.main.perform(inModes: [.default, .modalPanel], block: {
            print("Server error:" + error.localizedDescription)
        })
    }

    public var fermentrackRepoURL: URL = URL(string: repoDefaultAbsolutePath)!

    @objc dynamic var isProcessManagerInstalled = false
    
    weak var mainViewController: MainViewController!
    
    private var ignoreProcessManager = false
    @objc dynamic public var fermentrackHomeURL: URL? {
        didSet {
            if (!ignoreProcessManager && isProcessManagerInstalled && fermentrackHomeURL != nil) {
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
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isInstalling {
            return .terminateCancel
        } else {
            return .terminateNow
        }
    }
    
    public func startServerConnection() {
        if let oldConnection = serverConnection {
            oldConnection.invalidate()
            processManager = nil
        }
        serverConnection = NSXPCConnection(machServiceName: "com.redwoodmonkey.FermentrackProcessManager", options:useLocalManager ? [] : [.privileged])
        serverConnection!.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        serverConnection!.exportedInterface = NSXPCInterface(with: FermentrackProcessManagerClientProtocol.self)
        serverConnection!.exportedObject = self
        serverConnection!.resume()
        requestLoad()
    }
    
    func webServerRunningChanged(_ newValue: Bool) {
        RunLoop.main.perform(inModes: [.default, .modalPanel], block: {
            self.isWebServerRunning = newValue
        })
    }
    
    private func handleProcessManagerNotLoaded() {
        isProcessManagerInstalled = false
        mainViewController.handleProcessManagerNotLoaded()
    }
    
    func startWebServer(withReply reply: @escaping () -> Void) {
        processManager?.startWebServer(withReply: reply)
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

    var isInstalling = false {
        didSet {
            if oldValue != isInstalling {
                if isInstalling {
                    ProcessInfo.processInfo.disableSuddenTermination()
                } else {
                    ProcessInfo.processInfo.enableSuddenTermination()
                }
            }
        }
    }
    
    @objc dynamic var isProcessManagerSetup: Bool = false {
        didSet {
            if !ignoreProcessManager {
                if self.isProcessManagerSetup && fermentrackHomeURL != nil {
                    // Also, re-send our URL, in case it wasn't ever sent..
                    processManager?.setFermentrackHomeURL(fermentrackHomeURL!, userName: NSUserName())
                }
                
                self.processManager?.markSetupComplete(isSetupComplete: isProcessManagerSetup) {
                    // done!
                    print("mark complete DONE")
                }
            }
        }
    }
    
    private func handleProcessManagerLoaded(isSetup: Bool, fermentrackHomeURL: URL?, isWebServerRunning: Bool, shouldReloadOnChanges: Bool) {
        ignoreProcessManager = true
        
        isProcessManagerInstalled = true
        self.isWebServerRunning = isWebServerRunning
        self.shouldReloadOnChanges = shouldReloadOnChanges
        self.fermentrackHomeURL = fermentrackHomeURL ?? self.defaultFermentrackInstallDir()
        if isInstalling {
            // if we are doing an install, make sure it isn't setup, otherwise we try to start loading things constantly
            self.isProcessManagerSetup = false
            if isSetup {
                self.processManager?.markSetupComplete(isSetupComplete: false)  {
                }
            }
        } else {
            self.isProcessManagerSetup = isSetup
        }
        
        ignoreProcessManager = false
        mainViewController.handleProcessManagerIsLoaded()
    }

    private func requestLoad() {
        processManager = serverConnection!.remoteObjectProxyWithErrorHandler { error in
            // This means the service isn't installed yet, so we go to the setup panel
            RunLoop.main.perform(inModes: [.default, .modalPanel], block: {
                self.handleProcessManagerNotLoaded()
            })
            print("Mach service probably not installed, received error:", error)
        } as? FermentrackProcessManagerProtocol

        if let processManager = processManager {
            processManager.load(withReply: { (isSetup: Bool, fermentrackHomeURL: URL?, isWebServerRunning: Bool, shouldReloadOnChanges: Bool) in
                // ah gawd, this (DispatchQueue.main.async) causes me grief when doing my 0wn runloop stuff
                // it was called after my run of process events...messing up the setup..
                RunLoop.main.perform(inModes: [.default, .modalPanel], block: {
                    self.handleProcessManagerLoaded(isSetup: isSetup, fermentrackHomeURL: fermentrackHomeURL, isWebServerRunning: isWebServerRunning, shouldReloadOnChanges: shouldReloadOnChanges)
                })
            })
        } else {
            self.handleProcessManagerNotLoaded()
        }
    }

}

