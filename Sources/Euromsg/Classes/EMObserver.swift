//
//  EMObserver.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 1.06.2021.
//

import Foundation
import UIKit

class EMObserver {

    static let ncd = NotificationCenter.default
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(EMObserver.ncd.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
        observers.append(EMObserver.ncd.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
        observers.append(EMObserver.ncd.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
    }

    deinit {
        EMObserver.ncd.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        EMObserver.ncd.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        EMObserver.ncd.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

}
