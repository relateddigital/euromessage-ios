//
//  EMRegisterRequest.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import UIKit
import CoreTelephony

// MARK: - EMRegisterRequest
struct EMRegisterRequest: EMRequestProtocol, Equatable {

    internal var path = "subscription"
    internal var port = "4243"
    internal var method = "POST"
    internal var subdomain = "pushs"
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

        if let code = provider?.mobileCountryCode {
            if let networkCode = provider?.mobileNetworkCode {
                self.carrier = "\(code)\(networkCode)"
            }
        }

        self.osVersion = device.systemVersion
        self.deviceType = deviceType
        self.osName = device.systemName
        self.deviceName = device.name
        self.local = NSLocale.preferredLanguages.first
        self.firstTime = 1
        self.identifierForVendor = device.identifierForVendor?.uuidString
        self.token = nil
        self.extra = [:]
    }

    static func == (lhs: EMRegisterRequest, rhs: EMRegisterRequest) -> Bool {
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
        case consentType
        case consentSource
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
    var consentType: String?
    var consentSource: String = "HS_MOBIL"

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
        lhs.consentType == rhs.consentType &&
        lhs.consentSource == rhs.consentSource
    }

}
