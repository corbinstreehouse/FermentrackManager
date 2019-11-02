//
//  main.swift
//  com.redwoodmonkey.installer
//
//  Created by Corbin Dunn on 11/1/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

let serviceDelegate = InstallServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = serviceDelegate
listener.resume()


