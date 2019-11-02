//
//  InstallerProtocol.swift
//  com.redwoodmonkey.installer
//
//  Created by Corbin Dunn on 11/1/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

@objc public protocol InstallerProtocol {
    func installAgent(agentPathURL: URL, agentPlistURL: URL, withReply reply: @escaping (Error?) -> Void)
}
