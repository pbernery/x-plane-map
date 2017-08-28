//
//  Logger.swift
//  XPlaneMap
//
//  Created by Philippe Bernery on 28/08/2017.
//  Copyright © 2017 Philippe Bernery. All rights reserved.
//

import Foundation

enum LogLevel: Int {
    case debug = 0
    case error = 1
    case warning = 2
    case info = 3
}

struct Logger {
    static let logLevel = LogLevel.debug

    static func log(level: LogLevel = .info, message: String) {
        #if Debug
        if level >= logLevel {
            print(message)
        }
        #endif
    }
}
