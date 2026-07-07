//
//  NotificationService.swift
//  NotificationService
//
//  Created by Muhammed ARAFA on 12.04.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UserNotifications
import Euromsg

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        Euromsg.configure(appAlias: "EuromsgIOSTest", launchOptions: nil, enableLog: true, appGroupsKey: "group.com.relateddigital.EuromsgExample.relateddigital", deliveredBadge: false)
        Euromsg.didReceive(bestAttemptContent, withContentHandler: contentHandler)
        printPayloadAsJSON(request.content.userInfo)
    }

    override func serviceExtensionTimeWillExpire() {
        // Logs the timeout to Graylog and shows the push with its original content
        Euromsg.serviceExtensionTimeWillExpire(bestAttemptContent, withContentHandler: contentHandler)
    }
    
    func printPayloadAsJSON(_ userInfo: [AnyHashable: Any]) {
        // AnyHashable -> String dönüşümü
        var jsonCompatible: [String: Any] = [:]
        for (key, value) in userInfo {
            jsonCompatible["\(key)"] = value
        }
        
        // JSONData -> String (pretty format)
        if let data = try? JSONSerialization.data(withJSONObject: jsonCompatible, options: [.prettyPrinted]),
           let jsonString = String(data: data, encoding: .utf8) {
            print("📦 Gelen Push Payload (JSON):\n\(jsonString)")
        } else {
            print("⚠️ Payload JSON’a çevrilemedi, raw data:\n\(userInfo)")
        }
    }

}
