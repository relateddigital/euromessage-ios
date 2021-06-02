//
// AppDelegate.swift
// Euromsg
//
// Created by cicimen on 08/04/2020.
// Copyright (c) 2020 cicimen. All rights reserved.
//
import UIKit
import Euromsg
import UserNotifications
@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        // Configure Euromsg SDK
        Euromsg.configure(appAlias: "EuromsgIOSTest", enableLog: true)
        Euromsg.registerForPushNotifications()

        if #available(iOS 13, *) {
            // handle push for iOS 13 and later in sceneDelegate
        } else if let userInfo = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Any] {
            Euromsg.handlePush(pushDictionary: userInfo)
        }

        // Customize badge
//        Euromsg.setBadge(count: 5)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Euromsg.registerToken(tokenData: deviceToken)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
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
        completionHandler([.alert, .badge, .sound])
    }

    // This function will be called right after user tap on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Euromsg.handlePush(pushDictionary: response.notification.request.content.userInfo)
        completionHandler()
    }
}
