//
//  EMMessage.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

public struct EMMessage: EMCodable {
    
    public func getDate() -> Date? {
        guard let dateString = formattedDateString  else {
            return nil
        }
        return EMTools.parseDate(dateString)
    }
    
    public func sendDeliver() -> Bool {
        if let deliver = deliver, deliver.compare("true", options: .caseInsensitive) == .orderedSame {
            return true
        }
        return false
    }
    
    public func isSilent() -> Bool {
        if let silent = silent, silent.compare("true", options: .caseInsensitive) == .orderedSame {
            return true
        }
        return false
    }
    
    public var formattedDateString: String?
    public let aps: Aps?
    public let altURL: String?
    public let cid: String?
    public let url: String?
    public let settings: String?
    public let pushType: String?
    public let altUrl: String?
    public let mediaUrl: String?
    public let fcmOptions: FcmOptions?
    public let deeplink: String?
    public let pushId: String?
    public let emPushSp: String?
    public let elements: [Element]?
    public var actions: [ActionButtons]?
    public let deliver: String?
    public let silent: String?
    public var status: String?
    public var openedDate: String?
    public var pushCategory: String?
    public var keyID: String?
    public var email: String?

    
    public var notificationLoginID: String?

    // MARK: - Aps
    public struct Aps: Codable {
        public let alert: Alert?
        public let category: String?
        public let sound: String?
        public let contentAvailable: Int?
    }

    // MARK: - Alert
    public struct Alert: Codable {
        public let title: String?
        public let body: String?
    }

    // MARK: - FcmOptions
    public struct FcmOptions: EMCodable {
        public let image: String?
    }

    // MARK: - Element
    public struct Element: Codable {
//        public let id: Int?
        public let title: String?
        public let content: String?
        public let url: String?
        public let picture: String?
    }

    public struct ActionButtons: Codable {
        public let Title: String?
        public let Action: String?
        public let Icon: String?
        public let Url: String?
        public let AlternateUrl: String?
    }
}
