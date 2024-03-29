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
public struct EMSubscriptionRequest: EMRequestProtocol, Equatable {

    public var path = "subscription"
    public var method = "POST"
    public var subdomain = "pushs"
    public var prodBaseUrl = ".euromsg.com"
    
    public var extra: [String: String]?
    public var firstTime: Int?
    public var osVersion: String?
    public var deviceType: String?
    public var osName: String?
    public var deviceName: String?
    public var token: String?
    public var local: String?
    public var identifierForVendor: String?
    public var appKey: String?
    public var appVersion: String?
    public var advertisingIdentifier: String?
    public var sdkVersion: String?
    public var sdkType: String?
    public var carrier: String?

    // local variable
    public var isBadgeCustom: Bool?

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
        case sdkType = "sdkType"
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
        self.sdkType = EMKey.sdkType
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

    public static func == (lhs: EMSubscriptionRequest, rhs: EMSubscriptionRequest) -> Bool {
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
        lhs.sdkType == rhs.sdkType &&
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
        case SetAnonymous
    }

    public var keyID: String?
    public var email: String?
    public var emailPermit: String?
    public var pushPermit: String?
    public var gsmPermit: String?
    public var msisdn: String?
    public var location: String?
    public var facebook: String?
    public var twitter: String?
    public var consentTime: String?
    public var recipientType: String?
    public var consentSource: String? = "HS_MOBIL"
    public var userAgent: String?
    
    public var notificationLoginID: String?
    public var SetAnonymous: String?

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
        lhs.consentSource == rhs.consentSource &&
        lhs.SetAnonymous == rhs.SetAnonymous
    }

}
