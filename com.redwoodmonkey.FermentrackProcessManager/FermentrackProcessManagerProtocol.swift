//
//  FermentrackProcessManagerProtocol.swift
//  com.redwoodmonkey.FermentrackProcessManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

@objc public protocol FermentrackProcessManagerProtocol {
    func load(withReply reply: @escaping (_ fermentrackHomeURL: URL?, _ isWebServerRunning: Bool) -> Void)
    func setFermentrackHomeURL(_ url: URL)
    func getFermentrackHomeURL(withReply reply: @escaping (URL?) -> Void)
    func isWebServerRunning(withReply reply: @escaping (Bool) -> Void)
    func stopWebServer()
    func startWebServer()
}
