//
//  Euromsg.swift
//
//
//  Created by Muhammed ARAFA on 27.03.2020.
//

import Foundation
import UIKit

typealias UIA = UIApplication
typealias NC = NotificationCenter
typealias UNUNC = UNUserNotificationCenter

public protocol EuromsgDelegate: AnyObject {
    func didRegisterSuccessfully()
    func didFailRegister(error: EuromsgAPIError)
}

public class Euromsg {
    private static var sharedInstance: Euromsg?
    private let readWriteLock: EMReadWriteLock
    internal var euromsgAPI: EuromsgAPIProtocol?
    private var observers: [NSObjectProtocol]?
    
    static var emReadHandler: EMReadHandler?
    static var emDeliverHandler: EMDeliverHandler?
    static var emSubscriptionHandler: EMSubscriptionHandler?
    
    private var pushPermitDidCall: Bool = false
    weak var delegate: EuromsgDelegate?
    internal var subscription: EMSubscriptionRequest
    internal var graylog: EMGraylogRequest
    private static var previousSubscription: EMSubscriptionRequest?
    private var previousRegisterEmailSubscription: EMSubscriptionRequest?
    internal var userAgent: String?
    static var deliveredBadgeCount: Bool?
    
    var networkQueue: DispatchQueue!
    
    private init(appKey: String, launchOptions: [UIA.LaunchOptionsKey: Any]?) {
        EMLog.info("INITCALL \(appKey)")
        networkQueue = DispatchQueue(label: "com.euromsg.\(appKey).network)", qos: .utility)
        readWriteLock = EMReadWriteLock(label: "EuromsgLock")
        if let lastSubscriptionData = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data,
           let lastSubscription = try? JSONDecoder().decode(EMSubscriptionRequest.self, from: lastSubscriptionData) {
            subscription = lastSubscription
        } else {
            subscription = EMSubscriptionRequest()
        }
        subscription.setDeviceParameters()
        subscription.appKey = appKey
        subscription.token = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.tokenKey) as? String
        
        graylog = EMGraylogRequest()
        fillGraylogModel()
        
        let ncd = NC.default
        observers = []
        observers?.append(ncd.addObserver(forName: UIA.willResignActiveNotification, object: nil, queue: nil, using: Euromsg.sync))
        observers?.append(ncd.addObserver(forName: UIA.willTerminateNotification, object: nil, queue: nil, using: Euromsg.sync))
        observers?.append(ncd.addObserver(forName: UIA.willEnterForegroundNotification, object: nil, queue: nil, using: Euromsg.sync))
        observers?.append(ncd.addObserver(forName: UIA.didBecomeActiveNotification, object: nil, queue: nil, using: Euromsg.sync))
        
        if let userAgent = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.userAgent) as? String {
            self.userAgent = userAgent
        } else {
            EMTools.computeWebViewUserAgent { str in
                self.userAgent = str
                EMUserDefaultsUtils.saveUserDefaults(key: EMKey.userAgent, value: str as AnyObject)
            }
        }
    }
    
    deinit {
        NC.default.removeObserver(self, name: UIA.willResignActiveNotification, object: nil)
        NC.default.removeObserver(self, name: UIA.willTerminateNotification, object: nil)
        NC.default.removeObserver(self, name: UIA.willEnterForegroundNotification, object: nil)
        NC.default.removeObserver(self, name: UIA.didBecomeActiveNotification, object: nil)
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
                if let subscriptionData = EMUserDefaultsUtils.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data {
                    guard let subscriptionRequest = try? JSONDecoder().decode(EMSubscriptionRequest.self, from: subscriptionData),
                          let appKey = subscriptionRequest.appKey else {
                        EMLog.warning(EMKey.appAliasNotProvidedMessage)
                        return nil
                    }
                    Euromsg.configure(appAlias: appKey, launchOptions: nil)
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
    
    public class func configure(appAlias: String, launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
                                , enableLog: Bool = false, appGroupsKey: String? = nil, deliveredBadge: Bool? = true) {
        if let appGroupName = EMTools.getAppGroupName(appGroupName: appGroupsKey) {
            EMUserDefaultsUtils.setAppGroupsUserDefaults(appGroupName: appGroupName)
            EMLog.info("App Group Key : \(appGroupName)")
        }
        
        Euromsg.shared = Euromsg(appKey: appAlias, launchOptions: launchOptions)
        EMLog.isEnabled = enableLog
        Euromsg.shared?.euromsgAPI = EuromsgAPI()
        Euromsg.deliveredBadgeCount = deliveredBadge
        
        if let subscriptionHandler = Euromsg.emSubscriptionHandler {
            subscriptionHandler.euromsg = Euromsg.shared!
        } else {
            Euromsg.emSubscriptionHandler = EMSubscriptionHandler(euromsg: Euromsg.shared!)
        }
        
        if let readHandler = Euromsg.emReadHandler {
            readHandler.euromsg = Euromsg.shared!
        } else {
            Euromsg.emReadHandler = EMReadHandler(euromsg: Euromsg.shared!)
        }
        
        if let deliverHandler = Euromsg.emDeliverHandler {
            deliverHandler.euromsg = Euromsg.shared!
        } else {
            Euromsg.emDeliverHandler = EMDeliverHandler(euromsg: Euromsg.shared!)
        }
        
        if let userInfo = launchOptions?[UIA.LaunchOptionsKey.remoteNotification] as? [String: Any] {
            Euromsg.handlePush(pushDictionary: userInfo)
        }
    }
    
    /// Request to user for authorization for push notification
    /// - Parameter register: also register for deviceToken. _default : false_
    public static func askForNotificationPermission(register: Bool = false) {
        let center = UNUNC.current()
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
            let center = UNUNC.current()
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
            UIA.shared.registerForRemoteNotifications()
        }
    }
}

public protocol PushAction {
    func actionButtonClicked(identifier:String,url:String)
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
    
    public static func setAnonymous(perm: Bool) {
        if perm {
            setUserProperty(key: EMProperties.CodingKeys.SetAnonymous.rawValue, value: "true")
        } else {
            setUserProperty(key: EMProperties.CodingKeys.SetAnonymous.rawValue, value: "false")
        }
        sync()
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
        guard let shared = getShared() else {
            print("Euromsg shared instance is nil.")
            return
        }

        guard let value = value else {
            print("Value is nil for key: \(key).")
            return
        }

        shared.readWriteLock.write {
            if shared.subscription.extra == nil {
                shared.subscription.extra = [String: String]()
            }
            shared.subscription.extra?[key] = value
        }
        saveSubscription()
    }
    
    public static func removeUserProperty(key: String) {
        guard let shared = getShared() else {
            print("Euromsg shared instance is nil.")
            return
        }

        shared.readWriteLock.write {
            if shared.subscription.extra != nil {
                shared.subscription.extra?[key] = nil
            } else {
                print("No properties to remove for key: \(key).")
            }
        }
        saveSubscription()
    }
    
    public static func logout() {
        guard let shared = getShared() else {
            print("Euromsg shared instance is nil.")
            return
        }

        shared.readWriteLock.write {
            shared.subscription.extra = [String: String]()
        }
        saveSubscription()
    }
    
    private static func saveSubscription() {
        guard let shared = Euromsg.getShared() else {
            print("Euromsg shared instance is nil.")
            return
        }

        var subs: EMSubscriptionRequest?
        shared.readWriteLock.read {
            subs = shared.subscription
            shared.fillGraylogModel()
        }

        guard let validSubs = subs else {
            print("Subscription data is nil after read operation.")
            return
        }

        do {
            let subscriptionData = try JSONEncoder().encode(validSubs)
            EMUserDefaultsUtils.saveUserDefaults(key: EMKey.registerKey, value: subscriptionData as AnyObject)
        } catch {
            print("Failed to encode subscription: \(error.localizedDescription)")
        }
    }
    
    /// Euromsg SDK manage badge count by itself. If you want to use your custom badge count use this function.
    /// To get back this configuration set count to "-1".
    /// - Parameter count: badge count ( "-1" to give control to SDK )
    public static func setBadge(count: Int) {
        EMUserDefaultsUtils.userDefaults?.set(count == -1 ? false : true, forKey: EMKey.isBadgeCustom)
        UIA.shared.applicationIconBadgeNumber = count == -1 ? 0 : count
    }
    
    // MARK: API Methods
    
    /** :
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
        let tokenString = tokenData.reduce("", { $0 + String(format: "%02X", $1) })
        EMLog.info("Your token is \(tokenString)")
        shared.readWriteLock.write {
            shared.subscription.token = tokenString
        }
        Euromsg.sync()
    }
    
    public static func handlePushWithActionButtons(response: UNNotificationResponse,type:Any) {
        
        var actionButtonDelegate : PushAction?
        actionButtonDelegate = type as? PushAction
        
        let pushDictionary = response.notification.request.content.userInfo
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: pushDictionary, options: .prettyPrinted),
           let message = try? JSONDecoder().decode(EMMessage.self, from: jsonData) {
            
            if response.actionIdentifier == "action_0" {
                actionButtonDelegate?.actionButtonClicked(identifier: "action_0", url: message.actions?.first?.Url ?? "")
            } else if response.actionIdentifier == "action_1" {
                actionButtonDelegate?.actionButtonClicked(identifier: "action_1", url: message.actions?.last?.Url ?? "")
            }
        }
    }
    
    static func openLink(urlStr:String) {
        if let url = URL(string: urlStr) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Report Euromsg services that a push notification successfully read
    /// - Parameter pushDictionary: push notification data that comes from APNS
    public static func handlePush(pushDictionary: [AnyHashable: Any]) {
        guard let shared = getShared() else { return }
        guard pushDictionary["pushId"] != nil else {
            return
        }
        EMLog.info("handlePush: \(pushDictionary)")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: pushDictionary, options: .prettyPrinted),
           let message = try? JSONDecoder().decode(EMMessage.self, from: jsonData) {
            shared.networkQueue.async {
                if message.isSilent() {
                    Euromsg.emDeliverHandler?.reportDeliver(message: message, silent: true)
                } else {
                    EMUserDefaultsUtils.updatePayload(pushId: message.pushId)
                    Euromsg.emReadHandler?.reportRead(message: message)
                }
            }
        } else {
            EMLog.error("pushDictionary parse failed")
            Euromsg.sendGraylogMessage(logLevel: EMKey.graylogLogLevelError, logMessage: "pushDictionary parse failed")
        }
    }
    
    public static func setNotificationLoginID(notificationLoginID: String?) {
        setUserProperty(key: EMKey.notificationLoginIdKey, value: notificationLoginID)
        EMUserDefaultsUtils.saveUserDefaults(key: EMKey.notificationLoginIdKey, value: notificationLoginID as AnyObject)
    }
    
    public static func deleteNotifications(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                center.getDeliveredNotifications { notifications in
                    completion(notifications.isEmpty)
                }
            }
    }
    
    public static func removeNotification(withPushID pushID: String, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        
        center.getDeliveredNotifications { notifications in
            for notification in notifications {
                if let userInfo = notification.request.content.userInfo as? [String: Any] {
                    if let notificationPushID = userInfo["pushId"] as? String {
                        if notificationPushID == pushID {
                            center.removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                            completion(true)
                            return
                        }
                    } else {
                        completion(false)
                    }
                }
            }
            completion(false)
        }
    }
    
}

extension Euromsg {
    // MARK: Sync
    
    /// Synchronize user data with Euromsg servers
    /// - Parameter notification: no need for direct call
    public static func sync(notification: Notification? = nil) {
        guard let shared = getShared() else {
            EMLog.warning("Euromsg shared instance is nil.")
            return
        }
        
        if !shared.pushPermitDidCall {
            let center = UNUNC.current()
            center.getNotificationSettings { settings in
                if settings.authorizationStatus == .denied {
                    setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.not.rawValue)
                    
                    var subs: EMSubscriptionRequest?
                    shared.readWriteLock.read {
                        subs = shared.subscription
                    }
                    
                    if let subs = subs {
                        shared.networkQueue.async {
                            Euromsg.emSubscriptionHandler?.reportSubscription(subscriptionRequest: subs)
                        }
                    } else {
                        EMLog.warning("Subscription is nil after read operation.")
                    }
                } else {
                    setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.yes.rawValue)
                }
            }
        }
        
        var subs: EMSubscriptionRequest?
        var previousSubs: EMSubscriptionRequest?

        shared.readWriteLock.read {
            subs = shared.subscription
            previousSubs = Euromsg.previousSubscription
        }
        
        guard let validSubs = subs else {
            EMLog.warning("Subscription is nil.")
            return
        }
        
        // Clear badge
        if !(validSubs.isBadgeCustom ?? false) {
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.badgeCount)
            
            if !EMTools.isiOSAppExtension(), let deliveredBadgeCount = deliveredBadgeCount, deliveredBadgeCount {
                UNUNC.current().getDeliveredNotifications(completionHandler: { notifications in
                    DispatchQueue.main.async {
                        UIA.shared.applicationIconBadgeNumber = notifications.count
                    }
                })
            }
        }
        
        // Check for unreported messages
        shared.networkQueue.async {
            Euromsg.emReadHandler?.checkUserUnreportedMessages()
        }
        
        var shouldSendSubscription = false
        
        if validSubs.isValid() {
            shared.readWriteLock.write {
                if previousSubs == nil || validSubs != previousSubs {
                    Euromsg.previousSubscription = validSubs
                    shouldSendSubscription = true
                }
            }
            
            if !shouldSendSubscription {
                EMLog.warning("Subscription request not ready: \(String(describing: validSubs))")
                return
            }
            
            saveSubscription()
            
            shared.readWriteLock.read {
                subs = shared.subscription
            }
            
            if let subs = subs {
                EMUserDefaultsUtils.saveUserDefaults(key: EMKey.tokenKey, value: subs.token as AnyObject)
                EMLog.info("Current subscription \(subs.encoded)")
            } else {
                EMLog.warning("Failed to retrieve subscription after saving.")
            }
        } else {
            EMLog.warning("Subscription request is not valid: \(String(describing: validSubs))")
            return
        }
        
        if let subs = subs {
            shared.networkQueue.async {
                emSubscriptionHandler?.reportSubscription(subscriptionRequest: subs)
            }
        } else {
            EMLog.warning("Failed to retrieve subscription for reporting.")
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
                               sdkType: registerRequest.sdkType,
                               carrier: registerRequest.carrier)
    }
    
    public static func getIdentifierForVendorString() -> String {
        return EMTools.getIdentifierForVendorString()
    }
    
    public static func getPushMessages(completion: @escaping ((_ payloads: [EMMessage]) -> Void)) {
        completion(EMUserDefaultsUtils.getRecentPayloads())
    }
    
    public static func getPushMessagesWithId(completion: @escaping ((_ payloads: [EMMessage]) -> Void)) {
        completion(EMUserDefaultsUtils.getRecentPayloadsWithId())
    }
    
    public static func deletePayloadWithId(pushId: String? = nil, completion: @escaping ((_ completed: Bool) -> Void)) {
            if let pushId = pushId {
                EMUserDefaultsUtils.deletePayloadWithId(pushId: pushId) { success in
                    completion(success)
                }
            } else {
                EMUserDefaultsUtils.deletePayloadWithId { success in
                    completion(success)
                }
            }
            
        }
        
    public static func deletePayload(pushId: String? = nil, completion: @escaping ((_ completed: Bool) -> Void)) {
        if let pushId = pushId {
                EMUserDefaultsUtils.deletePayload(pushId: pushId) { success in
                    completion(success)
                }
            } else {
                EMUserDefaultsUtils.deletePayload { success in
                    completion(success)
                }
            }
        }
    public static func readAllPushMessages(pushId: String? = nil, completion: @escaping ((_ success: Bool) -> Void)) {
        if let pushId = pushId {
            EMUserDefaultsUtils.readAllPushMessages(pushId: pushId) { success in
                completion(success)
            }
        } else {
            EMUserDefaultsUtils.readAllPushMessages { success in
                completion(success)
            }
        }
        
    }
    
    public static func getSubscription () -> EMSubscriptionRequest {
        guard let shared = getShared() else { return EMSubscriptionRequest() }
        var subs: EMSubscriptionRequest!
        shared.readWriteLock.read {
            subs = shared.subscription
        }
        return subs
    }
    
}

extension Euromsg {
    // MARK: - Notification Extension
    
    public static func didReceive(_ bestAttemptContent: UNMutableNotificationContent?,
                                  withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        EMUNNotificationServiceExtensionHandler.didReceive(bestAttemptContent, withContentHandler: contentHandler)
    }
}

// MARK: - IYS Register Email Extension

extension Euromsg {
    public static func registerEmail(email: String, permission: Bool, isCommercial: Bool = false, customDelegate: EuromsgDelegate? = nil) {
        guard let shared = getShared() else { return }
        
        if let customDelegate = customDelegate {
            shared.delegate = customDelegate
        }
        
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
            let message = "Subscription request not ready : \(String(describing: registerEmailSubscriptionRequest))"
            EMLog.warning(message)
            shared.delegate?.didFailRegister(error: .other(message))
            return
        }
        
        shared.euromsgAPI?.request(requestModel: registerEmailSubscriptionRequest, retry: 3, completion: shared.registerEmailHandler)
    }
    
    private func registerEmailHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMLog.success("""
            Register email request successfully send, token: \(String(describing: previousRegisterEmailSubscription?.token))
            """)
            delegate?.didRegisterSuccessfully()
        case let .failure(error):
            EMLog.error("Register email request failed : \(error)")
            delegate?.didFailRegister(error: error)
        }
    }
}

// MARK: - Graylog

extension Euromsg {
    private func fillGraylogModel() {
        graylog.iosAppAlias = subscription.appKey
        graylog.token = subscription.token
        graylog.appVersion = subscription.appVersion
        graylog.sdkVersion = subscription.sdkVersion
        graylog.sdkType = subscription.sdkType
        graylog.osType = subscription.osName
        graylog.osVersion = subscription.osVersion
        graylog.deviceName = subscription.deviceName
        graylog.userAgent = userAgent
        graylog.identifierForVendor = subscription.identifierForVendor
        graylog.extra = subscription.extra
    }
    
    public static func sendGraylogMessage(logLevel: String, logMessage: String, _ path: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard let shared = getShared() else { return }
        var emGraylogRequest: EMGraylogRequest!
        shared.readWriteLock.read {
            emGraylogRequest = shared.graylog
        }
        emGraylogRequest.logLevel = logLevel
        emGraylogRequest.logMessage = logMessage
        
        if let file = path.components(separatedBy: "/").last {
            emGraylogRequest.logPlace = "\(file)/\(function)/\(line)"
        } else {
            emGraylogRequest.logPlace = "\(path)/\(function)/\(line)"
        }
        
        shared.euromsgAPI?.request(requestModel: emGraylogRequest, retry: 3, completion: shared.sendGraylogMessageHandler)
    }
    
    private func sendGraylogMessageHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            EMLog.success("GraylogMessage request sent successfully")
        case let .failure(error):
            EMLog.error("GraylogMessage request failed : \(error)")
        }
    }
}
