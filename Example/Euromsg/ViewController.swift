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
    
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var userPropertyTextField: UITextField!
    
    let emailKey = "email"
    let emailPermitKey = "emailPermit"
    
    
    var conf: EMConfiguration!
    
    
    
    override func viewDidLoad() {
        conf = Euromsg.checkConfiguration()
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        pushPermissionSwitch.isOn = conf.properties?.pushPermit == "Y"
        pushNotificationStatusLabel.text = "Push Permission: \(conf.properties?.pushPermit ?? "null")"
        emailPermissionSwitch.isOn = conf.properties?.emailPermit == "Y"
        emailPermissionLabel.text = "Email Permission: \(conf.properties?.emailPermit ?? "null")"
        phonePermissionSwitch.isOn = conf.properties?.gsmPermit == "Y"
        phonePermissionLabel.text = "Phone Permission: \(conf.properties?.gsmPermit ?? "null")"
        emailTextField.text = conf.userProperties?[emailKey] as? String ?? ""
        Euromsg.setUserProperty(key: "TestKey", value: "Test Value")
        guard let value = conf.userProperties?["TestKey"] else { return }
        print(value)
    }
    
    @IBAction func pushNotificationPermissionButtonAction(_ sender: UIButton) {
        Euromsg.askForNotificationPermissionProvisional()
        Euromsg.sync()
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
    
    @IBAction func setEmail(_ sender: Any) {
        if let email = emailTextField.text {
            Euromsg.configure(appAlias: "EuromsgIOSTest", launchOptions: nil, enableLog: true)
            Euromsg.setEmail(email: email.trimmingCharacters(in: .whitespacesAndNewlines), permission: emailPermissionSwitch.isOn)
            Euromsg.sync()
        }
    }
    
    @IBAction func removeUserProperty(_ sender: Any) {
        if let key = userPropertyTextField.text {
            Euromsg.removeUserProperty(key: key.trimmingCharacters(in: .whitespacesAndNewlines))
            Euromsg.sync()
        }
    }
    
    @IBAction func getPushMessages(_ sender: Any) {
        print("🚲 getPushMessages called")
        Euromsg.getPushMessages(completion: { messages in
            for message in messages {
                print("🆔: \(message.pushId ?? "")")
                print("📅: \(message.formattedDateString ?? "")")
                print(message.encoded)
            }
            
        })
    }
    
}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
