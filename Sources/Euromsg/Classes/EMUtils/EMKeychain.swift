//
//  EMKeychain.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 17.05.2021.
//

import Security
import Foundation

internal class EMKeychain {

    private static let accessLevel = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    private static let lock = NSLock()
    private static var lastResultCode: OSStatus = noErr
    private static let coreFoundationBooleanTrue: CFBoolean = kCFBooleanTrue

    @discardableResult
    static func set(_ value: String, forKey key: String) -> Bool {
        guard let value = value.data(using: String.Encoding.utf8) else {
            return false
        }
        lock.lock()
        defer { lock.unlock() }
        deleteNoLock(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessLevel
        ]
        lastResultCode = SecItemAdd(query as CFDictionary, nil)
        return lastResultCode == noErr
    }

    static func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        var result: AnyObject?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: coreFoundationBooleanTrue
        ]
        lastResultCode = withUnsafeMutablePointer(to: &result) {
          SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        if lastResultCode == noErr, let data = result as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }

    @discardableResult
    static func deleteNoLock(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        lastResultCode = SecItemDelete(query as CFDictionary)
        return lastResultCode == noErr
    }
}
