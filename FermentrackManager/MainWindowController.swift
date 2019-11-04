//
//  MainWindowController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/29/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

    override func windowDidLoad() {
        super.windowDidLoad()
        window!.isMovableByWindowBackground = true
        window!.autorecalculatesKeyViewLoop = true
    }

}
