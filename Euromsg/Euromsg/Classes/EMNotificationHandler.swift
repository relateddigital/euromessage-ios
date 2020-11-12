//
//  EMNotificationServiceHandler.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 20.04.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import UIKit

class EMNotificationHandler {

    @available(iOS 10.0, *)
    public static func didReceive(_ bestAttemptContent: UNMutableNotificationContent?,
                                  withContentHandler contentHandler:  @escaping (UNNotificationContent) -> Void) {
        guard let userInfo = bestAttemptContent?.userInfo,
            let data = try? JSONSerialization.data(withJSONObject: userInfo,
                                                   options: []) else { return }
        guard let pushDetail = try? JSONDecoder.init().decode(EMMessage.self,
                                                              from: data) else { return }
        Euromsg.shared?.emNetworkHandler?.reportRetention(message: pushDetail,
                                                          status: EMKey.euroReceivedStatus)
        EMTools.saveUserDefaults(key: EMKey.euroLastMessageKey, value: data as AnyObject)

        // Setup badge
        let userDefaults = UserDefaults(suiteName: EMKey.userDefaultSuiteKey)
        let badgeCount = userDefaults?.integer(forKey: EMKey.badgeCount)
        if let badgeCount = badgeCount, badgeCount > 0 {
            userDefaults?.set(badgeCount + 1, forKey: EMKey.badgeCount)
            bestAttemptContent?.badge = badgeCount + 1 as NSNumber
        } else {
            userDefaults?.set(1, forKey: EMKey.badgeCount)
            bestAttemptContent?.badge = 1
        }

        // Setup carousel buttons
        if pushDetail.aps?.category == "carousel" {
            addCarouselActionButtons()
        } else if pushDetail.aps?.category == "action.button" {
            addActionButtons(pushDetail)
        }

        // Setup notification for image/video
        guard let modifiedBestAttemptContent = bestAttemptContent else { return }
        if pushDetail.pushType == "Image" || pushDetail.pushType == "Video",
            let attachmentMedia = pushDetail.mediaUrl, let mediaUrl = URL(string: attachmentMedia) {
            loadAttachments(mediaUrl: mediaUrl,
                            modifiedBestAttemptContent: modifiedBestAttemptContent,
                            withContentHandler: contentHandler)
        } else {
            contentHandler(modifiedBestAttemptContent)
        }
    }

    @available(iOS 10.0, *)
    static func addCarouselActionButtons() {
        let categoryIdentifier = "carousel"
        let carouselNext = UNNotificationAction(identifier: "carousel.next",
                                                title: "▶", options: [])
        let carouselPrevious = UNNotificationAction(identifier: "carousel.previous",
                                                    title: "◀", options: [])
        let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier,
                                                      actions: [carouselNext, carouselPrevious],
                                                      intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
    }

    @available(iOS 10.0, *)
    static func addActionButtons(_ detail: EMMessage) {
        let categoryIdentifier = "action.button"
        if let buttons = detail.buttons {
            var actionButtons: [UNNotificationAction] = []
            for button in buttons {
                actionButtons.append(UNNotificationAction(identifier: button.identifier ?? "",
                                                          title: button.title ?? "",
                                                          options: [.foreground]))
            }
            let actionCategory = UNNotificationCategory(identifier: categoryIdentifier,
                                                          actions: actionButtons,
                                                          intentIdentifiers: [], options: [])

            UNUserNotificationCenter.current().setNotificationCategories([actionCategory])

        }
    }

    @available(iOS 10.0, *)
    static func loadAttachments(mediaUrl: URL,
                                modifiedBestAttemptContent: UNMutableNotificationContent,
                                withContentHandler contentHandler:  @escaping (UNNotificationContent) -> Void) {
        let session = URLSession(configuration: .default)
        session.downloadTask(
            with: mediaUrl,
            completionHandler: { temporaryLocation, response, error in
                if let err = error {
                    let desc = err.localizedDescription
                    EMLog.error("Error with downloading rich push: \(String(describing: desc))")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
                guard let mimeType = response?.mimeType else { return }
                let fileType = self.determineType(fileType: mimeType)
                guard let fileName = temporaryLocation?.lastPathComponent.appending(fileType) else { return }
                let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(fileName)
                do {
                    guard let temporaryLocation = temporaryLocation else { return }
                    try FileManager.default.moveItem(at: temporaryLocation,
                                                     to: temporaryDirectory)
                    let attachment = try UNNotificationAttachment(identifier: "",
                                                                  url: temporaryDirectory, options: nil)
                    modifiedBestAttemptContent.attachments = [attachment]
                    contentHandler(modifiedBestAttemptContent)
                    if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                        try FileManager.default.removeItem(at: temporaryDirectory)
                    }
                } catch {
                    EMLog.error("Error with the rich push attachment: \(error)")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
        }).resume()
    }

    static func determineType(fileType: String) -> String {
        switch fileType {
        case "video/mp4":
            return ".mp4"
        case "image/jpeg":
            return ".jpg"
        case "image/gif":
            return ".gif"
        case "image/png":
            return ".png"
        default:
            return ".tmp"
        }
    }

}
