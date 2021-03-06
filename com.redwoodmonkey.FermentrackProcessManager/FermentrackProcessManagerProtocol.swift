//
//  FermentrackProcessManagerProtocol.swift
//  com.redwoodmonkey.FermentrackProcessManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

@objc public protocol FermentrackProcessManagerProtocol {
    func load(withReply reply: @escaping (_ isSetup: Bool, _ fermentrackHomeURL: URL?, _ isWebServerRunning: Bool, _ shouldReloadOnChanges: Bool) -> Void)
    func markSetupComplete(isSetupComplete: Bool, withReply reply: @escaping () -> Void)
    func setFermentrackHomeURL(_ url: URL, userName: String)
    func isWebServerRunning(withReply reply: @escaping (Bool) -> Void)
    func setShouldReloadOnChanges(_ value: Bool)
    func stopWebServer()
    func startWebServer(withReply reply: @escaping () -> Void)
}

@objc public protocol FermentrackProcessManagerClientProtocol {
    func webServerRunningChanged(_ newValue: Bool)
    func handleError(_ error: Error)
}
