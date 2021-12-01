//
//  EMNotificationViewController.swift
//  NotificationContent
//
//  Created by Muhammed ARAFA on 12.07.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import Euromsg

@objc(EMNotificationViewController)
class EMNotificationViewController: UIViewController, UNNotificationContentExtension {
    
    let carouselView = EMNotificationCarousel.initView()
    var completion: ((_ url: URL?, _ userInfo: [AnyHashable: Any]?) -> Void)?
    
    var notificationRequestIdentifier = ""
    
    func didReceive(_ notification: UNNotification) {
        notificationRequestIdentifier = notification.request.identifier
        print("didReceive notificationRequestIdentifier: \(notificationRequestIdentifier)")
        Euromsg.configure(appAlias: "EuromsgIOSTest", launchOptions: nil, enableLog: true)
        carouselView.didReceive(notification)
    }
    func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        carouselView.didReceive(response, completionHandler: completion)
    }
    override func loadView() {
        completion = { [weak self] url, userInfo in
            if let url = url {
                self?.extensionContext?.open(url)
            } else {
                if #available(iOSApplicationExtension 12.0, *) {
                    self?.extensionContext?.performNotificationDefaultAction()
                }
            }
            
            if let identifier = self?.notificationRequestIdentifier {
                print("didReceiveResponse notificationRequestIdentifier: \(identifier)")
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            }
            
        }
        carouselView.completion = completion
        carouselView.delegate = self
        self.view = carouselView
    }
}

/**
 Add if you want to track which carousel element has been selected
 */
extension EMNotificationViewController: CarouselDelegate {
    
    func selectedItem(_ element: EMMessage.Element) {
        // Add your work...
        print("Selected element is => \(element)")
    }
    
}
