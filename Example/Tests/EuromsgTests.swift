//
//  EuromsgTests.swift
//  EuromsgTests
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import XCTest
@testable import Euromsg

class EuromsgTests: XCTestCase {

    override func setUp() {
        Euromsg.configure(appAlias: "appKey",
                          enableLog: true)
        Euromsg.logout()
    }

    func testEuromsgAppKey() {
        XCTAssertNotNil(Euromsg.checkConfiguration().appKey)
        Euromsg.configure(appAlias: "appKey",
                          enableLog: true)
        XCTAssert(true)
    }

    func testRegisterToken() {
        Euromsg.registerToken(tokenData: nil)
        XCTAssertNil(Euromsg.checkConfiguration().token)
        Euromsg.registerToken(tokenData: Data(base64Encoded: "dG9rZW4="))
        XCTAssertNotNil(Euromsg.checkConfiguration().token)
    }

    func testSetPushNotificationPermission() {
        Euromsg.setPushNotification(permission: true)
        XCTAssert(Euromsg.checkConfiguration().properties?.pushPermit == "Y")
        Euromsg.setPushNotification(permission: false)
        XCTAssert(Euromsg.checkConfiguration().properties?.pushPermit == "N")
    }

    func testSetEmailPermission() {
        XCTAssertNil(Euromsg.checkConfiguration().properties?.email)
        XCTAssertNil(Euromsg.checkConfiguration().properties?.emailPermit)
        Euromsg.setEmail(email: "test@test.com", permission: true)
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.email)
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.emailPermit)
        XCTAssert(Euromsg.checkConfiguration().properties?.emailPermit == "Y")
        Euromsg.setEmail(permission: false)
        XCTAssert(Euromsg.checkConfiguration().properties?.emailPermit == "N")
    }

    func testSetPhonePermission() {
        XCTAssertNil(Euromsg.checkConfiguration().properties?.msisdn)
        XCTAssertNil(Euromsg.checkConfiguration().properties?.gsmPermit)
        Euromsg.setPhoneNumber(msisdn: "5551112233", permission: true)
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.msisdn)
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.gsmPermit)
        XCTAssert(Euromsg.checkConfiguration().properties?.gsmPermit == "Y")
        Euromsg.setPhoneNumber(permission: false)
        XCTAssert(Euromsg.checkConfiguration().properties?.gsmPermit == "N")
    }

    func testSetUserKey() {
        XCTAssertNil(Euromsg.checkConfiguration().properties?.keyID)
        Euromsg.setEuroUserId(userKey: "Test User Key")
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.keyID)
    }

    func testSetTwitterID() {
        XCTAssertNil(Euromsg.checkConfiguration().properties?.twitter)
        Euromsg.setTwitterId(twitterId: "TestTwitterId")
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.twitter)
    }

    func testSetFacebookID() {
        XCTAssertNil(Euromsg.checkConfiguration().properties?.facebook)
        Euromsg.setFacebook(facebookId: "TestFacebookId")
        XCTAssertNotNil(Euromsg.checkConfiguration().properties?.facebook)
    }

    func testSetAdvertisingIdentifier() {
        XCTAssertNil(Euromsg.checkConfiguration().advertisingIdentifier)
        Euromsg.setAdvertisingIdentifier(adIdentifier: "TestId")
        XCTAssertNotNil(Euromsg.checkConfiguration().advertisingIdentifier)
    }

    func testSetAppVersion() {
        XCTAssertNil(Euromsg.checkConfiguration().appVersion)
        Euromsg.setAppVersion(appVersion: "TestAppVersion")
        XCTAssertNotNil(Euromsg.checkConfiguration().appVersion)
    }

    func testSetUserProperty() {
        XCTAssertNil(Euromsg.checkConfiguration().userProperties?["TestUserPropertyKey"])
        Euromsg.setUserProperty(key: "TestUserPropertyKey", value: "TestUserPropertyValue")
        XCTAssertNotNil(Euromsg.checkConfiguration().userProperties?["TestUserPropertyKey"])
    }

    func testHandlePush() {
        Euromsg.handlePush(pushDictionary: [:])
        Euromsg.handlePush(pushDictionary: ["pushId": "TestId"])
        XCTAssert(true)
    }

    func testEMSubscriptionRequest() {
        var first = EMSubscriptionRequest()
        let second = first
        XCTAssertEqual(first, second)
        first.firstTime = 0
        XCTAssertNotEqual(first, second)
    }

    @available(iOS 10.0, *)
    func testNotificationService() {
        let bestAttemptContent = UNMutableNotificationContent()
        bestAttemptContent.userInfo = ["test": "test"]
        Euromsg.didReceive(bestAttemptContent, withContentHandler: { (content) in
            XCTAssertEqual(content, bestAttemptContent)
        })
    }

}
