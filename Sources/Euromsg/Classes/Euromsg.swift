//
//  Euromsg.swift
//  
//
//  Created by Muhammed ARAFA on 27.03.2020.
//

import Foundation
import UIKit

protocol EuromsgDelegate: AnyObject {
    func didRegisterSuccessfully()
    func didFailRegister(error: EuromsgAPIError)
}

public class Euromsg {

    private static var sharedInstance: Euromsg?
    private let readWriteLock: EMReadWriteLock
    internal var euromsgAPI: EuromsgAPIProtocol?
    private var observers: [NSObjectProtocol]?
    internal var emReadHandler: EMReadHandler?
    internal var emDeliverHandler: EMDeliverHandler?
    private var pushPermitDidCall: Bool = false
    weak var delegate: EuromsgDelegate?
    internal var subscription: EMSubscriptionRequest
    internal var graylog: EMGraylogRequest
    private static var previousSubscription: EMSubscriptionRequest?
    private var previousRegisterEmailSubscription: EMSubscriptionRequest?
    internal var userAgent: String? = nil 

    private init(appKey: String) {
        EMLog.info("INITCALL \(appKey)")
        self.readWriteLock = EMReadWriteLock(label: "EuromsgLock")
        if let lastSubscriptionData = EMTools.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data,
           let lastSubscription = try? JSONDecoder().decode(EMSubscriptionRequest.self, from: lastSubscriptionData) {
            subscription = lastSubscription
        } else {
            subscription = EMSubscriptionRequest()
        }
        subscription.setDeviceParameters()
        subscription.appKey = appKey
        subscription.token = EMTools.retrieveUserDefaults(userKey: EMKey.tokenKey) as? String
        
        graylog = EMGraylogRequest()
        fillGraylogModel()
        
        let ncd = NotificationCenter.default
        observers = []
        observers?.append(ncd.addObserver(
                            forName: UIApplication.willResignActiveNotification,
                            object: nil,
                            queue: nil,
                            using: Euromsg.sync))
        observers?.append(ncd.addObserver(
                            forName: UIApplication.willTerminateNotification,
                            object: nil,
                            queue: nil,
                            using: Euromsg.sync))
        observers?.append(ncd.addObserver(
                            forName: UIApplication.willEnterForegroundNotification,
                            object: nil,
                            queue: nil,
                            using: Euromsg.sync))
        observers?.append(ncd.addObserver(
                            forName: UIApplication.didBecomeActiveNotification,
                            object: nil,
                            queue: nil,
                            using: Euromsg.sync))
        
        
        
        setUserAgent()
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willResignActiveNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willTerminateNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didBecomeActiveNotification,
                                                  object: nil)
    }
    
    static func sharedUIApplication() -> UIApplication? {
        let shared = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue()
        guard let sharedApplication = shared as? UIApplication else {
            return nil
        }
        return sharedApplication
    }

    private static func getShared() -> Euromsg? {
        guard let shared = Euromsg.shared else {
            EMLog.warning(EMKey.appAliasNotProvidedMessage)
            return nil
        }
        return shared
    }

    public static var shared: Euromsg? {
        get {
            guard sharedInstance?.subscription.appKey != nil,
                  sharedInstance?.subscription.appKey != "" else {
                if let subscriptionData = EMTools.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data {
                    guard let subscriptionRequest = try? JSONDecoder().decode(EMSubscriptionRequest.self, from: subscriptionData),
                          let appKey = subscriptionRequest.appKey else {
                        EMLog.warning(EMKey.appAliasNotProvidedMessage)
                        return nil
                    }
                    Euromsg.configure(appAlias: appKey)
                    return sharedInstance
                }
                EMLog.warning(EMKey.appAliasNotProvidedMessage)
                return nil
            }
            return sharedInstance
        }
        set {
            sharedInstance = newValue
        }
    }

    // MARK: Lifecycle
    public class func configure(appAlias: String, enableLog: Bool = false, appGroupsKey: String? = nil) {
        
        if let appGroupName = EMTools.getAppGroupName(appGroupName: appGroupsKey) {
            EMTools.setAppGroupsUserDefaults(appGroupName: appGroupName)
            EMLog.info("App Group Key : \(appGroupName)")
        }
        
        Euromsg.shared = Euromsg(appKey: appAlias)
        EMLog.shared.isEnabled = enableLog
        Euromsg.shared?.euromsgAPI = EuromsgAPI()
        Euromsg.shared?.emReadHandler = EMReadHandler(euromsg: Euromsg.shared!)
        Euromsg.shared?.emDeliverHandler = EMDeliverHandler(euromsg: Euromsg.shared!)

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } else {
            // If ios version is lower than 10, server should send 0 badge push notification to clear all.
        }
    }

    /// Request to user for authorization for push notification
    /// - Parameter register: also register for deviceToken. _default : false_
    public static func askForNotificationPermission(register: Bool = false) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                EMLog.success("Notification permission granted")
                if register {
                    Euromsg.registerForPushNotifications()
                }
            } else {
                EMLog.error("An error occurred while notification permission: \(error.debugDescription)")
            }
        }
    }

    public static func askForNotificationPermissionProvisional(register: Bool = false) {
        if #available(iOS 12.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
                if granted {
                    EMLog.success("Notification permission granted")
                    if register {
                        Euromsg.registerForPushNotifications()
                    }
                } else {
                    EMLog.error("An error occurred while notification permission: \(error.debugDescription)")
                }
            }
        } else {
            Euromsg.askForNotificationPermission(register: register)
        }
    }

    public static func registerForPushNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func setUserAgent() {
        if let userAgent = EMTools.retrieveUserDefaults(userKey: EMKey.userAgent) as? String {
            self.userAgent = userAgent
        } else {
            EMTools.computeWebViewUserAgent { str in
                self.userAgent = str
                EMTools.saveUserDefaults(key: EMKey.userAgent, value: str as AnyObject)
            }
        }
    }
}

extension Euromsg {

    // MARK: Request Builders

    public static func setPushNotification(permission: Bool) {
        if permission {
            setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.yes.rawValue)
            registerForPushNotifications()
        } else {
            setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.not.rawValue)
        }
        shared?.pushPermitDidCall = true
        sync()
    }

    public static func setPhoneNumber(msisdn: String? = nil, permission: Bool) {
        let per = permission ? EMProperties.PermissionKeys.yes.rawValue : EMProperties.PermissionKeys.not.rawValue
        setUserProperty(key: EMProperties.CodingKeys.gsmPermit.rawValue, value: per)
        if EMTools.validatePhone(phone: msisdn), permission {
            setUserProperty(key: EMProperties.CodingKeys.msisdn.rawValue, value: msisdn)
        }
    }

    public static func setEmail(email: String? = nil, permission: Bool) {
        let per = permission ? EMProperties.PermissionKeys.yes.rawValue : EMProperties.PermissionKeys.not.rawValue
        setUserProperty(key: EMProperties.CodingKeys.emailPermit.rawValue, value: per)
        if EMTools.validateEmail(email: email), permission {
            setUserProperty(key: EMProperties.CodingKeys.email.rawValue, value: email)
        }
    }
    
    public static func setEmail(email: String?) {
        if EMTools.validateEmail(email: email) {
            setUserProperty(key: EMProperties.CodingKeys.email.rawValue, value: email)
        }
    }

    public static func setEuroUserId(userKey: String?) {
        if let userKey = userKey {
            setUserProperty(key: EMProperties.CodingKeys.keyID.rawValue, value: userKey)
        }
    }

    public static func setAppVersion(appVersion: String?) {
        guard let shared = getShared() else { return }
        if let appVersion = appVersion {
            shared.readWriteLock.write {
                shared.subscription.appVersion = appVersion
            }
        }
        saveSubscription()
    }

    public static func setTwitterId(twitterId: String?) {
        if let twitterId = twitterId {
            setUserProperty(key: EMProperties.CodingKeys.twitter.rawValue, value: twitterId)
        }
    }

    public static func setAdvertisingIdentifier(adIdentifier: String?) {
        guard let shared = getShared() else { return }
        if let adIdentifier = adIdentifier {
            shared.readWriteLock.write {
                shared.subscription.advertisingIdentifier = adIdentifier
            }
        }
        saveSubscription()
    }

    public static func setFacebook(facebookId: String?) {
        if let facebookId = facebookId {
            setUserProperty(key: EMProperties.CodingKeys.facebook.rawValue, value: facebookId)
        }
    }

    public static func setUserProperty(key: String, value: String?) {
        if let shared = getShared(), let value = value {
            shared.readWriteLock.write {
                shared.subscription.extra?[key] = value
            }
            saveSubscription()
        }
    }
    
    public static func removeUserProperty(key: String) {
        if let shared = getShared(){
            shared.readWriteLock.write {
                shared.subscription.extra?[key] = nil
            }
            saveSubscription()
        }
    }

    public static func logout() {
        if let shared = getShared() {
            shared.readWriteLock.write {
                shared.subscription.token = nil
                shared.subscription.extra = [String: String]()
            }
            EMTools.removeUserDefaults(userKey: EMKey.tokenKey) // TODO: burada niye token var, android'de token silme yok
            // EMTools.removeUserDefaults(userKey: EMKey.registerKey) // TODO: bunu kaldırdım. zaten token yoksa request atılmıyor.
            saveSubscription()
        }

    }

    private static func saveSubscription() {
        if let shared = Euromsg.getShared() {
            var subs: EMSubscriptionRequest?
            shared.readWriteLock.read {
                subs = shared.subscription
                shared.fillGraylogModel()
            }
            if let subs = subs, let subscriptionData = try? JSONEncoder().encode(subs) {
                EMTools.saveUserDefaults(key: EMKey.registerKey, value: subscriptionData as AnyObject)
            }
        }
    }

    /// Euromsg SDK manage badge count by itself. If you want to use your custom badge count use this function.
    /// To get back this configuration set count to "-1".
    /// - Parameter count: badge count ( "-1" to give control to SDK )
    public static func setBadge(count: Int) {
        EMTools.userDefaults?.set(count == -1 ? false : true, forKey: EMKey.isBadgeCustom)
        UIApplication.shared.applicationIconBadgeNumber = count == -1 ? 0 : count
        // sync() //TODO: kaldırdım ne gerek var?
    }

    // MARK: API Methods
    /**:
     Registers device token to Euromsg services.
     To get deviceToken data use  `didRegisterForRemoteNotificationsWithDeviceToken` delegate function.
     For more information visit [Euromsg Documentation](https://github.com/relateddigital/euromessage-ios)
     - Parameter tokenData: delegate deviceToken data
     
     func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken
     deviceToken: Data) {
     Euromsg.shared?.registerToken(tokenData: deviceToken)
     }
     */
    public static func registerToken(tokenData: Data?) {
        guard let shared = getShared() else { return }
        guard let tokenData = tokenData else {
            EMLog.error("Token data cannot be nil")
            return
        }
        let tokenString = tokenData.reduce("", {$0 + String(format: "%02X", $1)})
        EMLog.info("Your token is \(tokenString)")
        shared.readWriteLock.write {
            shared.subscription.token = tokenString
        }
        Euromsg.sync()
    }

    /// Report Euromsg services that a push notification successfully delivered
    /// - Parameter pushDictionary: push notification data that comes from APNS
    public static func handlePush(pushDictionary: [AnyHashable: Any]) {
        guard let shared = getShared() else { return }
        guard pushDictionary["pushId"] != nil else {
            return
        }
        EMLog.info("handlePush: \(pushDictionary)")
        if let jsonData = try? JSONSerialization.data(withJSONObject: pushDictionary, options: .prettyPrinted),
           let message = try? JSONDecoder().decode(EMMessage.self, from: jsonData) {
            shared.emReadHandler?.reportRead(message: message)
        } else {
            EMLog.error("pushDictionary parse failed")
        }
    }
}

extension Euromsg {

    // MARK: Sync
    /// Synchronize user data with Euromsg servers
    /// - Parameter notification: no need for direct call
    public static func sync(notification: Notification? = nil) {
        guard let shared = getShared() else { return }
        if !shared.pushPermitDidCall {
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { (settings) in
                if settings.authorizationStatus == .denied {
                    setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.not.rawValue)
                    var subs: EMSubscriptionRequest!
                    shared.readWriteLock.read {
                        subs = shared.subscription
                    }
                    shared.euromsgAPI?.request(requestModel: subs, retry: 0, completion: shared.registerRequestHandler)
                } else {
                    setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.yes.rawValue)
                }
            }
        }

        var subs: EMSubscriptionRequest!
        var previousSubs: EMSubscriptionRequest?

        shared.readWriteLock.read {
            subs = shared.subscription
        }

        // Clear badge
        if !(subs.isBadgeCustom ?? false) {
            EMTools.removeUserDefaults(userKey: EMKey.badgeCount)
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        // check whether the user have an unreported message
        shared.emReadHandler?.checkUserUnreportedMessages()

        shared.readWriteLock.read {
            subs = shared.subscription
            previousSubs = Euromsg.previousSubscription
        }
        
        var shouldSendSubscription = false

        if subs.isValid() {
            shared.readWriteLock.write {
                if previousSubs == nil ||  subs != previousSubs {
                    Euromsg.previousSubscription = subs
                    shouldSendSubscription = true
                }
            }
            
            if !shouldSendSubscription {
                EMLog.warning("Subscription request not ready : \(String(describing: subs))")
                return
            }
            
            saveSubscription()
            shared.readWriteLock.read {
                subs = shared.subscription
            }
            EMTools.saveUserDefaults(key: EMKey.tokenKey, value: subs.token as AnyObject)
            EMLog.info("Current subscription \(subs.encoded)")
        } else {
            EMLog.warning("Subscription request is not valid : \(String(describing: subs))")
            return
        }

        shared.readWriteLock.read {
            subs = shared.subscription
        }
        
        shared.euromsgAPI?.request(requestModel: subs, retry: 0, completion: shared.registerRequestHandler)
    }

    /// RegisterRequest completion handler
    /// - Parameter result: result type
    private func registerRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMLog.success("""
                Subscription request successfully send, token: \(String(describing: self.subscription.token))
                """)
            self.delegate?.didRegisterSuccessfully()
        case .failure(let error):
            EMLog.error("Request failed : \(error)")
            self.delegate?.didFailRegister(error: error)
        }
    }

    /// Returns all the information that set before 
    public static func checkConfiguration() -> EMConfiguration {
        guard let shared = getShared() else { return EMConfiguration() }
        var registerRequest: EMSubscriptionRequest!
        shared.readWriteLock.read {
            registerRequest = shared.subscription
        }
        var properties: EMProperties?
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: registerRequest.extra ?? [:], options: [])
            properties = try JSONDecoder().decode(EMProperties.self, from: jsonData)
        } catch {
            
        }
        return EMConfiguration(userProperties: registerRequest.extra,
                               properties: properties,
                               firstTime: registerRequest.firstTime,
                               osVersion: registerRequest.osVersion,
                               deviceType: registerRequest.deviceType,
                               osName: registerRequest.osName,
                               deviceName: registerRequest.deviceName,
                               token: registerRequest.token,
                               local: registerRequest.local,
                               identifierForVendor: registerRequest.identifierForVendor,
                               appKey: registerRequest.appKey,
                               appVersion: registerRequest.appVersion,
                               advertisingIdentifier: registerRequest.advertisingIdentifier,
                               sdkVersion: registerRequest.sdkVersion,
                               carrier: registerRequest.carrier)
    }

}

extension Euromsg {

    // MARK: - Notification Extension
    @available(iOS 10.0, *)
    public static func didReceive(_ bestAttemptContent: UNMutableNotificationContent?,
                                  withContentHandler contentHandler:  @escaping (UNNotificationContent) -> Void) {
        EMNotificationHandler.didReceive(bestAttemptContent, withContentHandler: contentHandler)
    }
}

// MARK: - IYS Register Email Extension
extension Euromsg {

    public static func registerEmail(email: String, permission: Bool, isCommercial: Bool = false) {
        guard let shared = getShared() else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 60 * 60 * 3)
        setEmail(email: email, permission: permission)

        var registerEmailSubscriptionRequest: EMSubscriptionRequest!

        shared.readWriteLock.read {
            registerEmailSubscriptionRequest = shared.subscription
        }

        registerEmailSubscriptionRequest.extra?[EMProperties.CodingKeys.consentTime.rawValue] = dateFormatter.string(from: Date())
        registerEmailSubscriptionRequest.extra?[EMProperties.CodingKeys.consentSource.rawValue] = "HS_MOBIL"
        registerEmailSubscriptionRequest.extra?[EMProperties.CodingKeys.recipientType.rawValue] = isCommercial ? "TACIR" : "BIREYSEL"

        var previousRegisterEmailSubscription: EMSubscriptionRequest?
        shared.readWriteLock.read {
            previousRegisterEmailSubscription = shared.previousRegisterEmailSubscription
        }

        if registerEmailSubscriptionRequest.isValid() && (previousRegisterEmailSubscription == nil || registerEmailSubscriptionRequest != previousRegisterEmailSubscription) {
            shared.readWriteLock.write {
                shared.previousRegisterEmailSubscription = registerEmailSubscriptionRequest
            }
            EMLog.info("Current subscription \(registerEmailSubscriptionRequest.encoded)")
        } else {
            EMLog.warning("Subscription request not ready : \(String(describing: registerEmailSubscriptionRequest))")
            return
        }

        shared.euromsgAPI?.request(requestModel: registerEmailSubscriptionRequest, retry: 0, completion: shared.registerEmailHandler)
    }

    private func registerEmailHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMLog.success("""
               Register email request successfully send, token: \(String(describing: self.previousRegisterEmailSubscription?.token))
               """)
            self.delegate?.didRegisterSuccessfully()
        case .failure(let error):
            EMLog.error("Register email request failed : \(error)")
            self.delegate?.didFailRegister(error: error)
        }
    }

    public static func getIdentifierForVendorString() -> String {
        return EMTools.getIdentifierForVendorString()
    }
    
    public static func getPushMessages( completion: @escaping ((_ payloads: [EMMessage]) -> Void)) {
        completion(EMPayloadUtils.getRecentPayloads())
    }
    
    private func fillGraylogModel() {
        graylog.iosAppAlias = subscription.appKey
        graylog.token = subscription.token
        graylog.appVersion = subscription.appVersion
        graylog.sdkVersion = subscription.sdkVersion
        graylog.osType = subscription.osName
        graylog.osVersion = subscription.osVersion
        graylog.deviceName = subscription.deviceName
        graylog.userAgent = self.userAgent
        graylog.identifierForVendor = subscription.identifierForVendor
        graylog.extra = subscription.extra
    }

}
