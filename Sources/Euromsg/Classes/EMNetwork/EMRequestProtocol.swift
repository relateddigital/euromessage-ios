//
//  EMRequestProtocol.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

protocol EMRequestProtocol: EMCodable {
    var path: String { get }
    var method: String { get }
    var subdomain: String { get }
    var prodBaseUrl: String { get }
}
