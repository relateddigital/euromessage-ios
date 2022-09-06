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
        if let shared = getShared() {
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
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.tokenKey) // TODO: burada niye token var, android'de token silme yok
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
                EMUserDefaultsUtils.saveUserDefaults(key: EMKey.registerKey, value: subscriptionData as AnyObject)
            }
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
    
}

extension Euromsg {
    // MARK: Sync

    /// Synchronize user data with Euromsg servers
    /// - Parameter notification: no need for direct call
    public static func sync(notification: Notification? = nil) {
        guard let shared = getShared() else { return }
        if !shared.pushPermitDidCall {
            let center = UNUNC.current()
            center.getNotificationSettings { settings in
                if settings.authorizationStatus == .denied {
                    setUserProperty(key: EMProperties.CodingKeys.pushPermit.rawValue, value: EMProperties.PermissionKeys.not.rawValue)
                    var subs: EMSubscriptionRequest!
                    shared.readWriteLock.read {
                        subs = shared.subscription
                    }
                    shared.networkQueue.async {
                        Euromsg.emSubscriptionHandler?.reportSubscription(subscriptionRequest: subs)
                    }
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
            EMUserDefaultsUtils.removeUserDefaults(userKey: EMKey.badgeCount)

            if !EMTools.isiOSAppExtension() {
                if deliveredBadgeCount! {
                    UNUNC.current().getDeliveredNotifications(completionHandler: { notifications in
                        DispatchQueue.main.async {
                            UIA.shared.applicationIconBadgeNumber = notifications.count
                        }
                    })
                }
            }
        }
        // check whether the user have an unreported message
        shared.networkQueue.async {
            Euromsg.emReadHandler?.checkUserUnreportedMessages()
        }

        shared.readWriteLock.read {
            subs = shared.subscription
            previousSubs = Euromsg.previousSubscription
        }

        var shouldSendSubscription = false

        if subs.isValid() {
            shared.readWriteLock.write {
                if previousSubs == nil || subs != previousSubs {
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
            EMUserDefaultsUtils.saveUserDefaults(key: EMKey.tokenKey, value: subs.token as AnyObject)
            EMLog.info("Current subscription \(subs.encoded)")
        } else {
            EMLog.warning("Subscription request is not valid : \(String(describing: subs))")
            return
        }

        shared.readWriteLock.read {
            subs = shared.subscription
        }

        shared.networkQueue.async {
            emSubscriptionHandler?.reportSubscription(subscriptionRequest: subs)
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

    public static func getIdentifierForVendorString() -> String {
        return EMTools.getIdentifierForVendorString()
    }

    public static func getPushMessages(completion: @escaping ((_ payloads: [EMMessage]) -> Void)) {
        completion(EMUserDefaultsUtils.getRecentPayloads())
    }
    
    public static func getPushMessagesWithId(completion: @escaping ((_ payloads: [EMMessage]) -> Void)) {
        completion(EMUserDefaultsUtils.getRecentPayloadsWithId())
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
