//
//  EMGraylogRequest.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 8.09.2021.
//

import Foundation

struct EMGraylogRequest: EMCodable, EMRequestProtocol {
    var path = "log/mobileSdk"
    var method = "POST"
    var subdomain = "gt"

    var logLevel: String
    var logMessage: String
    var logPlace: String
    var googleAppAlias: String
    var huaweiAppAlias: String
    var iosAppAlias: String
    var token: String
    var appVersion: String
    var sdkVersion: String
    var osType: String
    var osVersion: String
    var deviceName: String
    var userAgent: String
    var identifierForVendor: String
    var extra: [String: String]?
}
