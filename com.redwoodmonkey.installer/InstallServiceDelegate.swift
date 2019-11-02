//
//  InstallServiceDelegate.swift
//  com.redwoodmonkey.installer
//
//  Created by Corbin Dunn on 11/1/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

class InstallServiceDelegate: NSObject, NSXPCListenerDelegate, InstallerProtocol {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        newConnection.exportedInterface = NSXPCInterface(with: InstallerProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        
        return true
    }

    func installAgent(agentPathURL: URL, agentPlistURL: URL, withReply reply: @escaping (Error?) -> Void) {
        
        do {
            let agentPlistDestURL = URL(fileURLWithPath: "/Library/LaunchDaemons").appendingPathComponent( agentPlistURL.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: agentPlistDestURL.path) {
                try FileManager.default.removeItem(at: agentPlistDestURL)
            }
            
            try FileManager.default.copyItem(at: agentPlistURL, to: agentPlistDestURL)
            
            let agentDestURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/").appendingPathComponent( agentPathURL.lastPathComponent)

            try FileManager.default.copyItem(at: agentPathURL, to: agentDestURL)

            reply(nil)
        } catch {
            reply(error)
        }
    }

    
}
