//
//  EMRetentionRequest.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

struct EMRetentionRequest: EMCodable, EMRequestProtocol {
    var path = "retention"
    var port = "4242"
    var method = "POST"
    var subdomain = "pushr"

    var key: String
    var token: String
    var status: String
    var pushId: String
    var emPushSP: String
}
