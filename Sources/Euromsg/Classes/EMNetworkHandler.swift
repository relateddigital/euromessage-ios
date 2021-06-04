//
//  EMNetworkHandler.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 7.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import Foundation

class EMNetworkHandler {

    private var euromsg: Euromsg!
    private var inProgressPushId: String?

    init() {}

    init(euromsg: Euromsg) {
        self.euromsg = euromsg
    }

    // MARK: Report Methods
    private func reportVisilabs(url: String) {
        euromsg.euromsgAPI?.request(urlString: url)
    }

    /// Reports recieved push to Euromsg services
    /// - Parameters:
    ///   - message: Push data
    ///   - status: Euromsg services push status ( euroReceivedStatus = "D",  euroReadStatus = "O" )
    internal func reportRetention(message: EMMessage, status: String) {
        guard let pushID = message.pushId, pushID != inProgressPushId else {
            return
        }
        inProgressPushId = pushID
        EMLog.info(message.encoded)
        guard let appKey = euromsg.subscription.appKey,
            let token = euromsg.subscription.token else {return}
        let request = EMRetentionRequest.init(key: appKey,
                                              token: token,
                                              status: status,
                                              pushId: pushID)
        DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(2)) { [weak self] in
            guard let self = self else { return }
            self.euromsg.euromsgAPI?.request(requestModel: request,
                                      completion: self.retentionRequestHandler)
        }
    }

    private func retentionRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMTools.removeUserDefaults(userKey: EMKey.euroLastMessageKey)
        case .failure:
            inProgressPushId = nil
        }
    }

    /// Controls locale storage for unreported changes on user data
    internal func checkUserUnreportedMessages() {
        let messageJson = EMTools.retrieveUserDefaults(userKey: EMKey.euroLastMessageKey) as? Data
        if let messageJson = messageJson {
            EMLog.info("Old message : \(messageJson)")
            let lastMessage =  try? JSONDecoder.init().decode(EMMessage.self, from: messageJson)
            if let lastMessage = lastMessage {
                reportRetention(message: lastMessage, status: EMKey.euroReadStatus)
            }
        }
    }

}
