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

    internal var registerRequest = EMRegisterRequest()
    private var currentRegister: EMRegisterRequest?
    internal var euromsgAPI: EuromsgAPIProtocol?
    private var observers: [NSObjectProtocol]?
    internal var emNetworkHandler: EMNetworkHandler?

    weak var delegate: EuromsgDelegate?
    private static var sharedInstance: Euromsg?
    public static var shared: Euromsg? {
        get {
            guard sharedInstance?.registerRequest.appKey != nil,
                sharedInstance?.registerRequest.appKey != "" else {
                    if let registerData = EMTools.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data {
                        guard let registerRequest = try? JSONDecoder.init().decode(EMRegisterRequest.self,
                                                                                   from: registerData),
                            let appKey = registerRequest.appKey else {
                                EMLog.warning("""
                                appAlias not provided. Please use Euromsg.configure(::) function first.
                                \(EMKey.instractionPage)
                                """)
                                return nil
                        }
                        Euromsg.configure(appAlias: appKey)
                        sharedInstance?.registerRequest = registerRequest
                        return sharedInstance
                    }
                    EMLog.warning("""
                    appAlias not provided. Please use Euromsg.configure(::) function first.
                    \(EMKey.instractionPage)
                    """)
                    return nil
            }
            return sharedInstance
        }
        set {
            sharedInstance = newValue
        }
    }

    // MARK: Lifecycle
    public class func configure(appAlias: String,
                                enableLog: Bool = false) {
        Euromsg.shared = Euromsg.init(appKey: appAlias)
        EMLog.shared.isEnabled = enableLog
        Euromsg.shared?.euromsgAPI = EuromsgAPI()
        Euromsg.shared?.emNetworkHandler = EMNetworkHandler(euromsg: Euromsg.shared!)

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } else {
            // If ios version is lower than 10, server should send 0 badge push notification to clear all.
        }
    }

    private init(appKey: String) {
        registerRequest.appKey = appKey
        registerRequest.sdkVersion = EMKey.sdkVersion
        registerRequest.token = EMTools.retrieveUserDefaults(userKey: EMKey.tokenKey) as? String
        if let lastRegister = EMTools.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data {
            let lastRequest = try? JSONDecoder.init().decode(EMRegisterRequest.self,
                                                             from: lastRegister)
            registerRequest.extra = lastRequest?.extra
        }
        let ncd = NotificationCenter.default
        observers = []
        observers?.append(ncd.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
        observers?.append(ncd.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
        observers?.append(ncd.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil,
            using: Euromsg.sync))
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didEnterBackgroundNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willTerminateNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didBecomeActiveNotification,
                                                  object: nil)
    }

    /// Request to user for authorization for push notification
    /// - Parameter register: also register for deviceToken. _default : false_
    public static func askForNotificationPermission(register: Bool = false) {
        if #available(iOS 10.0, *) {
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
        } else {
            let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
            if register {
                self.registerForPushNotifications()
            }
        }
    }

    public static func registerForPushNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

}

extension Euromsg {

    // MARK: Request Builders
    public static func setAdvertisingIdentifier(adIdentifier: String?) {
        guard let shared = getShared() else { return }
        if let adIdentifier = adIdentifier {
            shared.registerRequest.advertisingIdentifier = adIdentifier
        }
    }

    public static func setAppVersion(appVersion: String?) {
        guard let shared = getShared() else { return }
        if let appVersion = appVersion {
            shared.registerRequest.appVersion = appVersion
        }
    }

    public static func setPushNotification(permission: Bool) {
        guard let shared = getShared() else { return }
        if permission {
            shared.registerRequest.extra?[EMProperties.CodingKeys.pushPermit.rawValue] =
                EMProperties.PermissionKeys.yes.rawValue
            registerForPushNotifications()
        } else {
            shared.registerRequest.extra?[EMProperties.CodingKeys.pushPermit.rawValue] =
                EMProperties.PermissionKeys.not.rawValue
        }
        sync()
    }

    public static func setEmail(email: String? = nil, permission: Bool) {
        guard let shared = getShared() else { return }
        shared.registerRequest.extra?[EMProperties.CodingKeys.emailPermit.rawValue] =
            permission ? EMProperties.PermissionKeys.yes.rawValue :
            EMProperties.PermissionKeys.not.rawValue
        if EMTools.validateEmail(email: email), permission {
            shared.registerRequest.extra?[EMProperties.CodingKeys.email.rawValue] = email
        }
        sync()
    }

    public static func registerEmail(email: String, permission: Bool, isCommercial: Bool = false) {
        guard let shared = getShared() else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 60 * 60 * 3)
        shared.registerRequest.extra?[EMProperties.CodingKeys.email.rawValue] = email
        shared.registerRequest.extra?[EMProperties.CodingKeys.emailPermit.rawValue] =
            permission ? EMProperties.PermissionKeys.yes.rawValue :
            EMProperties.PermissionKeys.not.rawValue
    
        var registerRequest = shared.registerRequest
        registerRequest.extra?[EMProperties.CodingKeys.consentTime.rawValue] =
            dateFormatter.string(from: Date())
        registerRequest.extra?[EMProperties.CodingKeys.consentSource.rawValue] =
            "HS_MOBIL"
        registerRequest.extra?[EMProperties.CodingKeys.recipientType.rawValue] =
            isCommercial ? "TACIR" : "BIREYSEL"
        shared.euromsgAPI?.request(requestModel: registerRequest,
                            completion: shared.registerEmailHandler)
    }

    private func registerEmailHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
          EMLog.success("""
            Register request successfully send, token: \(String(describing: self.registerRequest.token))
            """)
        case .failure(let error):
          EMLog.error("Request failed : \(error)")
        }
      }

    public static func setPhoneNumber(msisdn: String? = nil, permission: Bool) {
        guard let shared = getShared() else { return }
        shared.registerRequest.extra?[EMProperties.CodingKeys.gsmPermit.rawValue] =
            permission ? EMProperties.PermissionKeys.yes.rawValue :
            EMProperties.PermissionKeys.not.rawValue
        if EMTools.validatePhone(phone: msisdn), permission {
            shared.registerRequest.extra?[EMProperties.CodingKeys.msisdn.rawValue] = msisdn
        }
        sync()
    }

    public static func setEuroUserId(userKey: String?) {
        guard let shared = getShared() else { return }
        if let userKey = userKey {
            shared.registerRequest.extra?[EMProperties.CodingKeys.keyID.rawValue] = userKey
        }
        sync()
    }

    public static func setTwitterId(twitterId: String?) {
        guard let shared = getShared() else { return }
        if let twitterId = twitterId {
            shared.registerRequest.extra?[EMProperties.CodingKeys.twitter.rawValue] = twitterId
        }
        sync()
    }

    public static func setFacebook(facebookId: String?) {
        guard let shared = getShared() else { return }
        if let facebookId = facebookId {
            shared.registerRequest.extra?[EMProperties.CodingKeys.facebook.rawValue] = facebookId
        }
        sync()
    }

    public static func setUserProperty(key: String, value: String?) {
        guard let shared = getShared() else { return }
        if let value = value {
            shared.registerRequest.extra?[key] = value
        }
        sync()
    }
    /// Euromsg SDK manage badge count by itself. If you want to use your custom badge count use this function.
    /// To get back this configuration set count to "-1".
    /// - Parameter count: badge count ( "-1" to give control to SDK )
    public static func setBadge(count: Int) {
        EMTools.userDefaults?.set(count == -1 ? false : true, forKey: EMKey.isBadgeCustom)
        UIApplication.shared.applicationIconBadgeNumber = count == -1 ? 0 : count
        sync()
    }

    private static func getShared() -> Euromsg? {
        guard let shared = Euromsg.shared else {
            EMLog.warning("""
              appAlias not provided. Please use Euromsg.configure(::) function first.
                \(EMKey.instractionPage)
            """)
            return nil
        }
        return shared
    }

    // MARK: API Methods
    /**:
     Registers device token to Euromsg services.
     To get deviceToken data use  `didRegisterForRemoteNotificationsWithDeviceToken` delegate function.
     For more information visit [Euromsg Documentation](https://github.com/visilabs/Euro-IOS)
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
        shared.registerRequest.token = tokenString
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
        let jsonData = try? JSONSerialization.data(withJSONObject: pushDictionary, options: .prettyPrinted)
        let state = UIApplication.shared.applicationState
        if state != UIApplication.State.active {
            EMTools.saveUserDefaults(key: EMKey.euroLastMessageKey, value: jsonData as AnyObject)
        } else if let jsonData = jsonData,
            let message = try? JSONDecoder.init().decode(EMMessage.self, from: jsonData) {
            shared.emNetworkHandler?.reportRetention(message: message, status: EMKey.euroReadStatus)
        }
    }

}

extension Euromsg {

    // MARK: Sync
    /// Synchronize user data with Euromsg servers
    /// - Parameter notification: no need for direct call
    public static func sync(notification: Notification? = nil) {
        guard let shared = getShared() else { return }

        // Clear badge
        if !(shared.registerRequest.isBadgeCustom ?? false) {
            EMTools.removeUserDefaults(userKey: EMKey.badgeCount)
            UIApplication.shared.applicationIconBadgeNumber = 0
        }

        // check whether the user have an unreported message
        shared.emNetworkHandler?.checkUserUnreportedMessages()
        shared.currentRegister = shared.registerRequest
        if let lastRegisterData = EMTools.retrieveUserDefaults(userKey: EMKey.registerKey) as? Data {
            let lastRegister = try? JSONDecoder.init().decode(EMRegisterRequest.self, from: lastRegisterData)
            // set whether it is the first request or not
            if EMTools.retrieveUserDefaults(userKey: EMKey.tokenKey) != nil {
                shared.registerRequest.firstTime = 1
            }
            EMLog.info("Current registration settings \(shared.currentRegister?.encoded ?? "")")
            if shared.registerRequest.token != nil {
                EMTools.saveUserDefaults(key: EMKey.tokenKey, value: shared.registerRequest.token as AnyObject)
            }
            if EMTools.getInfoString(key: "CFBundleIdentifier") != "com.euromsg.EuroFramework" {
                if let lastRequestDate = EMTools.retrieveUserDefaults(userKey: EMKey.lastRequestDateKey) as? Date {
                    let comparisonResult = Date().compare(lastRequestDate)
                    if (comparisonResult == ComparisonResult.orderedAscending &&
                        lastRegister == shared.currentRegister) ||
                        shared.registerRequest.token == nil {
                        EMLog.warning("Register request not ready : \(shared.registerRequest)")
                        return
                    }
                }
            }
        }
        shared.euromsgAPI?.request(requestModel: shared.registerRequest,
                            completion: shared.registerRequestHandler)
    }

    /// RegisterRequest completion handler
    /// - Parameter result: result type
    private func registerRequestHandler(result: Result<EMResponse?, EuromsgAPIError>) {
        switch result {
        case .success:
            let fiveMinsLater = Date.init(timeInterval: (15 * 60), since: Date())
            EMTools.saveUserDefaults(key: EMKey.lastRequestDateKey,
                                     value: fiveMinsLater as AnyObject)
            if let currentRegisterData = try? JSONEncoder.init().encode(currentRegister) {
                EMTools.saveUserDefaults(key: EMKey.registerKey,
                                         value: currentRegisterData as AnyObject)
            }
            EMLog.success("""
                Register request successfully send, token: \(String(describing: self.registerRequest.token))
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
        let registerRequest = shared.registerRequest
        var properties: EMProperties?
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: registerRequest.extra ?? [:], options: [])
            properties = try JSONDecoder().decode(EMProperties.self, from: jsonData)
        } catch {}
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
    public static func logout() {
        EMTools.removeUserDefaults(userKey: EMKey.tokenKey)
        EMTools.removeUserDefaults(userKey: EMKey.registerKey)
    }
}
