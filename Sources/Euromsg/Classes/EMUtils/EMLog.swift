//
//  EMLog.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 28.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import os.log

class EMLog {

    /// shared instance
    static var shared = EMLog()

    private init() {}

    /// is Logging enable
    static var isEnabled: Bool = true

    /// Log for success. Will add 🟢 emoji to see better
    ///
    /// - Parameter message: Logging message
    static func success(_ message: Any!) {
        EMLog.shared.debug(type: "🟢", message: message)
    }

    /// Log for success. Will add 🔵 emoji to see better
    ///
    /// - Parameter message: Logging message
    static func info(_ message: Any) {
        EMLog.shared.debug(type: "🔵", message: message)
    }

    /// Log for warning. Will add ⚠️ emoji to see better
    ///
    /// - Parameter message: Logging message
    static func warning(_ message: Any) {
        EMLog.shared.debug(type: "⚠️", message: message)
    }

    /// Log for error. Will add 🔴 emoji to see better
    ///
    /// - Parameter message: Logging message
    static func error(_ message: Any) {
        EMLog.shared.debug(type: "🔴", message: message)
    }

    private func debug(type: Any?, message: Any?) {
        guard EMLog.isEnabled else { return }
        DispatchQueue.main.async {
            os_log("%@", type: .debug, "\(type ?? "") -> \(message ?? "")")
        }
    }

}
