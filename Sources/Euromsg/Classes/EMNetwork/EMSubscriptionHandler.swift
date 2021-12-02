//
//  EMSubscriptionHandler.swift
//  Euromsg
//
//  Created by Egemen Gülkılık on 1.12.2021.
//

import Foundation

class EMSubscriptionHandler {
    
    var euromsg: Euromsg!
    
    private let semaphore = DispatchSemaphore(value: 0)
    private let readWriteLock: EMReadWriteLock
    private var inProgressSubscriptionRequest: EMSubscriptionRequest?
    
    init(euromsg: Euromsg) {
        self.euromsg = euromsg
        self.readWriteLock = EMReadWriteLock(label: "EMSubscriptionHandler")
    }
    
    /// Reports user, device data and APNS token to Euromsg services
    /// - Parameters:
    ///   - subscription: Subscription data
    internal func reportSubscription(subscriptionRequest: EMSubscriptionRequest) {
        guard let _ = subscriptionRequest.appKey, let _ = subscriptionRequest.token else {
            EMLog.error("EMSubscriptionHandler reportSubscription appKey or token does not exist")
            return
        }
        
        var isRequestSame = false
        var isRequestSameAsLastSuccessfulSubscriptionRequest = false
        self.readWriteLock.read {
            if subscriptionRequest == inProgressSubscriptionRequest {
                isRequestSame = true
            }
            if let lastSuccessfulSubscriptionRequest = EMUserDefaultsUtils.getLastSuccessfulSubscription()
                , EMUserDefaultsUtils.getLastSuccessfulSubscriptionTime().addingTimeInterval(TimeInterval(EMKey.threeDaysInSeconds)) > Date()
                , lastSuccessfulSubscriptionRequest == subscriptionRequest {
                isRequestSameAsLastSuccessfulSubscriptionRequest = true
            }
        }
                
        if isRequestSame {
            EMLog.info("EMSubscriptionHandler request is not valid. EMSubscriptionRequest is the same as the previous one.")
            return
        }
        
        if isRequestSameAsLastSuccessfulSubscriptionRequest {
            EMLog.info("EMSubscriptionHandler request is not valid. EMSubscriptionRequest is the same as the lastSuccessfulSubscription.")
            return
        }
        
        self.readWriteLock.write {
            inProgressSubscriptionRequest = subscriptionRequest
            EMLog.info("EMSubscriptionHandler reportSubscription: \(subscriptionRequest.encoded)")
        }
        
        euromsg.euromsgAPI?.request(requestModel: subscriptionRequest, retry: 3, completion: self.subscriptionRequestHandler)
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
    }
    
    private func subscriptionRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            euromsg.delegate?.didRegisterSuccessfully()
            if let subscriptionRequest = inProgressSubscriptionRequest {
                EMLog.success("EMSubscriptionHandler: Request successfully send, token: \(String(describing: subscriptionRequest.token))")
                EMUserDefaultsUtils.saveLastSuccessfulSubscriptionTime(time: Date())
                EMUserDefaultsUtils.saveLastSuccessfulSubscription(subscription: subscriptionRequest)
            }
        case .failure(let error):
            EMLog.error("EMSubscriptionHandler: Request failed : \(error)")
            euromsg.delegate?.didFailRegister(error: error)
        }
        self.readWriteLock.write {
            inProgressSubscriptionRequest = nil
        }
        semaphore.signal()
    }
    
    
    
}

