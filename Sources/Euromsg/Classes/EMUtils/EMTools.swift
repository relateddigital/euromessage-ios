//
//  EMTools.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import UIKit

internal class EMTools {

    static let userDefaults = UserDefaults(suiteName: EMKey.userDefaultSuiteKey)
    static func validatePhone(phone: String?) -> Bool {
        guard phone != nil else {
            return false
        }
        return (phone!.count > 9)
    }

    private static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
    static func validateEmail(email: String?) -> Bool {
        guard email != nil else {
            return false
        }
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return (emailTest.evaluate(with: email!))
    }

    static func retrieveUserDefaults(userKey: String) -> AnyObject? {
        guard let value = userDefaults?.object(forKey: userKey) else {
            return nil
        }
        return value as AnyObject?
    }

    static func removeUserDefaults(userKey: String) {
        if userDefaults?.object(forKey: userKey) != nil {
            userDefaults?.removeObject(forKey: userKey)
            userDefaults?.synchronize()
        }
    }

    static func saveUserDefaults(key: String?, value: AnyObject?) {
        guard key != nil && value != nil else {
            return
        }
        userDefaults?.set(value, forKey: key!)
        userDefaults?.synchronize()
    }

    static func getInfoString(key: String) -> String? {
        let bundle = Bundle.init(for: self)
        return bundle.infoDictionary?[key] as? String
    }
    
    //TODO: dökümana appgroup kısmı eklenmeli, NotificationService, NotificationContent
    //TODO: dökümana developer.apple.com appgroup identifier tanımı eklenmeli
    //TODO: UserDefaults'taki suiteName kısmı dinamik olmalı
    static func getIdentifierForVendorString() -> String {
        let emptyUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        if let identifierForVendorString = retrieveUserDefaults(userKey: EMKey.identifierForVendorKey) as? String, let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            EMKeychain.set(identifierForVendorString, forKey: EMKey.identifierForVendorKey)
            return identifierForVendorString
        } else if let identifierForVendorString = EMKeychain.get(EMKey.identifierForVendorKey), let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            saveUserDefaults(key: EMKey.identifierForVendorKey, value: identifierForVendorString as AnyObject)
            return identifierForVendorString
        } else if let identifierForVendorString = UIDevice.current.identifierForVendor?.uuidString, let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            saveUserDefaults(key: EMKey.identifierForVendorKey, value: identifierForVendorString as AnyObject)
            EMKeychain.set(identifierForVendorString, forKey: EMKey.identifierForVendorKey)
            return identifierForVendorString
        }
        return ""
    }
}
