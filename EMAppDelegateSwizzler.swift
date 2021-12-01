//
//  EMAppDelegateSwizzler.swift
//  Euromsg
//
//  Created by Egemen Gülkılık on 29.11.2021.
//

import Foundation
import UIKit
import UserNotifications

protocol EMAppDelegateSwizzlerDelegate: AnyObject {
    func didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data)
}

class EMAppDelegateSwizzler {
    
    private static let shared = EMAppDelegateSwizzler()
    private weak var delegate: EMAppDelegateSwizzlerDelegate?
    
}
