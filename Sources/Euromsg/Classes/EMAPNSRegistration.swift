//
//  EMAPNSRegistration.swift
//  Euromsg
//
//  Created by Egemen Software on 14.12.2021.
//

import Foundation
import UIKit
import UserNotifications

class EMAPNSRegistration {
    
    static let shared = EMAPNSRegistration()
    
    private var shouldUpdateAPNSRegistration = true
    private var notificationOptions: EMNotificationOptions?
    private var userPromptedForNotifications = false
    private var authorizedNotificationSettings: EMAuthorizedNotificationSettings?
    private var authorizationStatus: EMAuthorizationStatus?
    
    func enableUserPushNotifications(_ completionHandler: @escaping (_ success: Bool) -> Void) {
        self.updateAPNSRegistration { success in
            completionHandler(success)
        }
    }
    
    private func updateAPNSRegistration(_ completionHandler: @escaping (_ success: Bool) -> Void) {
        self.shouldUpdateAPNSRegistration = false
        
        self.getNotificationAuthorizedSettings(completionHandler: { authorizedSettings, status in
            var options: EMNotificationOptions = []
            
            let categories = EMUNNotificationServiceExtensionHandler.getCarouselActionCategorySet()
            
            if let notificationOptions = self.notificationOptions {
                options = notificationOptions
            }
            
            if (authorizedSettings == [] && options == []) {
                completionHandler(false)
            } else if (status == .ephemeral) {
                self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                completionHandler(true)
            } else {
                self.updateRegistration(options: options, categories: categories) { result, authorizedSettings, status in
                    self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                    completionHandler(result)
                }
            }
        })
    }
    
    private func notificationRegistrationFinished(authorizedSettings: EMAuthorizedNotificationSettings, status: EMAuthorizationStatus) {
        DispatchQueue.main.async {
            UIA.shared.registerForRemoteNotifications()
        }
        self.userPromptedForNotifications = true;
        self.authorizedNotificationSettings = authorizedSettings;
        self.authorizationStatus = status;

    }
    
    func updateRegistration(options: EMNotificationOptions, categories: Set<UNNotificationCategory>? = nil, completionHandler: @escaping (Bool, EMAuthorizedNotificationSettings, EMAuthorizationStatus) -> Void) {
        if let categories = categories {
            UNUNC.current().setNotificationCategories(categories)
        }
        UNUNC.current().requestAuthorization(options: getUNAuthorizationOptions(emOptions: options)) { granted, error in
            if let error = error  {
                EMLog.error("requestAuthorizationWithOptions failed with error: \(error)")
            }
            self.getNotificationAuthorizedSettings { authorizedSettings, status in
                completionHandler(granted, authorizedSettings, status)
            }
        }
    }
    
    func getUNAuthorizationOptions(emOptions: EMNotificationOptions) -> UNAuthorizationOptions {
        var unOptions:UNAuthorizationOptions = []
        
        if emOptions.contains(.badge) {
            unOptions.insert(.badge)
        }

        if emOptions.contains(.sound) {
            unOptions.insert(.sound)
        }

        if emOptions.contains(.alert) {
            unOptions.insert(.alert)
        }

        if emOptions.contains(.carPlay) {
            unOptions.insert(.carPlay)
        }

        if #available(iOS 12.0, tvOS 12.0, *) {
            if emOptions.contains(.criticalAlert) {
                unOptions.insert(.criticalAlert)
            }

            if emOptions.contains(.providesAppNotificationSettings) {
                unOptions.insert(.providesAppNotificationSettings)
            }

            if emOptions.contains(.provisional) {
                unOptions.insert(.provisional)
            }
        }

        return unOptions
    }
    
    func getNotificationAuthorizedSettings(completionHandler: @escaping (EMAuthorizedNotificationSettings, EMAuthorizationStatus) -> Void)  {
        UNUNC.current().getNotificationSettings { [self] notificationSettings in
            let status = self.getNotificationAuthorizationStatus(status: notificationSettings.authorizationStatus)
            var authorizedSettings: EMAuthorizedNotificationSettings = []
            
            if (notificationSettings.badgeSetting == .enabled) {
                authorizedSettings.insert(.badge)
            }
            
            if notificationSettings.soundSetting == .enabled {
                authorizedSettings.insert(.sound)
            }
            
            if notificationSettings.alertSetting == .enabled {
                authorizedSettings.insert(.alert)
            }
            
            if notificationSettings.carPlaySetting == .enabled {
                authorizedSettings.insert(.carPlay)
            }
            
            if notificationSettings.lockScreenSetting == .enabled {
                authorizedSettings.insert(.lockScreen)
            }
            
            if notificationSettings.notificationCenterSetting == .enabled {
                authorizedSettings.insert(.notificationCenter)
            }
            
            if #available(iOS 12.0, *) {
                if notificationSettings.criticalAlertSetting == .enabled {
                    authorizedSettings.insert(.criticalAlert)
                }
            }
            
            if #available(iOS 13.0, *) {
                if notificationSettings.announcementSetting == .enabled {
                    authorizedSettings.insert(.announcement)
                }
            }
            
            if #available(iOS 15.0, *) {
                if notificationSettings.timeSensitiveSetting == .enabled {
                    authorizedSettings.insert(.timeSensitive)
                }
                
                if notificationSettings.scheduledDeliverySetting == .enabled {
                    authorizedSettings.insert(.scheduledDelivery)
                }
            }
            
            completionHandler(authorizedSettings, status)
            
        }
    }
    
    private func getNotificationAuthorizationStatus(status: UNAuthorizationStatus) -> EMAuthorizationStatus {
        if #available(iOS 12.0, tvOS 12.0, *) {
            if status == .provisional {
                return .provisional
            }
        }
        if status == .notDetermined {
            return .notDetermined
        } else if status == .denied {
            return .denied
        } else if status == .authorized {
            return .authorized
        }
        if #available(iOS 14.0, *) {
            if (status == .ephemeral) {
                return .ephemeral;
            }
        }
        EMLog.warning("Can not determine UNAuthorizationStatus: \(status.rawValue)")
        return .notDetermined
    }
}

struct EMNotificationOptions : OptionSet {
    let rawValue: Int
    static let none: Self = []
    static let badge = Self(rawValue: (1 << 0))
    static let sound = Self(rawValue: (1 << 1))
    static let alert = Self(rawValue: (1 << 2))
    static let carPlay = Self(rawValue: (1 << 3))
    static let criticalAlert = Self(rawValue: (1 << 4))
    static let providesAppNotificationSettings = Self(rawValue: (1 << 5))
    static let provisional = Self(rawValue: (1 << 6))
}

struct EMAuthorizedNotificationSettings : OptionSet {
    let rawValue: Int
    static let none: Self = []
    static let badge = Self(rawValue: (1 << 0))
    static let sound = Self(rawValue: (1 << 1))
    static let alert = Self(rawValue: (1 << 2))
    static let carPlay = Self(rawValue: (1 << 3))
    static let lockScreen = Self(rawValue: (1 << 4))
    static let notificationCenter = Self(rawValue: (1 << 5))
    static let criticalAlert = Self(rawValue: (1 << 6))
    static let announcement = Self(rawValue: (1 << 7))
    static let scheduledDelivery = Self(rawValue: (1 << 8))
    static let timeSensitive = Self(rawValue: (1 << 9))
}

enum EMAuthorizationStatus : Int {
    case notDetermined = 0
    case denied = 1
    case authorized = 2
    case provisional = 3
    case ephemeral = 4
}


