//
//  EMKeys.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 14.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

class EMKey {
    internal static let appAliasNotProvidedMessage = """
                    appAlias not provided. Please use Euromsg.configure(::) function first.
                    For more information visit https://github.com/relateddigital/euromessage-ios
                    """
    internal static let sdkVersion = "2.4.1"
    internal static let tokenKey = "EURO_TOKEN_KEY"
    internal static let registerKey = "EURO_REGISTER_KEY"
    internal static let euroLastMessageKey = "EURO_LAST_MESSAGE_KEY"
    internal static let identifierForVendorKey = "EURO_IDENTIFIER_FOR_VENDOR_KEY"
    internal static let euroReceivedStatus = "D"
    internal static let euroReadStatus = "O"
    internal static let isBadgeCustom = "EMisBadgeCustom"
    internal static let badgeCount = "EMbadgeCount"
    internal static let userDefaultSuiteKey =  "group.relateddigital.euromsg" // TODO: bu sabit olmamalı, müşteri set etmeli.
    internal static let userAgent = "user-agent"
    
    internal static let timeoutInterval = 30
    internal static let prodBaseUrl = ".euromsg.com"
    
    
    internal static let payloadDayThreshold = 30
    internal static let euroPayloadsKey = "EURO_PAYLOADS_KEY"
    internal static let appGroupNameDefaultPrefix = "group"
    internal static let appGroupNameDefaultSuffix = "relateddigital"
    
    internal static let graylogLogLevelError = "e"
    internal static let graylogLogLevelWarning = "w"
    
    
}
