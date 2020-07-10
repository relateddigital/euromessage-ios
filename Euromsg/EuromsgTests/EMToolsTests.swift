//
//  EMToolsTests.swift
//  EuromsgTests
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import XCTest
@testable import Euromsg

class EMToolsTests: XCTestCase {

    func testPhoneValidator() {
        XCTAssertFalse(EMTools.validatePhone(phone: nil))
        XCTAssertFalse(EMTools.validatePhone(phone: "123456789"))
        XCTAssert(EMTools.validatePhone(phone: "0123456789"))
    }

    func testEmailValidator() {
        XCTAssertFalse(EMTools.validateEmail(email: nil))
        XCTAssertFalse(EMTools.validateEmail(email: ""))
        XCTAssert(EMTools.validateEmail(email: "aaa@aaa.com"))
    }

    func testGetString() {
        XCTAssert((EMTools.getInfoString(key: "CFBundleIdentifier") != nil))
    }
}
