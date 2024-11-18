//
//  EMUserDefaultsUtils.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 8.09.2021.
//

import Foundation

class EMUserDefaultsUtils {
    
    // MARK: - UserDefaults
    
    static let userDefaults = UserDefaults(suiteName: EMKey.userDefaultSuiteKey)
    static var appGroupUserDefaults : UserDefaults?
    
    static func setAppGroupsUserDefaults(appGroupName: String) {
        appGroupUserDefaults = UserDefaults(suiteName: appGroupName)
    }
    
    static func retrieveUserDefaults(userKey: String) -> AnyObject? {
        var val: Any?
        if let value = appGroupUserDefaults?.object(forKey: userKey) {
            val = value
        }
        else if let value = userDefaults?.object(forKey: userKey) {
            val = value
        }
        guard let value = val else {
            return nil
        }
        return value as AnyObject?
    }
    
    static func removeUserDefaults(userKey: String) {
        if userDefaults?.object(forKey: userKey) != nil {
            userDefaults?.removeObject(forKey: userKey)
            userDefaults?.synchronize()
        }
        if appGroupUserDefaults?.object(forKey: userKey) != nil {
            appGroupUserDefaults?.removeObject(forKey: userKey)
            appGroupUserDefaults?.synchronize()
        }
    }
    
    static func saveUserDefaults(key: String?, value: AnyObject?) {
        guard let key = key, let value = value else {
            print("Key or value is nil. Skipping save operation.")
            return
        }

        userDefaults?.set(value, forKey: key)
        userDefaults?.synchronize()
        appGroupUserDefaults?.set(value, forKey: key)
        appGroupUserDefaults?.synchronize()
    }
    
    // MARK: - Retention
    
    private static let pushIdLock = EMReadWriteLock(label: "EMPushIdLock")
    
    static func saveReadPushId(pushId: String) {
        var pushIdList = getReadPushIdList()
        pushIdLock.write {
            if !pushIdList.contains(pushId) {
                pushIdList.append(pushId)
                if let pushIdListData = try? JSONEncoder().encode(pushIdList) {
                    saveUserDefaults(key: EMKey.euroReadPushIdListKey, value: pushIdListData as AnyObject)
                } else {
                    EMLog.warning("Can not encode pushIdList : \(String(describing: pushIdList))")
                }
            } else {
                EMLog.warning("PushId already exists. pushId: \(pushId)")
            }
        }
    }
    
    static func getReadPushIdList() -> [String] {
        var finalPushIdList = [String]()
        pushIdLock.read {
            if let pushIdListJsonData = retrieveUserDefaults(userKey: EMKey.euroReadPushIdListKey) as? Data {
                if let pushIdList = try? JSONDecoder().decode([String].self, from: pushIdListJsonData) {
                    finalPushIdList = pushIdList
                }
            }
        }
        return Array(finalPushIdList.suffix(50))
    }
    
    static func pushIdListContains(pushId: String) -> Bool {
        return getReadPushIdList().contains(pushId)
    }
    
    // MARK: - Deliver
    
    private static let payloadLock = EMReadWriteLock(label: "EMPayloadLock")
    
    static func savePayload(payload: EMMessage) {
        var payload = payload
        if let pushId = payload.pushId {
            payload.formattedDateString = EMTools.formatDate(Date())
            payload.openedDate = ""
            payload.status = "D"
            if let extra = Euromsg.shared?.subscription.extra {
                if extra["keyID"] != nil {
                    payload.keyID = extra["keyID"]
                }
                if extra["email"] != nil {
                    payload.email = extra["email"]
                }
            }
            var recentPayloads = getRecentPayloads()
            payloadLock.write {
                if let existingPayload = recentPayloads.first(where: { $0.pushId == pushId }) {
                    EMLog.warning("Payload is not valid, there is already another payload with same pushId  New : \(payload.encoded) Existing: \(existingPayload.encoded)")
                } else {
                    recentPayloads.insert(payload, at: 0)
                    if let recentPayloadsData = try? JSONEncoder().encode(recentPayloads) {
                        saveUserDefaults(key: EMKey.euroPayloadsKey, value: recentPayloadsData as AnyObject)
                    } else {
                        EMLog.warning("Can not encode recentPayloads : \(String(describing: recentPayloads))")
                    }
                }
            }
        } else {
            EMLog.warning("Payload is not valid, pushId missing : \(payload.encoded)")
        }
    }
    
    static func savePayloadWithId(payload: EMMessage, notificationLoginID: String) {
        var payload = payload
        if let pushId = payload.pushId, !notificationLoginID.isEmpty {
            payload.notificationLoginID = notificationLoginID
            payload.formattedDateString = EMTools.formatDate(Date())
            payload.openedDate = ""
            payload.status = "D"
            if let extra = Euromsg.shared?.subscription.extra {
                if extra["keyID"] != nil {
                    payload.keyID = extra["keyID"]
                }
                if extra["email"] != nil {
                    payload.email = extra["email"]
                }
            }
            var recentPayloads = getRecentPayloadsWithId()
            payloadLock.write {
                if let existingPayload = recentPayloads.first(where: { $0.pushId == pushId }) {
                    EMLog.warning("Payload is not valid, there is already another payload with same pushId  New : \(payload.encoded) Existing: \(existingPayload.encoded)")
                } else {
                    recentPayloads.insert(payload, at: 0)
                    if let recentPayloadsData = try? JSONEncoder().encode(recentPayloads) {
                        saveUserDefaults(key: EMKey.euroPayloadsWithIdKey, value: recentPayloadsData as AnyObject)
                    } else {
                        EMLog.warning("Can not encode recentPayloads : \(String(describing: recentPayloads))")
                    }
                }
            }
        } else {
            EMLog.warning("Payload is not valid, pushId missing : \(payload.encoded)")
        }
    }
    
    static func deletePayloadWithId(pushId: String? = nil, completion: @escaping (Bool) -> Void) {
            let emptyPayloads: [EMMessage] = []
            var recentPayloads = getRecentPayloadsWithId()
            payloadLock.write {
                
                guard let pushId = pushId, let index = recentPayloads.firstIndex(where: { $0.pushId == pushId }) else {
                    do {
                        let emptyData = try JSONEncoder().encode(emptyPayloads)
                        saveUserDefaults(key: EMKey.euroPayloadsWithIdKey, value: emptyData as AnyObject)
                        EMLog.info("All payloads have been deleted successfully.")
                        completion(true)
                    } catch {
                        EMLog.warning("Cannot encode empty payloads: \(error.localizedDescription)")
                        completion(false)
                    }
                    return
                }
                
                recentPayloads.remove(at: index)
                
                do {
                    let updatedData = try JSONEncoder().encode(recentPayloads)
                    saveUserDefaults(key: EMKey.euroPayloadsWithIdKey, value: updatedData as AnyObject)
                    EMLog.info("Push with id \(pushId) was deleted")
                    completion(true)
                } catch {
                    EMLog.warning("Cannot encode recentPayloads after deletion: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }

        static func deletePayload(pushId: String? = nil, completion: @escaping (Bool) -> Void) {
            let emptyPayloads: [EMMessage] = []
            var recentPayloads = getRecentPayloads()
            payloadLock.write {
                
                guard let pushId = pushId, let index = recentPayloads.firstIndex(where: { $0.pushId == pushId }) else {
                    // PushId bulunamadı, tüm payload'ları temizliyoruz
                    do {
                        let emptyData = try JSONEncoder().encode(emptyPayloads)
                        saveUserDefaults(key: EMKey.euroPayloadsKey, value: emptyData as AnyObject)
                        EMLog.info("All payloads have been deleted successfully.")
                        completion(true)
                    } catch {
                        EMLog.warning("Cannot encode empty payloads: \(error.localizedDescription)")
                        completion(false)
                    }
                    return
                }
                
                recentPayloads.remove(at: index)
                
                do {
                    let updatedData = try JSONEncoder().encode(recentPayloads)
                    saveUserDefaults(key: EMKey.euroPayloadsKey, value: updatedData as AnyObject)
                    EMLog.info("Push with id \(pushId) was deleted")
                    completion(true)
                } catch {
                    EMLog.warning("Cannot encode recentPayloads after deletion: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    
    static func updatePayload(pushId: String?) {
        var recentPayloads = getRecentPayloads()
        payloadLock.write {
            if let index = recentPayloads.firstIndex(where: { $0.pushId == pushId }) {
                var updatedPayload = recentPayloads[index]
                // Güncelleme işlemlerini yap
                updatedPayload.status = "O"
                updatedPayload.openedDate = EMTools.formatDate(Date())
                // Güncellenmiş payload'ı koleksiyona tekrar ekle
                recentPayloads[index] = updatedPayload
                if let updatedPayloadsData = try? JSONEncoder().encode(recentPayloads) {
                    saveUserDefaults(key: EMKey.euroPayloadsKey, value: updatedPayloadsData as AnyObject)
                } else {
                    EMLog.warning("Can not encode updated payloads: \(String(describing: recentPayloads))")
                }
            } else {
                EMLog.warning("Payload with pushId \(pushId ?? "") not found in recent payloads.")
            }
        }
    }
    
    static func readAllPushMessages(pushId: String? = nil, completion: @escaping ((_ success: Bool) -> Void)){
        var recentPayloads = getRecentPayloads()
        payloadLock.write {
            if let pushId = pushId {
                if let index = recentPayloads.firstIndex(where: { $0.pushId == pushId }) {
                    var updatedPayload = recentPayloads[index]
                    updatedPayload.status = "O"
                    updatedPayload.openedDate = EMTools.formatDate(Date())
                    recentPayloads[index] = updatedPayload
                } else {
                    // Belirtilen pushId'ye sahip bir öğe bulunamadı
                    EMLog.warning("Push message with pushId \(pushId) not found.")
                    completion(false)
                    return // İşlemi sonlandır ve devam etme
                }
            } else {
                for index in 0..<recentPayloads.count {
                    var updatedPayload = recentPayloads[index]
                    updatedPayload.status = "O"
                    updatedPayload.openedDate = EMTools.formatDate(Date())
                    recentPayloads[index] = updatedPayload
                }
            }
            if let updatedPayloadsData = try? JSONEncoder().encode(recentPayloads) {
                saveUserDefaults(key: EMKey.euroPayloadsKey, value: updatedPayloadsData as AnyObject)
                completion(true)
            } else {
                EMLog.warning("Can not encode updated payloads: \(String(describing: recentPayloads))")
                completion(false)
            }
        }
    }
    
    static func getRecentPayloadsWithId() -> [EMMessage] {
        var finalPayloads = [EMMessage]()
        payloadLock.read {
            guard let notificationLoginId = retrieveUserDefaults(userKey: EMKey.notificationLoginIdKey) as? String,
                  !notificationLoginId.isEmpty else {
                EMLog.error("EM-getRecentPayloadsWithId() : login ID is empty!");
                return
            }
            
            if let payloadsJsonData = retrieveUserDefaults(userKey: EMKey.euroPayloadsWithIdKey) as? Data {
                if let payloads = try? JSONDecoder().decode([EMMessage].self, from: payloadsJsonData) {
                    finalPayloads = payloads
                }
            }
            if let filterDate = Calendar.current.date(byAdding: .day, value: -EMKey.payloadDayThreshold, to: Date()) {
                finalPayloads = finalPayloads.filter({ payload in
                    
                    if payload.notificationLoginID != notificationLoginId {
                        return false
                    }
                    
                    if let date = payload.getDate() {
                        return date > filterDate
                    } else {
                        return false
                    }
                })
            }
        }
        return finalPayloads.sorted(by: { payload1, payload2 in
            if let date1 = payload1.getDate(), let date2 = payload2.getDate() {
                return date1 > date2
            } else {
                return false
            }
        })
    }
    
    
    static func getRecentPayloads() -> [EMMessage] {
        var finalPayloads = [EMMessage]()
        payloadLock.read {
            if let payloadsJsonData = retrieveUserDefaults(userKey: EMKey.euroPayloadsKey) as? Data {
                if let payloads = try? JSONDecoder().decode([EMMessage].self, from: payloadsJsonData) {
                    finalPayloads = payloads
                }
            }
            if let filterDate = Calendar.current.date(byAdding: .day, value: -EMKey.payloadDayThreshold, to: Date()) {
                finalPayloads = finalPayloads.filter({ payload in
                    if let date = payload.getDate() {
                        return date > filterDate
                    } else {
                        return false
                    }
                })
            }
        }
        return finalPayloads.sorted(by: { payload1, payload2 in
            if let date1 = payload1.getDate(), let date2 = payload2.getDate() {
                return date1 > date2
            } else {
                return false
            }
        })
    }
    
    static func payloadContains(pushId: String) -> Bool {
        let payloads = getRecentPayloads()
        return payloads.first(where: { $0.pushId == pushId }) != nil
    }
    
    // MARK: - Subscription
    
    private static let subscriptionLock = EMReadWriteLock(label: "EMSubscriptionLock")
    
    static func saveLastSuccessfulSubscriptionTime(time: Date) {
        subscriptionLock.write {
            saveUserDefaults(key: EMKey.euroLastSuccessfulSubscriptionDateKey, value: time as AnyObject)
        }
    }
    
    static func getLastSuccessfulSubscriptionTime() -> Date {
        var lastSuccessfulSubscriptionTime = Date(timeIntervalSince1970: 0)
        subscriptionLock.read {
            if let date = retrieveUserDefaults(userKey: EMKey.euroLastSuccessfulSubscriptionDateKey) as? Date {
                lastSuccessfulSubscriptionTime = date
            }
        }
        return lastSuccessfulSubscriptionTime
    }
    
    static func saveLastSuccessfulSubscription(subscription: EMSubscriptionRequest) {
        subscriptionLock.write {
            if let subscriptionData = try? JSONEncoder().encode(subscription) {
                saveUserDefaults(key: EMKey.euroLastSuccessfulSubscriptionKey, value: subscriptionData as AnyObject)
            } else {
                EMLog.error("EMUserDefaultsUtils saveLastSuccessfulSubscription encode error.")
            }
        }
    }
    
    static func getLastSuccessfulSubscription() -> EMSubscriptionRequest? {
        var lastSuccessfulSubscription: EMSubscriptionRequest?
        subscriptionLock.read {
            if let lastSuccessfulSubscriptionData = retrieveUserDefaults(userKey: EMKey.euroLastSuccessfulSubscriptionKey) as? Data {
                if let subscription = try? JSONDecoder().decode(EMSubscriptionRequest.self, from: lastSuccessfulSubscriptionData) {
                    lastSuccessfulSubscription = subscription
                } else {
                    EMLog.error("EMUserDefaultsUtils getLastSuccessfulSubscription decode error.")
                }
            }
        }
        return lastSuccessfulSubscription
    }
    
}
