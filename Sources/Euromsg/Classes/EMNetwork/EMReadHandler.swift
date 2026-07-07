//
//  EMReadHandler.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 7.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

class EMReadHandler {
    private let readWriteLock: EMReadWriteLock
    var euromsg: Euromsg!
    private var inProgressPushId: String?
    private var inProgressEmPushSp: String?
    private var emMessage: EMMessage?
    
    
    init(euromsg: Euromsg) {
        self.euromsg = euromsg
        self.readWriteLock = EMReadWriteLock(label: "EMReadHandler")
    }
    
    // MARK: Report Methods
    
    /// Reports recieved push to Euromsg services
    /// - Parameters:
    ///   - message: Push data
    internal func reportRead(message: EMMessage) {
        
        guard let appKey = euromsg.subscription.appKey, let token = euromsg.subscription.token else {
            Euromsg.pushError("ReadHandler appKey(\(euromsg.subscription.appKey == nil ? "nil" : "ok")) or token(\(euromsg.subscription.token == nil ? "nil" : "ok")) missing, read report SKIPPED for pushId: \(message.pushId ?? "nil")")
            return
        }

        var request: EMRetentionRequest?

        guard let pushID = message.pushId, let emPushSp = message.emPushSp else {
            Euromsg.pushWarning("ReadHandler pushId(\(message.pushId ?? "nil")) or emPushSp(\(message.emPushSp ?? "nil")) is empty, read report SKIPPED")
            return
        }

        if EMUserDefaultsUtils.pushIdListContains(pushId: pushID) {
            Euromsg.pushTrace("ReadHandler pushId \(pushID) already reported, skipping duplicate")
            return
        }
        
        var isRequestValid = true
        
        self.readWriteLock.read {
            if pushID == inProgressPushId && emPushSp == inProgressEmPushSp  {
                isRequestValid = false
            }
        }
        
        if !isRequestValid {
            EMLog.warning("EMReadHandler request not valid. Retention request with pushId: \(pushID) and emPushSp \(emPushSp) already sent.")
            return
        }
        
        self.readWriteLock.write {
            inProgressPushId = pushID
            inProgressEmPushSp = emPushSp
            emMessage = message
            EMLog.info("reportRead: \(message.encode ?? "")")
            request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroReadStatus, pushId: pushID, emPushSp: emPushSp)
        }
        
        if let request = request {
            Euromsg.pushTrace("ReadHandler sending read report. pushId: \(pushID)")
            self.euromsg.euromsgAPI?.request(requestModel: request, retry: 3, completion: self.readRequestHandler)
        }
    }

    private func readRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            Euromsg.pushTrace("ReadHandler read report sent successfully. pushId: \(inProgressPushId ?? "nil")")
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.euroLastMessageKey)
            if let pushId = inProgressPushId {
                EMUserDefaultsUtils.saveReadPushId(pushId: pushId)
            }
        case let .failure(error):
            Euromsg.pushError("ReadHandler read report FAILED after retries: \(error). pushId: \(inProgressPushId ?? "nil"), payload saved for later retry")
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
    
    /// Controls locale storage for unreported changes on user data
    internal func checkUserUnreportedMessages() {
        let messageJson = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.euroLastMessageKey) as? Data
        if let messageJson = messageJson {
            EMLog.info("Old message : \(messageJson)")
            let lastMessage = try? JSONDecoder().decode(EMMessage.self, from: messageJson)
            if let lastMessage = lastMessage {
                reportRead(message: lastMessage)
            }
        }
    }
}
