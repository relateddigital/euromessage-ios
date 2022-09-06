//
//  EMSubscriptionRequest.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//
import Foundation
import UIKit
import CoreTelephony

// MARK: - Subscription
struct EMSubscriptionRequest: EMRequestProtocol, Equatable {

    internal var path = "subscription"
    internal var method = "POST"
    internal var subdomain = "pushs"
    internal var prodBaseUrl = ".euromsg.com"
    
    var extra: [String: String]?
    var firstTime: Int?
    var osVersion: String?
    var deviceType: String?
    var osName: String?
    var deviceName: String?
    var token: String?
    var local: String?
    var identifierForVendor: String?
    var appKey: String?
    var appVersion: String?
    var advertisingIdentifier: String?
    var sdkVersion: String?
    var carrier: String?

    // local variable
    var isBadgeCustom: Bool?

    enum CodingKeys: String, CodingKey {
        case extra = "extra"
        case firstTime = "firstTime"
        case osVersion = "osVersion"
        case deviceType = "deviceType"
        case osName = "os"
        case deviceName = "deviceName"
        case token = "token"
        case local = "local"
        case identifierForVendor = "identifierForVendor"
        case appKey = "appKey"
        case appVersion = "appVersion"
        case advertisingIdentifier = "advertisingIdentifier"
        case sdkVersion = "sdkVersion"
        case carrier = "carrier"
    }

    init() {
        self.token = nil
        self.extra = [:]
    }

    mutating func setDeviceParameters() {
        let device = UIDevice.current
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceType = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        let provider: CTCarrier?
        if #available(iOS 12, *) {
            provider = CTTelephonyNetworkInfo.init().serviceSubscriberCellularProviders?.first?.value
        } else {
            provider = CTTelephonyNetworkInfo.init().subscriberCellularProvider
        }

        self.firstTime = 0
        self.osName = device.systemName
        self.osVersion = device.systemVersion
        self.sdkVersion = EMKey.sdkVersion
        self.deviceName = device.name
        self.deviceType = deviceType

        if let code = provider?.mobileCountryCode {
            if let networkCode = provider?.mobileNetworkCode {
                self.carrier = "\(code)\(networkCode)"
            }
        }

        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            self.appVersion = appVersion
        }

        self.identifierForVendor = EMTools.getIdentifierForVendorString()
        self.local = NSLocale.preferredLanguages.first
    }

    static func == (lhs: EMSubscriptionRequest, rhs: EMSubscriptionRequest) -> Bool {
        lhs.extra == rhs.extra &&
        lhs.firstTime == rhs.firstTime &&
        lhs.osVersion == rhs.osVersion &&
        lhs.deviceType == rhs.deviceType &&
        lhs.osName == rhs.osName &&
        lhs.deviceName == rhs.deviceName &&
        lhs.token == rhs.token &&
        lhs.local == rhs.local &&
        lhs.identifierForVendor == rhs.identifierForVendor &&
        lhs.appKey == rhs.appKey &&
        lhs.appVersion == rhs.appVersion &&
        lhs.advertisingIdentifier == rhs.advertisingIdentifier &&
        lhs.sdkVersion == rhs.sdkVersion &&
        lhs.carrier == rhs.carrier
    }

    func isValid() -> Bool {
        return !EMTools.isNilOrWhiteSpace(self.token) && !EMTools.isNilOrWhiteSpace(self.appKey)
    }
}

// MARK: - Extra
public struct EMProperties: Codable, Equatable {
    enum PermissionKeys: String {
        case yes = "Y", not = "N"
    }
    enum CodingKeys: String, CodingKey {
        case keyID
        case email
        case emailPermit
        case pushPermit
        case gsmPermit
        case msisdn
        case location
        case facebook
        case twitter
        case consentTime
        case recipientType
        case consentSource
        case notificationLoginID
    }

    var keyID: String?
    var email: String?
    public var emailPermit: String?
    public var pushPermit: String?
    public var gsmPermit: String?
    var msisdn: String?
    var location: String?
    var facebook: String?
    var twitter: String?
    var consentTime: String?
    var recipientType: String?
    var consentSource: String? = "HS_MOBIL"
    var userAgent: String?
    
    var notificationLoginID: String?

    public static func == (lhs: EMProperties, rhs: EMProperties) -> Bool {
        lhs.keyID == rhs.keyID &&
        lhs.email == rhs.email &&
        lhs.emailPermit == rhs.emailPermit &&
        lhs.pushPermit == rhs.pushPermit &&
        lhs.gsmPermit == rhs.gsmPermit &&
        lhs.msisdn == rhs.msisdn &&
        lhs.location == rhs.location &&
        lhs.facebook == rhs.facebook &&
        lhs.twitter == rhs.twitter &&
        lhs.consentTime == rhs.consentTime &&
        lhs.recipientType == rhs.recipientType &&
        lhs.consentSource == rhs.consentSource
    }

}
