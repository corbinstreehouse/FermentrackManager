//
//  NSViewController+Extensions.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/6/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

extension NSViewController {

    public static var storyboardSceneID: NSStoryboard.SceneIdentifier {
        return String(className().split(separator: ".").last!)
    }

}
