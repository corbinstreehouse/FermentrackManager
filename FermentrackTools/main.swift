//
//  main.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/26/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

// TODO: How do I want to get the locations into here? User defaults?
let defaultFermentrackBasePathKeyName = "FermentrackBasePath"
UserDefaults.standard.register(defaults: [defaultFermentrackBasePathKeyName : "/Users/corbin/Projects/Fermentrack"])
let fermentrackHomePath = UserDefaults.standard.string(forKey: defaultFermentrackBasePathKeyName)!
let fermentrackHomeURL = URL(fileURLWithPath: fermentrackHomePath)

let fermentrackManager = FermentrackManager(fermentrackHomeURL)

while (true) {
    fermentrackManager.run()
    Thread.sleep(forTimeInterval: 1.0)
}

