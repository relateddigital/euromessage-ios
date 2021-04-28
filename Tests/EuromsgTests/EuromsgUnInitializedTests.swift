//
//  EuromsgUnInitializedTests.swift
//  EuromsgTests
//
//  Created by Muhammed ARAFA on 7.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import XCTest
@testable import Euromsg

@available(iOS 10.0, *)
class EuromsgUnInitializedTests: XCTestCase {

    override func setUp() {
        EuromsgSpec.configure(appAlias: "appKey",
                          enableLog: true)
        EuromsgSpec.logout()
    }

    func testEuromsgappKey() {
        XCTAssertNil(EuromsgSpec.checkConfiguration().appKey)
    }

    func testRegisterToken() {
        EuromsgSpec.registerToken(tokenData: nil)
        XCTAssertNil(Euromsg.checkConfiguration().token)
        EuromsgSpec.registerToken(tokenData: Data())
        XCTAssertNil(Euromsg.checkConfiguration().token)
    }

    func testSetPushNotificationPermission() {
        EuromsgSpec.setPushNotification(permission: true)
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.pushPermit)
    }

    func testSetEmailPermission() {
        EuromsgSpec.setEmail(email: "test@test.com", permission: true)
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.email)
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.emailPermit)
    }

    func testSetPhonePermission() {
        EuromsgSpec.setPhoneNumber(msisdn: "5551112233", permission: true)
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.msisdn)
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.gsmPermit)
    }

    func testSetUserKey() {
        EuromsgSpec.setEuroUserId(userKey: "Test User Key")
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.keyID)
    }

    func testSetTwitterID() {
        EuromsgSpec.setTwitterId(twitterId: "TestTwitterId")
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.twitter)
    }

    func testSetFacebookID() {
        EuromsgSpec.setFacebook(facebookId: "TestFacebookId")
        XCTAssertNil(EuromsgSpec.checkConfiguration().properties?.facebook)
    }

    func testSetAdvertisingIdentifier() {
        EuromsgSpec.setAdvertisingIdentifier(adIdentifier: "TestId")
        XCTAssertNil(Euromsg.checkConfiguration().advertisingIdentifier)
    }

    func testSetAppVersion() {
        EuromsgSpec.setAppVersion(appVersion: "TestAppVersion")
        XCTAssertNil(Euromsg.checkConfiguration().appVersion)
    }

    func testSetUserProperty() {
        EuromsgSpec.setUserProperty(key: "TestUserPropertyKey", value: "TestUserPropertyValue")
        XCTAssertNil(EuromsgSpec.checkConfiguration().userProperties?["TestUserPropertyKey"])
    }

    func testHandlePush() {
        EuromsgSpec.handlePush(pushDictionary: [:])
        EuromsgSpec.handlePush(pushDictionary: ["pushId": "TestId"])
        XCTAssert(true)
    }

    func testEMRegisterRequest() {
        var first = EMRegisterRequest()
        let second = first
        XCTAssertEqual(first, second)
        first.firstTime = 0
        XCTAssertNotEqual(first, second)
    }

    @available(iOS 10.0, *)
    func testNotificationService() {
        let bestAttemptContent = UNMutableNotificationContent()
        bestAttemptContent.userInfo = ["test": "test"]
        EuromsgSpec.didReceive(bestAttemptContent, withContentHandler: { (content) in
            XCTAssertEqual(content, bestAttemptContent)
        })
    }

}
