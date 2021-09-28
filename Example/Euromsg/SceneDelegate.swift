//
//  SceneDelegate.swift
//  EuromsgExample
//
//  Created by Muhammed ARAFA on 30.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit
import Euromsg

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard (scene as? UIWindowScene) != nil else { return }
        if let userInfo = connectionOptions.notificationResponse?.notification.request.content.userInfo {
            //Euromsg.handlePush(pushDictionary: userInfo)
        }

    }

    func sceneDidDisconnect(_ scene: UIScene) {

    }

    func sceneDidBecomeActive(_ scene: UIScene) {

    }

    func sceneWillResignActive(_ scene: UIScene) {

    }

    func sceneWillEnterForeground(_ scene: UIScene) {

    }

    func sceneDidEnterBackground(_ scene: UIScene) {

    }
}
