//
//  EMTools.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import UIKit
import WebKit

internal class EMTools {
    
    static private var webView: WKWebView?
    
    static let userDefaults = UserDefaults(suiteName: EMKey.userDefaultSuiteKey)
    static var appGroupUserDefaults : UserDefaults?
    
    
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
        var val: Any?
        if let value = appGroupUserDefaults?.object(forKey: userKey) {
            val = value
        }
        else if let value = userDefaults?.object(forKey: userKey) {
            val = value
        }
        guard let value = val else {
            return nil
        }
        return value as AnyObject?
    }
    
    static func removeUserDefaults(userKey: String) {
        if userDefaults?.object(forKey: userKey) != nil {
            userDefaults?.removeObject(forKey: userKey)
            userDefaults?.synchronize()
        }
        if appGroupUserDefaults?.object(forKey: userKey) != nil {
            appGroupUserDefaults?.removeObject(forKey: userKey)
            appGroupUserDefaults?.synchronize()
        }
    }
    
    static func saveUserDefaults(key: String?, value: AnyObject?) {
        guard key != nil && value != nil else {
            return
        }
        userDefaults?.set(value, forKey: key!)
        userDefaults?.synchronize()
        appGroupUserDefaults?.set(value, forKey: key!)
        appGroupUserDefaults?.synchronize()
    }
    
    static func getInfoString(key: String) -> String? {
        let bundle = Bundle.init(for: self)
        return bundle.infoDictionary?[key] as? String
    }
    
    static func isiOSAppExtension() -> Bool {
        return Bundle.main.bundlePath.hasSuffix(".appex")
    }
    
    // swiftlint:disable todo line_length
    // TODO: dökümana appgroup kısmı eklenmeli, NotificationService, NotificationContent
    // TODO: dökümana developer.apple.com appgroup identifier tanımı eklenmeli
    // TODO: UserDefaults'taki suiteName kısmı dinamik olmalı
    static func getIdentifierForVendorString() -> String {
        let emptyUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        if let identifierForVendorString = retrieveUserDefaults(userKey: EMKey.identifierForVendorKey) as? String, let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            if !isiOSAppExtension() {
                EMKeychain.set(identifierForVendorString, forKey: EMKey.identifierForVendorKey)
            }
            return identifierForVendorString
        } else if let identifierForVendorString = EMKeychain.get(EMKey.identifierForVendorKey), let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            if !isiOSAppExtension() {
                saveUserDefaults(key: EMKey.identifierForVendorKey, value: identifierForVendorString as AnyObject)
            }
            return identifierForVendorString
        } else if let identifierForVendorString = UIDevice.current.identifierForVendor?.uuidString, let uuid = UUID(uuidString: identifierForVendorString), !uuid.uuidString.elementsEqual(emptyUUID.uuidString) {
            if !isiOSAppExtension() {
                saveUserDefaults(key: EMKey.identifierForVendorKey, value: identifierForVendorString as AnyObject)
                EMKeychain.set(identifierForVendorString, forKey: EMKey.identifierForVendorKey)
            }
            return identifierForVendorString
        }
        return ""
    }
    
    static func isNilOrWhiteSpace(_ value: String?) -> Bool {
        return value?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
    }
    
    static func computeWebViewUserAgent(completion: @escaping ((String) -> Void)) {
        DispatchQueue.main.async { [completion] in
            webView = WKWebView(frame: CGRect.zero)
            webView?.loadHTMLString("<html></html>", baseURL: nil)
            webView?.evaluateJavaScript("navigator.userAgent", completionHandler: { userAgent, error in
                if error == nil, let userAgentString = userAgent as? String, userAgentString.count > 0 {
                    completion(userAgentString)
                } else {
                    EMLog.error("Can not computed userAgent")
                }
            })
        }
    }
    
    private static func primaryBundleIdentifier() -> String? {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            if let b = Bundle(url: bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()) {
                bundle = b
            }
        }
        return bundle.bundleIdentifier
    }
    
    static func getAppGroupName(appGroupName: String?) -> String? {
        var name = appGroupName
        if name == nil, let primaryBundleIdentifier = primaryBundleIdentifier() {
            name = "\(EMKey.appGroupNameDefaultPrefix).\(primaryBundleIdentifier).\(EMKey.appGroupNameDefaultSuffix)"
        }
        return name?.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    static func setAppGroupsUserDefaults(appGroupName: String) {
        appGroupUserDefaults = UserDefaults(suiteName: appGroupName)
    }
    
    static private let dateFormatter = DateFormatter()

    static func formatDate(_ date: Date, format: String = "yyyy-MM-dd HH:mm:ss") -> String {
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: date)
    }
    
    static func parseDate(_ dateString: String, format: String = "yyyy-MM-dd HH:mm:ss") -> Date? {
        dateFormatter.dateFormat = format
        return dateFormatter.date(from: dateString)
    }
    
}
