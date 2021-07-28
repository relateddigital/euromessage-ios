//
//  PayloadViewController.swift
//  Euromsg_Example
//
//  Created by Umut Can ALPARSLAN on 26.07.2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit

class PayloadViewController: UIViewController {

    @IBOutlet weak var payloadTV: UITextView!
    
    var appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        payloadTV.text = "Gelen push mesajına tıklandığında payload burada gözükecektir"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.payloadTV.text = self.appDelegate.userInfoPayload.decodingUnicodeCharacters
            self.payloadTV.isEditable = false
            self.payloadTV.dataDetectorTypes = .all
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.payloadTV.text = self.appDelegate.userInfoPayload.decodingUnicodeCharacters
            self.payloadTV.isEditable = false
            self.payloadTV.dataDetectorTypes = .all
        }
    }
    

}
