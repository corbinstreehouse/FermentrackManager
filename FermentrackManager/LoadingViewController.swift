//
//  LoadingViewController.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/2/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

class LoadingViewController: NSViewController {

    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewWillAppear() {
        progressIndicator.startAnimation(nil)
    }
    
}
