//
//  EMGraylogRequest.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 8.09.2021.
//

import Foundation

struct EMGraylogRequest: EMCodable, EMRequestProtocol {
    internal var path = "log/mobileSdk"
    internal var method = "POST"
    internal var subdomain = "gt"
    internal var prodBaseUrl = ".relateddigital.com"

    var logLevel: String?
    var logMessage: String?
    var logPlace: String?
    var googleAppAlias: String?
    var huaweiAppAlias: String?
    var iosAppAlias: String?
    var token: String?
    var appVersion: String?
    var sdkVersion: String?
    var osType: String?
    var osVersion: String?
    var deviceName: String?
    var userAgent: String?
    var identifierForVendor: String?
    var extra: [String: String]? = [String: String]()
    
    enum CodingKeys: String, CodingKey {
        case logLevel = "logLevel"
        case logMessage = "logMessage"
        case logPlace = "logPlace"
        case googleAppAlias = "googleAppAlias"
        case huaweiAppAlias = "huaweiAppAlias"
        case iosAppAlias = "iosAppAlias"
        case token = "token"
        case appVersion = "appVersion"
        case sdkVersion = "sdkVersion"
        case osType = "osType"
        case osVersion = "osVersion"
        case deviceName = "deviceName"
        case userAgent = "userAgent"
        case identifierForVendor = "identifierForVendor"
        case extra = "extra"
    }
    
}
