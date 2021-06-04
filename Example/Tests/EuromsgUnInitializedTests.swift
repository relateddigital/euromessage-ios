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
        XCTAssertEqual(EuromsgSpec.checkConfiguration().appKey, "EuromsgIOSTest")
    }

    func testRegisterToken() {
        EuromsgSpec.registerToken(tokenData: nil)
        XCTAssertNil(Euromsg.checkConfiguration().token)
        EuromsgSpec.registerToken(tokenData: Data())
        XCTAssertTrue(Euromsg.checkConfiguration().token?.isEmpty ?? false)
    }

    func testSetPushNotificationPermission() {
        EuromsgSpec.setPushNotification(permission: true)
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.pushPermit, "Y")
    }

    func testSetEmailPermission() {
        EuromsgSpec.setEmail(email: "test@test.com", permission: true)
        XCTAssertNotNil(EuromsgSpec.checkConfiguration().properties?.email)
        XCTAssertNotNil(EuromsgSpec.checkConfiguration().properties?.emailPermit)
    }

    func testSetPhonePermission() {
        EuromsgSpec.setPhoneNumber(msisdn: "5551112233", permission: true)
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.msisdn, "5551112233")
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.gsmPermit, "Y")
    }

    func testSetUserKey() {
        EuromsgSpec.setEuroUserId(userKey: "Test User Key")
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.keyID, "Test User Key")
    }

    func testSetTwitterID() {
        EuromsgSpec.setTwitterId(twitterId: "TestTwitterId")
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.twitter, "TestTwitterId")
    }

    func testSetFacebookID() {
        EuromsgSpec.setFacebook(facebookId: "TestFacebookId")
        XCTAssertEqual(EuromsgSpec.checkConfiguration().properties?.facebook, "TestFacebookId")
    }

    func testSetAdvertisingIdentifier() {
        EuromsgSpec.setAdvertisingIdentifier(adIdentifier: "TestId")
        XCTAssertEqual(Euromsg.checkConfiguration().advertisingIdentifier, "TestId")
    }

    func testSetAppVersion() {
        EuromsgSpec.setAppVersion(appVersion: "TestAppVersion")
        XCTAssertEqual(Euromsg.checkConfiguration().appVersion, "TestAppVersion")
    }

    func testSetUserProperty() {
        EuromsgSpec.setUserProperty(key: "TestUserPropertyKey", value: "TestUserPropertyValue")
        XCTAssertEqual(EuromsgSpec.checkConfiguration().userProperties?["TestUserPropertyKey"] as! String, "TestUserPropertyValue")
    }

    func testHandlePush() {
        EuromsgSpec.handlePush(pushDictionary: [:])
        EuromsgSpec.handlePush(pushDictionary: ["pushId": "TestId"])
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
        EuromsgSpec.didReceive(bestAttemptContent, withContentHandler: { (content) in
            XCTAssertEqual(content, bestAttemptContent)
        })
    }

}
