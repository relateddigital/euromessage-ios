//
//  ViewController.swift
//  EuromsgExample
//
//  Created by Muhammed ARAFA on 30.03.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit
import Euromsg

class ViewController: UIViewController {

    @IBOutlet weak var pushNotificationStatusLabel: UILabel!
    @IBOutlet weak var pushPermissionSwitch: UISwitch!
    @IBOutlet weak var emailPermissionLabel: UILabel!
    @IBOutlet weak var emailPermissionSwitch: UISwitch!
    @IBOutlet weak var phonePermissionLabel: UILabel!
    @IBOutlet weak var phonePermissionSwitch: UISwitch!

    let conf = Euromsg.checkConfiguration()

    override func viewDidLoad() {
        super.viewDidLoad()
        pushPermissionSwitch.isOn = conf.properties?.pushPermit == "Y"
        pushNotificationStatusLabel.text = "Push Permission: \(conf.properties?.pushPermit ?? "null")"
        emailPermissionSwitch.isOn = conf.properties?.emailPermit == "Y"
        emailPermissionLabel.text = "Email Permission: \(conf.properties?.emailPermit ?? "null")"
        phonePermissionSwitch.isOn = conf.properties?.gsmPermit == "Y"
        phonePermissionLabel.text = "Phone Permission: \(conf.properties?.gsmPermit ?? "null")"
        Euromsg.setUserProperty(key: "TestKey", value: "Test Value")
        guard let value = conf.userProperties?["TestKey"] else { return }
        print(value)
    }

    @IBAction func pushNotificationPermissionButtonAction(_ sender: UIButton) {
        Euromsg.askForNotificationPermission()
    }

    @IBAction func pushNotificationPermissionSwitchAction(_ sender: UISwitch) {
        Euromsg.setPushNotification(permission: sender.isOn)
        if sender.isOn {
            #if targetEnvironment(simulator)
            Euromsg.registerToken(tokenData: Data(base64Encoded: "dG9rZW4="))
            #else
            Euromsg.registerForPushNotifications()
            #endif
        }
        pushNotificationStatusLabel.text = "Push Permission: \(conf.properties?.pushPermit ?? "null")"
    }

    @IBAction func emailPermissionSwitchAction(_ sender: UISwitch) {
        Euromsg.setEmail(permission: sender.isOn)
        emailPermissionLabel.text = "Email Permission: \(conf.properties?.emailPermit ?? "null")"
    }

    @IBAction func phonePermissionSwitchAction(_ sender: UISwitch) {
        Euromsg.setPhoneNumber(permission: sender.isOn)
        phonePermissionLabel.text = "Phone Permission: \(conf.properties?.gsmPermit ?? "null")"
    }

}

