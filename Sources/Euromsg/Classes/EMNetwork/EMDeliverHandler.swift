//
//  EMDeliverHandler.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 8.09.2021.
//

import Foundation

class EMDeliverHandler {
    private let readWriteLock: EMReadWriteLock
    var euromsg: Euromsg!
    private var inProgressPushId: String?
    private var inProgressEmPushSp: String?
    private var emMessage: EMMessage?
    
    
    init(euromsg: Euromsg) {
        self.euromsg = euromsg
        self.readWriteLock = EMReadWriteLock(label: "EMDeliverHandler")
    }
        
    /// Reports delivered push to Euromsg services
    /// - Parameters:
    ///   - message: Push data
    internal func reportDeliver(message: EMMessage, silent: Bool? = false) {
        guard let appKey = euromsg.subscription.appKey, let token = euromsg.subscription.token else {
            Euromsg.pushError("DeliverHandler appKey(\(euromsg.subscription.appKey == nil ? "nil" : "ok")) or token(\(euromsg.subscription.token == nil ? "nil" : "ok")) missing, deliver report SKIPPED for pushId: \(message.pushId ?? "nil"). If token is nil in the extension, check App Groups setup.")
            return
        }

        var request: EMRetentionRequest?

        guard let pushID = message.pushId, let emPushSp = message.emPushSp else {
            Euromsg.pushWarning("DeliverHandler pushId(\(message.pushId ?? "nil")) or emPushSp(\(message.emPushSp ?? "nil")) is empty, deliver report SKIPPED")
            return
        }

        if EMUserDefaultsUtils.payloadContains(pushId: pushID) {
            Euromsg.pushTrace("DeliverHandler pushId \(pushID) already reported, skipping duplicate")
            return
        }
        
        var isRequestValid = true
        
        self.readWriteLock.read {
            if pushID == inProgressPushId && emPushSp == inProgressEmPushSp  {
                isRequestValid = false
            }
        }
        
        if !isRequestValid {
            EMLog.warning("EMDeliverHandler request not valid. Retention request with pushId: \(pushID) and emPushSp \(emPushSp) already sent.")
            return
        }
        
        self.readWriteLock.write {
            inProgressPushId = pushID
            inProgressEmPushSp = emPushSp
            emMessage = message
            EMLog.info("reportDeliver: \(message.encode ?? "")")
            if silent == true {
                request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroSilentStatus, pushId: pushID, emPushSp: emPushSp)
            } else {
                request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroReceivedStatus, pushId: pushID, emPushSp: emPushSp)
            }
            
        }
        
        if let request = request {
            Euromsg.pushTrace("DeliverHandler sending deliver report. pushId: \(pushID), status: \(silent == true ? EMKey.euroSilentStatus : EMKey.euroReceivedStatus)")
            self.euromsg.euromsgAPI?.request(requestModel: request, retry: 3, completion: self.deliverRequestHandler)
        }
    }

    private func deliverRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            Euromsg.pushTrace("DeliverHandler deliver report sent successfully. pushId: \(inProgressPushId ?? "nil")")
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.euroLastMessageKey)
        case let .failure(error):
            Euromsg.pushError("DeliverHandler deliver report FAILED after retries: \(error). pushId: \(inProgressPushId ?? "nil"), payload saved for later retry")
            if let emMessage = emMessage, let emMessageData = try? JSONEncoder().encode(emMessage) {
                EMUserDefaultsUtils.saveUserDefaults(key: EMKey.euroLastMessageKey, value: emMessageData as AnyObject)
            }
            self.readWriteLock.write {
                inProgressPushId = nil
                inProgressEmPushSp = nil
                emMessage = nil
            }
        }
    }
}
