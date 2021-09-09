//
//  EMPayloadUtils.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 8.09.2021.
//

import Foundation

class EMPayloadUtils {

    static func savePayload(payload: EMMessage) {
        var payload = payload
        if let pushId = payload.pushId {
            payload.formattedDateString = EMTools.formatDate(Date())
            var recentPayloads = getRecentPayloads()
            if let existingPayload = recentPayloads.first(where: { $0.pushId == pushId }) {
                EMLog.warning("Payload is not valid, there is already another payload with same pushId  New : \(payload.encoded) Existing: \(existingPayload.encoded)")
            } else {
                recentPayloads.insert(payload, at: 0)
                if let recentPayloadsData = try? JSONEncoder().encode(recentPayloads) {
                    EMTools.saveUserDefaults(key: EMKey.euroPayloadsKey, value: recentPayloadsData as AnyObject)
                } else {
                    EMLog.warning("Can not encode recentPayloads : \(String(describing: recentPayloads))")
                }
            }
        } else {
            EMLog.warning("Payload is not valid, pushId missing : \(payload.encoded)")
        }
    }

    static func getRecentPayloads() -> [EMMessage] {
        var finalPayloads = [EMMessage]()
        if let payloadsJsonData = EMTools.retrieveUserDefaults(userKey: EMKey.euroPayloadsKey) as? Data {
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
        return finalPayloads.sorted(by: { payload1, payload2 in
            if let date1 = payload1.getDate(), let date2 = payload2.getDate() {
                return date1 > date2
            } else {
                return false
            }
        })
    }

}
