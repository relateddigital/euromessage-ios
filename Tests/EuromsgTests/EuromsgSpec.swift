//
//  EuromsgSpec.swift
//  EuromsgTests
//
//  Created by Muhammed ARAFA on 7.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit
@testable import Euromsg

class EuromsgSpec: Euromsg {
    override class func configure(appAlias: String, enableLog: Bool = false) {
        shared = nil
    }
}
