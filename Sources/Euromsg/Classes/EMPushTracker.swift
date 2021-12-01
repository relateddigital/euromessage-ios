//
//  EMPushTracker.swift
//  Euromsg
//
//  Created by Egemen Gulkilik on 23.08.2021.
//

import Foundation
import UIKit
import UserNotifications
import UserNotificationsUI // TODO:
//import ObjectiveC // TODO: BUNA gerek var mı?

/*
class UAAutoIntegrationDummyDelegate: NSObject, UNUserNotificationCenterDelegate {
    
}


class UAAutoIntegration: NSObject {
    
    private static let instance = UAAutoIntegration()
    
    private var appDelegateSwizzler: UASwizzler?
    private var notificationDelegateSwizzler: UASwizzler?
    private var notificationCenterSwizzler: UASwizzler?
    private var dummyNotificationDelegate: UAAutoIntegrationDummyDelegate?
    private var delegate: UAAppIntegrationDelegate?
    
    
    class func integrate(with delegate: UAAppIntegrationDelegate?) {
        instance.delegate = delegate
        instance.dummyNotificationDelegate = UAAutoIntegrationDummyDelegate()
        instance.swizzleAppDelegate()
        instance.swizzleNotificationCenter()
    }
    
    class func reset() {
        instance.appDelegateSwizzler = nil
        instance.notificationDelegateSwizzler = nil
        instance.notificationCenterSwizzler = nil
        instance.dummyNotificationDelegate = nil
        //instance = nil//TODO
    }
    
    func swizzleAppDelegate() {
        guard let delegate = UIApplication.shared.delegate else {
            EMLog.error("App delegate not set, unable to perform automatic setup.")
            return
        }
        let `class` = type(of: delegate)
        appDelegateSwizzler = UASwizzler(for: `class`)
        appDelegateSwizzler.swizzle(#selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)), protocol: UIApplicationDelegate, implementation: ApplicationDidRegisterForRemoteNotificationsWithDeviceToken as? IMP)
        appDelegateSwizzler.swizzle(#selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)), protocol: UIApplicationDelegate, implementation: ApplicationDidFailToRegisterForRemoteNotificationsWithError as? IMP)
        appDelegateSwizzler.swizzle(#selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)), protocol: UIApplicationDelegate, implementation: ApplicationDidReceiveRemoteNotificationFetchCompletionHandler as? IMP)
        appDelegateSwizzler.swizzle(#selector(UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)), protocol: UIApplicationDelegate, implementation: ApplicationPerformFetchWithCompletionHandler as? IMP)
    }
    
    func swizzleNotificationCenter() {
        /*
         guard let `class` = UNUserNotificationCenter.self else {
         EMLog.error("UNUserNotificationCenter not available, unable to perform automatic setup.")
         return
         }
         */
        
        let `class` = UNUserNotificationCenter.self
        
        
        notificationCenterSwizzler = UASwizzler(for: `class`)
        notificationCenterSwizzler.swizzle(Selector("setDelegate:"), implementation: UserNotificationCenterSetDelegate as? IMP)
        let notificationCenterDelegate = UNUserNotificationCenter.current().delegate
        if let notificationCenterDelegate = notificationCenterDelegate {
            swizzleNotificationCenterDelegate(notificationCenterDelegate)
        } else {
            UNUserNotificationCenter.current().delegate = instance_.dummyNotificationDelegate
        }
    }
    
    func swizzleNotificationCenterDelegate(_ delegate: UNUserNotificationCenterDelegate) {
        let `class` = type(of: delegate)
        notificationDelegateSwizzler = UASwizzler(for: `class`)
        notificationDelegateSwizzler.swizzle(#selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)), protocol: UNUserNotificationCenterDelegate, implementation: UserNotificationCenterWillPresentNotificationWithCompletionHandler as? IMP)
        notificationDelegateSwizzler.swizzle(#selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)), protocol: UNUserNotificationCenterDelegate, implementation: UserNotificationCenterDidReceiveNotificationResponseWithCompletionHandler as? IMP)
    }
    
    func setNotificationCenter(_ notificationCenterSwizzler: UASwizzler?) {
        if self.notificationCenterSwizzler {
            self.notificationCenterSwizzler.unswizzle()
        }
        self.notificationCenterSwizzler = notificationCenterSwizzler
    }
    
    func setNotificationDelegateSwizzler(_ notificationDelegateSwizzler: UASwizzler?) {
        if self.notificationDelegateSwizzler {
            self.notificationDelegateSwizzler.unswizzle()
        }
        self.notificationDelegateSwizzler = notificationDelegateSwizzler
    }
    
    func setAppDelegateSwizzler(_ appDelegateSwizzler: UASwizzler?) {
        self.appDelegateSwizzler?.unswizzle()
        self.appDelegateSwizzler = appDelegateSwizzler
    }
    
    
    //TODO:bu metod eksik
    func UserNotificationCenterWillPresentNotificationWithCompletionHandler(_ self: Any?, _ _cmd: Selector, _ notificationCenter: UNUserNotificationCenter?, _ notification: UNNotification?, _ handler: ) {
        weak var delegate = instance.delegate
        var mergedPresentationOptions = delegate?.presentationOptions(for: notification)
        let dispatchGroup = DispatchGroup()
        let original = instance_.notificationDelegateSwizzler.originalImplementation(#function)
        if original != nil {
            var completionHandlerCalled = false
            let completionHandler: ((UNNotificationPresentationOptions) -> Void)? = { options in
                UAAutoIntegration.dispatchMain({
                    if completionHandlerCalled {
                        EMLog.error("Completion handler called multiple times.")
                        return
                    }
                    completionHandlerCalled = true
                    mergedPresentationOptions.insert(options)
                    dispatchGroup.leave()
                })
            }
            dispatchGroup.enter()
        }
    }
    
    
    func ApplicationDidRegisterForRemoteNotificationsWithDeviceToken(_ self: Any?, _ _cmd: Selector, _ application: UIApplication?, _ deviceToken: Data?) {
        if let deviceToken = deviceToken {
            UAAutoIntegration.instance.delegate?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
        
        let original = UAAutoIntegration.instance.appDelegateSwizzler?.originalImplementation(#function)
        if original != nil {
            original()
        }
    }
    
    
    
}



protocol UAAppIntegrationDelegate: NSObjectProtocol {
    func didRegisterForRemoteNotifications(deviceToken: Data)
    func didFailToRegisterForRemoteNotifications(error: Error)
    func didReceiveRemoteNotification(userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    func willPresentNotification(notification: UNNotification, presentationOptions options: UNNotificationPresentationOptions, completionHandler: @escaping () -> Void)
    func didReceiveNotificationResponse(response: UNNotificationResponse, completionHandler: @escaping (UNNotificationContentExtensionResponseOption) -> Void) // TODO:
    func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions
}

class UASwizzler: NSObject {
    
    private var `class`: AnyClass?
    private var originalMethods: [AnyHashable : Any]?
    
    init(`class`: AnyClass) {
        super.init()
        self.`class` = `class`
        originalMethods = [:]
    }
    
    convenience init(for `class`: AnyClass) {
        self.init(class: `class`)
    }
    
    
    /// Swizzles a protocol method.
    ///
    /// - Parameters:
    ///   - selector: The selector to swizzle.
    ///   - protocol: The selector's protocol.
    ///   - implementation: The implmentation to replace the method with.
    ///
    func swizzle(_ selector: Selector, `protocol`: Protocol?, implementation: IMP) {
        let method = class_getInstanceMethod(UASwizzler.self, selector)
        if let method = method {
            EMLog.info("Swizzling implementation for \(NSStringFromSelector(selector)) class \(UASwizzler.self)")
            var existing = method_setImplementation(method, implementation)
            if implementation != existing {
                storeOriginalImplementation(&existing, selector: selector)
            }
        } else {
            var description: objc_method_description? = nil
            if let aProtocol = `protocol` {
                description = protocol_getMethodDescription(aProtocol, selector, false, true)
            }
            EMLog.info("Adding implementation for \(NSStringFromSelector(selector)) class \(UASwizzler.self)")
            class_addMethod(UASwizzler.self, selector, implementation, description?.types)
        }
    }
    
    /// Swizzles a class or instance method.
    ///
    /// - Parameters:
    ///   - selector: The selector to swizzle.
    ///   - implementation: The implmentation to replace the method with.
    ///
    func swizzle(_ selector: Selector, implementation: IMP) {
        let method = class_getInstanceMethod(UASwizzler.self, selector)
        if let method = method {
            EMLog.info("Swizzling implementation for \(NSStringFromSelector(selector)) class \(UASwizzler.self)")
            var existing = method_setImplementation(method, implementation)
            if implementation != existing {
                storeOriginalImplementation(&existing, selector: selector)
            }
        } else {
            EMLog.info("Unable to swizzle method for \(NSStringFromSelector(selector)) class \(UASwizzler.self), method not found.")
        }
    }
    
    /// Unswizzles all methods.
    ///
    func unswizzle() {
    }
    
    /// Gets the original implementation for a given selector.
    ///
    /// - Parameter selector: The selector.
    ///
    /// - Returns: The original implmentation, or nil if its not found.
    ///
    func originalImplementation(_ selector: Selector) -> IMP? {
        let selectorString = NSStringFromSelector(selector)
        let value = originalMethods?[selectorString] as? NSValue
        if value == nil {
            return nil
        }
        var implementation: IMP? = nil
        value?.getValue(&implementation)
        return implementation
    }
    
    
    func storeOriginalImplementation(_ implementation: inout IMP, selector: Selector) {
        let selectorString = NSStringFromSelector(selector)
        originalMethods?[selectorString] = NSValue(pointer: &implementation)
    }
    
}
*/
































































class EMPushTracker : NSObject {
    
    var initializedAutomaticPushOpenTracking = false
    var hasAddedObserver = false
    
    func initializeAutomaticPushOpenTracking() {
        if initializedAutomaticPushOpenTracking {
            return
        }
        initializedAutomaticPushOpenTracking = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupAutomaticPushOpenTracking()
        }
    }
    
    func setupAutomaticTokenTracking() {
        
    }
    
    func setupAutomaticPushOpenTracking() {
        guard let appDelegate = UIApplication.shared.delegate else {
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
        
        if let newClass = newClass, class_getInstanceMethod(newClass, NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")) != nil {
            selector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
            newSelector = #selector(NSObject.em_userNotificationCenter(_:newDidReceive:withCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            newSelector = #selector(UIResponder.em_application(_:newDidReceiveRemoteNotification:fetchCompletionHandler:))
        } else if class_getInstanceMethod(aClass, NSSelectorFromString("application:didReceiveRemoteNotification:")) != nil {
            selector = NSSelectorFromString("application:didReceiveRemoteNotification:")
            newSelector = #selector(UIResponder.em_application(_:newDidReceiveRemoteNotification:))
        }
        
        if let selector = selector, let newSelector = newSelector {
            let block = { (_: AnyObject?, _: Selector, _: AnyObject?, pushDictionary: AnyObject?) in
                if let pushDictionary = pushDictionary as? [AnyHashable: Any] {
                    Euromsg.handlePush(pushDictionary: pushDictionary)
                }
            }
            EMSwizzler.swizzleSelector(selector,
                                       withSelector: newSelector,
                                       for: newClass ?? aClass,
                                       name: "push notification opened",
                                       block: block)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "delegate",
           let UNDelegate = UNUserNotificationCenter.current().delegate {
            let delegateClass: AnyClass = type(of: UNDelegate)
            if class_getInstanceMethod(delegateClass, NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")) != nil {
                let selector = NSSelectorFromString("userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:")
                let newSelector = #selector(NSObject.em_userNotificationCenter(_:newDidReceive:withCompletionHandler:))
                let block = { (_: AnyObject?, _: Selector, _: AnyObject?, pushDictionary: AnyObject?) in
                    if let pushDictionary = pushDictionary as? [AnyHashable: Any] {
                        Euromsg.handlePush(pushDictionary: pushDictionary)
                    }
                }
                EMSwizzler.swizzleSelector(selector,
                                           withSelector: newSelector,
                                           for: delegateClass,
                                           name: "push notification opened",
                                           block: block)
            }
        }
    }
    
    deinit {
        if hasAddedObserver {
            UNUserNotificationCenter.current().removeDelegateObserver(emPushTracker: self)
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
    @objc func em_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
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
    
    @objc func em_application(_ application: UIApplication, newDidReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
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
