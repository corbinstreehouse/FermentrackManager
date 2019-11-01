//
//  CustomError.swift
//  FermentrackTools
//
//  Created by Corbin Dunn on 10/28/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation


public enum CustomError: Error {
    case withMessage(_: String)
}

extension CustomError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .withMessage(let message):
            return message
        }
    }
}
