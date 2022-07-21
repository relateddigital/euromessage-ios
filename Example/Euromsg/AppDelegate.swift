//
// AppDelegate.swift
// Euromsg
//
// Created by cicimen on 08/04/2020.
// Copyright (c) 2020 cicimen. All rights reserved.
//
import Euromsg
import UIKit
import UserNotifications
@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    var userInfoPayload = ""
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Configure Euromsg SDK
        Euromsg.configure(appAlias: "EuromsgIOSTest", launchOptions: launchOptions, enableLog: true, appGroupsKey: "group.com.relateddigital.EuromsgExample.relateddigital", deliveredBadge: false)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Euromsg.registerToken(tokenData: deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        Euromsg.handlePush(pushDictionary: userInfo)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Euromsg.handlePush(pushDictionary: userInfo)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    // This function will be called right after user tap on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Euromsg.handlePush(pushDictionary: response.notification.request.content.userInfo)

        userInfoPayload = response.notification.request.content.userInfo.toString() ?? "çevrilemedi"
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let presentViewController = storyBoard.instantiateViewController(withIdentifier: "payload") as! PayloadViewController

        window?.rootViewController?.present(presentViewController, animated: true, completion: nil)
        completionHandler()
    }
}

extension Dictionary {
    func toString() -> String? {
        return (compactMap({ (key, value) -> String in
            "\(key)=\(value)"
        }) as Array).joined(separator: "\n\n")
    }
}

extension String {
    var decodingUnicodeCharacters: String { applyingTransform(.init("Hex-Any"), reverse: false) ?? "" }
}
