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
            EMLog.error("EMDeliverHandler reportDeliver appKey or token does not exist")
            return
        }
        
        var request: EMRetentionRequest?
        
        guard let pushID = message.pushId, let emPushSp = message.emPushSp else {
            EMLog.warning("EMDeliverHandler pushId or emPushSp is empty")
            return
        }
        
        if EMUserDefaultsUtils.payloadContains(pushId: pushID) {
            EMLog.warning("EMDeliverHandler pushId already sent.")
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
            EMLog.info("reportDeliver: \(message.encoded)")
            if silent == true {
                request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroSilentStatus, pushId: pushID, emPushSp: emPushSp)
            } else {
                request = EMRetentionRequest(key: appKey, token: token, status: EMKey.euroReceivedStatus, pushId: pushID, emPushSp: emPushSp)
            }
            
        }
        
        if let request = request {
            self.euromsg.euromsgAPI?.request(requestModel: request, retry: 3, completion: self.deliverRequestHandler)
        }
    }
    
    private func deliverRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.euroLastMessageKey)
        case .failure:
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
