//
//  EMRetentionRequest.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

struct EMRetentionRequest: EMCodable, EMRequestProtocol {
    internal var path = "retention"
    internal var method = "POST"
    internal var subdomain = "pushr"
    internal var prodBaseUrl = ".euromsg.com"

    var key: String
    var token: String
    var status: String
    var pushId: String
    var emPushSp: String
    
    enum CodingKeys: String, CodingKey {
        case key = "key"
        case token = "token"
        case status = "status"
        case pushId = "pushId"
        case emPushSp = "emPushSp"
    }
}
