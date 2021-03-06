//
//  main.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/26/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

let fermentrackManager = FermentrackProcessManager()

// The main thread here will kick off the XPC service and block on resume
let serviceDelegate = ListenerDelegate(fermentrackManager)
let listener = NSXPCListener(machServiceName: "com.redwoodmonkey.FermentrackProcessManager")
listener.delegate = serviceDelegate
listener.resume()
dispatchMain()


