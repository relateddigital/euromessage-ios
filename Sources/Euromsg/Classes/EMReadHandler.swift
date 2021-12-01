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
            EMLog.error("EMReadHandler reportRead appKey or token does not exist")
            return
        }
        
        var request: EMRetentionRequest?
        
        guard let pushID = message.pushId, let emPushSp = message.emPushSp else {
            EMLog.warning("EMReadHandler pushId or emPushSp is empty")
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
            EMLog.info("reportRead: \(message.encoded)")
            request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroReadStatus, pushId: pushID, emPushSp: emPushSp)
        }
        
        if let request = request {
            DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(2)) { [weak self] in
                guard let self = self else { return }
                self.euromsg.euromsgAPI?.request(requestModel: request, retry: 3, completion: self.readRequestHandler)
            }
        }
    }
    
    private func readRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMTools.removeUserDefaults(userKey: EMKey.euroLastMessageKey)
        case .failure:
            if let emMessage = emMessage, let emMessageData = try? JSONEncoder().encode(emMessage) {
                EMTools.saveUserDefaults(key: EMKey.euroLastMessageKey, value: emMessageData as AnyObject)
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
        let messageJson = EMTools.retrieveUserDefaults(userKey: EMKey.euroLastMessageKey) as? Data
        if let messageJson = messageJson {
            EMLog.info("Old message : \(messageJson)")
            let lastMessage = try? JSONDecoder().decode(EMMessage.self, from: messageJson)
            if let lastMessage = lastMessage {
                reportRead(message: lastMessage)
            }
        }
    }
}
