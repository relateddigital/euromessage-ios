//
//  EMPushTracker.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 23.08.2021.
//

import Foundation
import UserNotifications

class EMPushTracker : NSObject {
    
    var hasAddedObserver = false
    
    func initializeAutomaticPushOpenTracking() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupAutomaticPushOpenTracking()
        }
    }
    
    //TODO: appextension kontrolü yap
    func setupAutomaticPushOpenTracking() {
        guard let appDelegate = Euromsg.sharedUIApplication()?.delegate else {
            return
        }
        var selector: Selector?
        var newSelector: Selector?
        let aClass: AnyClass = type(of: appDelegate)
        var newClass: AnyClass?
        if let UNDelegate = UNUserNotificationCenter.current().delegate {
            newClass = type(of: UNDelegate)
        } else {
            UNUserNotificationCenter.current().addDelegateObserver(emPushTracker: self)
            hasAddedObserver = true
        }
        
        if let newClass = newClass,
           class_getInstanceMethod(newClass,
                                   NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")) != nil {
            selector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
            newSelector = #selector(NSObject.em_userNotificationCenter(_:newDidReceive:withCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            newSelector = #selector(UIResponder.mp_application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:")
            newSelector = #selector(UIResponder.mp_application(_:newDidReceiveRemoteNotification:))
        }
        
        if let selector = selector, let newSelector = newSelector {
            let block = { (_: AnyObject?, _: Selector, _: AnyObject?, param2: AnyObject?) in
                if let param2 = param2 as? [AnyHashable: Any] {
                    //TODO: burada open isteği gönderilecek
                    //self.delegate?.trackPushNotification(param2, event: "$campaign_received", properties: [:])
                }
            }
            EMSwizzler.swizzleSelector(selector,
                                       withSelector: newSelector,
                                       for: newClass ?? aClass,
                                       name: "notification opened",
                                       block: block)
        }
    }
    
}

extension UNUserNotificationCenter {
    func addDelegateObserver(emPushTracker: EMPushTracker) {
        addObserver(emPushTracker, forKeyPath: #keyPath(delegate), options: [.old, .new], context: nil)
    }
    
    func removeDelegateObserver(emPushTracker: EMPushTracker) {
        removeObserver(emPushTracker, forKeyPath: #keyPath(delegate))
    }
}

extension UIResponder {
    @objc func mp_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        let originalSelector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
           let swizzle = EMSwizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary, @escaping (UIBackgroundFetchResult) -> Void) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, userInfo as NSDictionary, completionHandler)
            
            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, userInfo as AnyObject?)
            }
        }
    }
    
    @objc func mp_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        let originalSelector = NSSelectorFromString("application:didReceiveRemoteNotification:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
           let swizzle = EMSwizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UIApplication, NSDictionary) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, application, userInfo as NSDictionary)
            
            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, application as AnyObject?, userInfo as AnyObject?)
            }
        }
    }
}

extension NSObject {
    @objc func em_userNotificationCenter(_ center: UNUserNotificationCenter,
                                         newDidReceive response: UNNotificationResponse,
                                         withCompletionHandler completionHandler: @escaping () -> Void) {
        let originalSelector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
        if let originalMethod = class_getInstanceMethod(type(of: self), originalSelector),
           let swizzle = EMSwizzler.swizzles[originalMethod] {
            typealias MyCFunction = @convention(c) (AnyObject, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void
            let curriedImplementation = unsafeBitCast(swizzle.originalMethod, to: MyCFunction.self)
            curriedImplementation(self, originalSelector, center, response, completionHandler)
            
            for (_, block) in swizzle.blocks {
                block(self, swizzle.selector, center as AnyObject?, response.notification.request.content.userInfo as AnyObject?)
            }
        }
    }
}
