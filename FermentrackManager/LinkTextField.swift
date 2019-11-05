//
//  LinkTextField.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 11/4/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Cocoa

// not using this...
class LinkTextFieldCell: NSTextFieldCell {
    
    // AppKit really needs a better way of customizing NSTextField that doesn't involve private hackery.
//    override func _textAttributes() -> [AnyHashable : Any] {
//        var r = super._textAttributes()
//        r[NSAttributedString.Key.foregroundColor] = NSColor.linkColor
//        return r
//    }
}

class LinkTextField: NSTextField {

    @objc public var targetURLString: String? // If nil, use the value in the thing

    override func resetCursorRects() {
        discardCursorRects()
        // This is too big...need to fix for the cell size...
//        addCursorRect(self.bounds, cursor: NSCursor.pointingHand)
    }
    
    fileprivate func resolvedTargetURL() -> URL? {
        if let s = targetURLString {
            if let u = URL(string: s) {
                return u
            }
        }
        if stringValue.count > 0 {
            return URL(string: stringValue)
        }
        return nil
    }

    override func mouseUp(with event: NSEvent) {
        // If we hit in the text area open the URL
        let hit = cell!.hitTest(for: event, in: self.bounds, of: self)
        if hit == .contentArea {
            if let url = resolvedTargetURL() {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
}
