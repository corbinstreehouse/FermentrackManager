//
//  ServiceDelegate.swift
//  com.redwoodmonkey.FermentrackProcessManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class ServiceDelegate: NSObject, NSXPCListenerDelegate, FermentrackProcessManagerProtocol {

    var processManager: FermentrackProcessManager!
    
    init(_ processManager: FermentrackProcessManager) {
        self.processManager = processManager
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        newConnection.exportedInterface = NSXPCInterface(with: FermentrackProcessManagerProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        
        return true
    }
    
    func load(withReply reply: @escaping (_ fermentrackHomeURL: URL?) -> Void) {
        // Really just to kick the tires and see if the service is running
        reply(processManager.getFermentrackHomeURL())
    }
    
    func setFermentrackHomeURL(_ url: URL) {
        self.processManager.setFermentrackHomeURL(url: url)
    }

    func getFermentrackHomeURL(withReply reply: @escaping (URL?) -> Void) {
        reply(self.processManager.getFermentrackHomeURL())
    }

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
