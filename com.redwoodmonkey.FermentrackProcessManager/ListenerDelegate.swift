//
//  ListenerDelegate.swift
//  com.redwoodmonkey.FermentrackProcessManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    
    var processManager: FermentrackProcessManager!
    
    init(_ processManager: FermentrackProcessManager) {
        self.processManager = processManager
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        // Create a new instance to service this connection
        let manager = ExportedProcessManager(processManager, connection: newConnection)
        
        newConnection.exportedInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        newConnection.exportedObject = manager
        newConnection.remoteObjectInterface = NSXPCInterface(with: FermentrackProcessManagerClientProtocol.self);
        
        newConnection.resume()
        
        return true
    }
}

class ExportedProcessManager: LocalProcessManagerClient, FermentrackProcessManagerProtocol  {
    
    var processManager: FermentrackProcessManager!
    var connection: NSXPCConnection!
    
    init(_ processManager: FermentrackProcessManager, connection: NSXPCConnection) {
        super.init()
        self.processManager = processManager
        self.connection = connection
        self.processManager.addClient(self)
        self.connection.invalidationHandler = {
            self.processManager.removeClient(self)
            self.processManager = nil
            self.connection.invalidationHandler = nil
            self.connection = nil
        }
    }
    
    private var remoteClient: FermentrackProcessManagerClientProtocol? {
        get {
            return self.connection.remoteObjectProxy as? FermentrackProcessManagerClientProtocol
        }
    }
    
    override func webServerRunningChanged(_ newValue: Bool) {
        self.remoteClient?.webServerRunningChanged(newValue)
    }
    
    override func handleError(_ error: Error) {
        self.remoteClient?.handleError(error)
    }
    
    func setShouldReloadOnChanges(_ value: Bool) {
        processManager.shouldReloadOnChanges = value
    }
    
    func load(withReply reply: @escaping (_ isSetup: Bool, _ fermentrackHomeURL: URL?, _ webServerIsRunning: Bool, _ shouldReloadOnChanges: Bool) -> Void) {
        // Really just to kick the tires and see if the service is running
        reply(processManager.isSetupComplete, processManager.fermentrackHomeURL, processManager.isWebServerRunning, processManager.shouldReloadOnChanges)
    }
    
    func setFermentrackHomeURL(_ url: URL, userName: String) {
        processManager.setFermentrackHomeURL(url: url, userName: userName)
    }
    
    func markSetupComplete(isSetupComplete: Bool, withReply reply: @escaping () -> Void) {
        processManager.mark(isSetupComplete: isSetupComplete)
        reply()
    }

//    func getFermentrackHomeURL(withReply reply: @escaping (URL?) -> Void) {
//        reply(self.processManager.getFermentrackHomeURL())
//    }
    
    func isWebServerRunning(withReply reply: @escaping (Bool) -> Void) {
        reply(processManager.isWebServerRunning)
    }
    
    func stopWebServer() {
        processManager.stopWebServer()
    }
    
    func startWebServer() {
        processManager.startWebServer()
    }
    
}
