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
    var userInfoPayload = ""
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        // Configure Euromsg SDK
        Euromsg.configure(appAlias: "EuromsgIOSTest", launchOptions: launchOptions, enableLog: true)
        Euromsg.registerForPushNotifications()

        // Customize badge
//        Euromsg.setBadge(count: 5)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Euromsg.registerToken(tokenData: deviceToken)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        //Euromsg.handlePush(pushDictionary: userInfo)
        print("didReceiveRemoteNotification userInfo: [AnyHashable: Any]")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        //Euromsg.handlePush(pushDictionary: userInfo)
        print("fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)")
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
        
        
        //Euromsg.handlePush(pushDictionary: response.notification.request.content.userInfo)
        
        //userInfoPayload = response.notification.request.content.userInfo.toString() ?? "çevrilemedi"
        //let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        //        let presentViewController = storyBoard.instantiateViewController(withIdentifier: "payload") as! PayloadViewController

                        
        //        self.window?.rootViewController?.present(presentViewController, animated: true, completion: nil)
        print("userNotificationCenter didReceive")
        completionHandler()
    }
}

extension Dictionary {

    func toString() -> String? {
        return (self.compactMap({ (key, value) -> String in
            return "\(key)=\(value)"
        }) as Array).joined(separator: "\n\n")
    }

}

extension String {
    var decodingUnicodeCharacters: String { applyingTransform(.init("Hex-Any"), reverse: false) ?? "" }
}
