//
//  EMConfiguration.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 31.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

public struct EMConfiguration {
    public var userProperties: [String: Any]?
    public var properties: EMProperties?
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
    public var carrier: String?
}
