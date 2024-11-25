//
//  EMMessage.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 27.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues { $0.value }
        } else if container.decodeNil() {
            self.value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let arrayValue = value as? [Any] {
            let anyCodableArray = arrayValue.map { AnyCodable($0) }
            try container.encode(anyCodableArray)
        } else if let dictValue = value as? [String: Any] {
            let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
            try container.encode(anyCodableDict)
        } else if value is NSNull {
            try container.encodeNil()
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// RDPushMessage yapısı
public struct EMMessage: Codable {
    
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
    public let utm_source: String?
    public let utm_campaign: String?
    public let utm_medium: String?
    public let utm_content: String?
    public let utm_term: String?
    public var notificationLoginID: String?
    public var status: String?
    public var openedDate: String?
    public var actions: [ActionButtons]?
    public var pushCategory: String?
    public var keyID: String?
    public var email: String?
    public let deliver: String?
    public let silent: String?

    // Ekstra parametreleri saklamak için
    public var extraFields: [String: Any] = [:]
    
    public var encode: String? {
            if let jsonData = try? JSONEncoder().encode(self) {
                return String(data: jsonData, encoding: .utf8)
            }
            return nil
        }

    // CodingKeys enum'u
    enum CodingKeys: String, CodingKey, CaseIterable {
        case formattedDateString
        case aps
        case altURL
        case cid
        case url
        case settings
        case pushType
        case altUrl
        case mediaUrl
        case fcmOptions
        case deeplink
        case pushId
        case emPushSp
        case elements
        case utm_source
        case utm_campaign
        case utm_medium
        case utm_content
        case utm_term
        case notificationLoginID
        case status
        case openedDate
        case actions
        case pushCategory
        case keyID
        case email
        case deliver
        case silent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // Bilinen parametreleri decode etme
        formattedDateString = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "formattedDateString")!)
        aps = try container.decodeIfPresent(Aps.self, forKey: DynamicCodingKeys(stringValue: "aps")!)
        altURL = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "altURL")!)
        cid = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "cid")!)
        url = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "url")!)
        settings = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "settings")!)
        pushType = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "pushType")!)
        altUrl = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "altUrl")!)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "mediaUrl")!)
        fcmOptions = try container.decodeIfPresent(FcmOptions.self, forKey: DynamicCodingKeys(stringValue: "fcmOptions")!)
        deeplink = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "deeplink")!)
        pushId = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "pushId")!)
        emPushSp = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "emPushSp")!)
        elements = try container.decodeIfPresent([Element].self, forKey: DynamicCodingKeys(stringValue: "elements")!)
        utm_source = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "utm_source")!)
        utm_campaign = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "utm_campaign")!)
        utm_medium = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "utm_medium")!)
        utm_content = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "utm_content")!)
        utm_term = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "utm_term")!)
        notificationLoginID = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "notificationLoginID")!)
        status = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "status")!)
        openedDate = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "openedDate")!)
        actions = try container.decodeIfPresent([ActionButtons].self, forKey: DynamicCodingKeys(stringValue: "actions")!)
        pushCategory = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "pushCategory")!)
        keyID = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "keyID")!)
        email = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "email")!)
        deliver = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "deliver")!)
        silent = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "silent")!)

        // Bilinen parametrelerin bir setini oluşturma
        let knownKeys = Set(CodingKeys.allCases.map { $0.rawValue })

        // Tüm anahtarları döngüye alma ve bilinmeyenleri extraFields'a ekleme
        for key in container.allKeys {
            if !knownKeys.contains(key.stringValue) {
                let value = try container.decode(AnyCodable.self, forKey: key)
                extraFields[key.stringValue] = value.value
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        // Bilinen özellikleri encode etme
        try container.encodeIfPresent(formattedDateString, forKey: DynamicCodingKeys(stringValue: "formattedDateString")!)
        try container.encodeIfPresent(aps, forKey: DynamicCodingKeys(stringValue: "aps")!)
        try container.encodeIfPresent(altURL, forKey: DynamicCodingKeys(stringValue: "altURL")!)
        try container.encodeIfPresent(cid, forKey: DynamicCodingKeys(stringValue: "cid")!)
        try container.encodeIfPresent(url, forKey: DynamicCodingKeys(stringValue: "url")!)
        try container.encodeIfPresent(settings, forKey: DynamicCodingKeys(stringValue: "settings")!)
        try container.encodeIfPresent(pushType, forKey: DynamicCodingKeys(stringValue: "pushType")!)
        try container.encodeIfPresent(altUrl, forKey: DynamicCodingKeys(stringValue: "altUrl")!)
        try container.encodeIfPresent(mediaUrl, forKey: DynamicCodingKeys(stringValue: "mediaUrl")!)
        try container.encodeIfPresent(fcmOptions, forKey: DynamicCodingKeys(stringValue: "fcmOptions")!)
        try container.encodeIfPresent(deeplink, forKey: DynamicCodingKeys(stringValue: "deeplink")!)
        try container.encodeIfPresent(pushId, forKey: DynamicCodingKeys(stringValue: "pushId")!)
        try container.encodeIfPresent(emPushSp, forKey: DynamicCodingKeys(stringValue: "emPushSp")!)
        try container.encodeIfPresent(elements, forKey: DynamicCodingKeys(stringValue: "elements")!)
        try container.encodeIfPresent(utm_source, forKey: DynamicCodingKeys(stringValue: "utm_source")!)
        try container.encodeIfPresent(utm_campaign, forKey: DynamicCodingKeys(stringValue: "utm_campaign")!)
        try container.encodeIfPresent(utm_medium, forKey: DynamicCodingKeys(stringValue: "utm_medium")!)
        try container.encodeIfPresent(utm_content, forKey: DynamicCodingKeys(stringValue: "utm_content")!)
        try container.encodeIfPresent(utm_term, forKey: DynamicCodingKeys(stringValue: "utm_term")!)
        try container.encodeIfPresent(notificationLoginID, forKey: DynamicCodingKeys(stringValue: "notificationLoginID")!)
        try container.encodeIfPresent(status, forKey: DynamicCodingKeys(stringValue: "status")!)
        try container.encodeIfPresent(openedDate, forKey: DynamicCodingKeys(stringValue: "openedDate")!)
        try container.encodeIfPresent(actions, forKey: DynamicCodingKeys(stringValue: "actions")!)
        try container.encodeIfPresent(pushCategory, forKey: DynamicCodingKeys(stringValue: "pushCategory")!)
        try container.encodeIfPresent(keyID, forKey: DynamicCodingKeys(stringValue: "keyID")!)
        try container.encodeIfPresent(email, forKey: DynamicCodingKeys(stringValue: "email")!)
        try container.encodeIfPresent(deliver, forKey: DynamicCodingKeys(stringValue: "deliver")!)
        try container.encodeIfPresent(silent, forKey: DynamicCodingKeys(stringValue: "silent")!)

        // ExtraFields'daki değerleri doğrudan üst düzeyde encode etme
        for (key, value) in extraFields {
            let codingKey = DynamicCodingKeys(stringValue: key)!
            let anyCodableValue = AnyCodable(value)
            try container.encode(anyCodableValue, forKey: codingKey)
        }
    }

    // DynamicCodingKeys yapısı
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    
    public func getDate() -> Date? {
        guard let dateString = formattedDateString else {
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

    // MARK: - Aps
    public struct Aps: Codable {
        public let alert: Alert?
        public let category: String?
        public let sound: String?
        public let contentAvailable: Int?

        enum CodingKeys: String, CodingKey {
            case alert
            case category
            case sound
            case contentAvailable = "content-available"
        }
    }

    // MARK: - Alert
    public struct Alert: Codable {
        public let title: String?
        public let body: String?
    }

    // MARK: - FcmOptions
    public struct FcmOptions: Codable {
        public let image: String?
    }

    // MARK: - Element
    public struct Element: Codable {
        public let title: String?
        public let content: String?
        public let url: String?
        public let picture: String?
    }

    // MARK: - ActionButtons
    public struct ActionButtons: Codable {
        public let Title: String?
        public let Action: String?
        public let Icon: String?
        public let Url: String?
        public let AlternateUrl: String?
    }
}
