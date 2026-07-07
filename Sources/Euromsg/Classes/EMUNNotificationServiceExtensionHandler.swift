//
//  EMUNNotificationServiceExtensionHandler.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 20.04.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation
import UIKit

class EMUNNotificationServiceExtensionHandler {

    public static func didReceive(_ bestAttemptContent: UNMutableNotificationContent?
                                  , withContentHandler contentHandler:  @escaping (UNNotificationContent) -> Void) {

        Euromsg.pushTrace("NSE didReceive started. sdkVersion: \(EMKey.sdkVersion), sharedConfigured: \(Euromsg.shared != nil), diagnostics: \(Euromsg.pushDiagnosticsEnabled)")
        EMUserDefaultsUtils.markNSEStage("started")

        // Every contentHandler call goes through this wrapper so an unfinished
        // run (timeout/crash/kill) can be detected and reported on next launch.
        let contentHandler: (UNNotificationContent) -> Void = { content in
            EMUserDefaultsUtils.markNSEStage("contentHandlerCalled", completed: true)
            contentHandler(content)
        }

        guard let bestAttemptContent = bestAttemptContent else {
            Euromsg.pushError("NSE bestAttemptContent is nil, push cannot be processed at all")
            return
        }
        let userInfo = bestAttemptContent.userInfo

        if let payloadData = try? JSONSerialization.data(withJSONObject: userInfo, options: []),
           let payloadString = String(data: payloadData, encoding: .utf8) {
            Euromsg.pushTrace("NSE raw payload: \(payloadString)")
        } else {
            Euromsg.pushWarning("NSE raw payload could not be serialized for logging (non-JSON values in userInfo)")
        }

        var modifiedUserInfo = userInfo

        do {
            if let aps = modifiedUserInfo["aps"] as? [AnyHashable: Any] {
                if let alert = aps["alert"] as? String {
                    Euromsg.pushTrace("NSE aps.alert is a plain string, converting to dictionary form")
                    var newAlert = [String: String]()
                    newAlert["body"] = alert
                    var modifiedAps = aps
                    modifiedAps["alert"] = newAlert

                    modifiedUserInfo["aps"] = modifiedAps
                }
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: modifiedUserInfo, options: []) else {
            Euromsg.pushError("NSE payload JSON serialization FAILED, push shown UNPROCESSED (no image, no deliver report)")
            contentHandler(bestAttemptContent)
            return
        }

        let pushDetail: EMMessage
        do {
            pushDetail = try JSONDecoder().decode(EMMessage.self, from: data)
        } catch {
            Euromsg.pushError("NSE payload decode to EMMessage FAILED: \(error), push shown UNPROCESSED (no image, no deliver report)")
            contentHandler(bestAttemptContent)
            return
        }

        Euromsg.pushTrace("NSE payload decoded. pushId: \(pushDetail.pushId ?? "nil"), pushType: \(pushDetail.pushType ?? "nil"), mediaUrl: \(pushDetail.mediaUrl ?? "nil"), deliver: \(pushDetail.deliver ?? "nil"), category: \(pushDetail.aps?.category ?? "nil"), actionCount: \(pushDetail.actions?.count ?? 0)")
        EMUserDefaultsUtils.markNSEStage("decoded", pushId: pushDetail.pushId)

        if pushDetail.sendDeliver() {
            if let shared = Euromsg.shared {
                Euromsg.pushTrace("NSE deliver report queued for pushId: \(pushDetail.pushId ?? "nil")")
                shared.networkQueue.async {
                    Euromsg.emDeliverHandler?.reportDeliver(message: pushDetail)
                }
            } else {
                Euromsg.pushWarning("NSE deliver flag is true but Euromsg.shared is nil, deliver report SKIPPED. Is Euromsg.configure(appAlias:) called in the extension before Euromsg.didReceive?")
            }
        } else {
            Euromsg.pushTrace("NSE deliver flag is '\(pushDetail.deliver ?? "nil")', deliver report not requested")
        }

        if let notificationLoginId = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.notificationLoginIdKey) as? String,
           !notificationLoginId.isEmpty {
            Euromsg.pushTrace("NSE payload saved with notificationLoginID: \(notificationLoginId)")
            EMUserDefaultsUtils.savePayloadWithId(payload: pushDetail, notificationLoginID: notificationLoginId)
        } else {
            Euromsg.pushTrace("NSE payload saved without notificationLoginID (app group defaults: \(EMUserDefaultsUtils.appGroupUserDefaults != nil ? "available" : "NOT available"))")
            EMUserDefaultsUtils.savePayload(payload: pushDetail)
        }

        // Setup carousel buttons
        if pushDetail.aps?.category == "carousel" {
            Euromsg.pushTrace("NSE carousel category detected, registering carousel actions")
            UNUNC.current().setNotificationCategories(getCarouselActionCategorySet())
        } else if pushDetail.actions?.count ?? 0 > 0 {
            Euromsg.pushTrace("NSE \(pushDetail.actions?.count ?? 0) action button(s) detected, registering category: \(pushDetail.aps?.category ?? "action_button")")
            addActionButtons(pushDetail)
        }

        // Setup notification for image/video
        let modifiedBestAttemptContent = bestAttemptContent

        if let sound = pushDetail.aps?.sound, sound.count > 0 {
            Euromsg.pushTrace("NSE custom sound set: \(sound)")
            modifiedBestAttemptContent.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }

        if pushDetail.pushType == "Image" || pushDetail.pushType == "Video" {
            guard let attachmentMedia = pushDetail.mediaUrl, !attachmentMedia.isEmpty else {
                Euromsg.pushError("NSE pushType is \(pushDetail.pushType ?? "") but mediaUrl is missing/empty, push shown WITHOUT image")
                contentHandler(modifiedBestAttemptContent)
                return
            }
            guard let mediaUrl = URL(string: attachmentMedia) else {
                Euromsg.pushError("NSE mediaUrl is not a valid URL: '\(attachmentMedia)' (whitespace or non-encoded characters?), push shown WITHOUT image")
                contentHandler(modifiedBestAttemptContent)
                return
            }
            if mediaUrl.scheme?.lowercased() != "https" {
                Euromsg.pushWarning("NSE mediaUrl scheme is '\(mediaUrl.scheme ?? "nil")', ATS may block non-HTTPS downloads in the extension: \(attachmentMedia)")
            }
            EMUserDefaultsUtils.markNSEStage("downloadStarted", pushId: pushDetail.pushId, detail: attachmentMedia)
            loadAttachments(mediaUrl: mediaUrl, modifiedBestAttemptContent: modifiedBestAttemptContent, withContentHandler: contentHandler)
        } else if pushDetail.pushType == "Text" && pushDetail.actions?.count ?? 0 > 0 {
            // Intentional dummy download: gives iOS time to register the action
            // category before the notification is presented.
            Euromsg.pushTrace("NSE Text push with action buttons, performing category-registration delay download")
            let mediaUrl = URL(string: "https://google.com")!
            loadAttachments(mediaUrl: mediaUrl, modifiedBestAttemptContent: modifiedBestAttemptContent, withContentHandler: contentHandler, expectAttachment: false)
        } else if pushDetail.pushType == "Text" {
            Euromsg.pushTrace("NSE Text push, contentHandler called (no attachment expected)")
            contentHandler(modifiedBestAttemptContent)
        } else {
            Euromsg.pushError("NSE unhandled pushType: '\(pushDetail.pushType ?? "nil")' (expected exact-case Image/Video/Text), push shown WITHOUT processing")
            contentHandler(modifiedBestAttemptContent)
        }
    }

    @available(iOS 10.0, *)
    static func addActionButtons(_ detail: EMMessage) {
        let categoryIdentifier = detail.aps?.category ??  "action_button"
        if let buttons = detail.actions {
            var actionButtons: [UNNotificationAction] = []
            var index = 0
            for button in buttons {
                if #available(iOS 15.0, *) {
                    actionButtons.append(UNNotificationAction(identifier: "action_\(index)",
                                                              title: button.Title ?? "",
                                                              options: [.foreground],icon: UNNotificationActionIcon.init(systemImageName: "\(button.Icon ?? "")")))
                } else {
                    actionButtons.append(UNNotificationAction(identifier: "action_\(index)",
                                                              title: button.Title ?? "",
                                                              options: [.foreground]))
                }
                index+=1
            }
            let actionCategory = UNNotificationCategory(identifier: categoryIdentifier,
                                                        actions: actionButtons,
                                                        intentIdentifiers: [], options: [])

            UNUserNotificationCenter.current().setNotificationCategories([actionCategory])
        }
    }

    private func openLink() {
        if let url = URL(string: "") {
            UIApplication.shared.open(url)
        }
    }

    static func getCarouselActionCategorySet() -> Set<UNNotificationCategory>  {
        let categoryIdentifier = "carousel"
        let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "▶", options: [])
        let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "◀", options: [])
        let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
        return [carouselCategory]
    }

    static func loadAttachments(mediaUrl: URL,
                                modifiedBestAttemptContent: UNMutableNotificationContent,
                                withContentHandler contentHandler:  @escaping (UNNotificationContent) -> Void,
                                expectAttachment: Bool = true) {
        if expectAttachment {
            Euromsg.pushTrace("NSE attachment download starting: \(mediaUrl.absoluteString)")
        }
        let startTime = Date()
        let session = URLSession(configuration: .default)
        session.downloadTask(
            with: mediaUrl,
            completionHandler: { temporaryLocation, response, error in
                let elapsed = String(format: "%.2f", Date().timeIntervalSince(startTime))
                if let err = error {
                    if expectAttachment {
                        Euromsg.pushError("NSE attachment download FAILED after \(elapsed)s: \(err.localizedDescription), URL: \(mediaUrl.absoluteString), push shown WITHOUT image")
                    }
                    contentHandler(modifiedBestAttemptContent)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let mimeType = response?.mimeType ?? ""
                var fileSize: Int64 = -1
                if let path = temporaryLocation?.path,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attributes[.size] as? Int64 {
                    fileSize = size
                }
                if expectAttachment {
                    Euromsg.pushTrace("NSE download finished in \(elapsed)s. httpStatus: \(statusCode), contentType: \(mimeType.isEmpty ? "nil" : mimeType), fileSize: \(fileSize) bytes")
                }

                guard expectAttachment else {
                    contentHandler(modifiedBestAttemptContent)
                    return
                }

                if statusCode >= 400 {
                    Euromsg.pushError("NSE attachment download returned HTTP \(statusCode), URL: \(mediaUrl.absoluteString), push shown WITHOUT image")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
                guard !mimeType.isEmpty else {
                    Euromsg.pushError("NSE response has no content-type, file type cannot be determined, URL: \(mediaUrl.absoluteString), push shown WITHOUT image")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
                let fileType = self.determineType(fileType: mimeType)
                if fileType == ".tmp" {
                    Euromsg.pushError("NSE unsupported content-type '\(mimeType)' (supported: image/jpeg, image/png, image/gif, video/mp4; WebP/octet-stream are NOT supported by iOS attachments), URL: \(mediaUrl.absoluteString), push shown WITHOUT image")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
                if fileSize > 10 * 1024 * 1024 {
                    Euromsg.pushWarning("NSE downloaded file is \(fileSize) bytes, iOS attachment size limit (10MB for images) may reject it, URL: \(mediaUrl.absoluteString)")
                }
                guard let temporaryLocation = temporaryLocation else {
                    Euromsg.pushError("NSE download reported success but temporary file is missing, push shown WITHOUT image")
                    contentHandler(modifiedBestAttemptContent)
                    return
                }
                let fileName = temporaryLocation.lastPathComponent.appending(fileType)
                let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(fileName)
                do {
                    try FileManager.default.moveItem(at: temporaryLocation,
                                                     to: temporaryDirectory)
                    let attachment = try UNNotificationAttachment(identifier: "",
                                                                  url: temporaryDirectory, options: nil)
                    modifiedBestAttemptContent.attachments = [attachment]
                    Euromsg.pushTrace("NSE attachment created successfully (\(fileType), \(fileSize) bytes), contentHandler called WITH image")
                    contentHandler(modifiedBestAttemptContent)
                    if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                        try FileManager.default.removeItem(at: temporaryDirectory)
                    }
                } catch {
                    Euromsg.pushError("NSE attachment creation FAILED: \(error), contentType: \(mimeType), fileSize: \(fileSize) bytes, URL: \(mediaUrl.absoluteString), push shown WITHOUT image")
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
