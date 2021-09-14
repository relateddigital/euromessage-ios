//
//  EMCodable.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 6.04.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit

public protocol EMCodable: Codable {}
public extension EMCodable {
    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
