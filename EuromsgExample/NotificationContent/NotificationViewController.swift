//
//  NotificationViewController.swift
//  NotificationContent
//
//  Created by Muhammed ARAFA on 9.05.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import Euromsg

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var bestAttemptContent: UNMutableNotificationContent?

    var carouselElements : [EMMessage.Element] = []
    var currentIndex : Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.contentInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
    }

    func didReceive(_ notification: UNNotification) {
        
        self.bestAttemptContent = (notification.request.content.mutableCopy() as? UNMutableNotificationContent)
        
        guard let userInfo = bestAttemptContent?.userInfo,
            let data = try? JSONSerialization.data(withJSONObject: userInfo,
                                                   options: []) else { return }
        let pushDetail = try? JSONDecoder.init().decode(EMMessage.self,
                                                        from: data)
        
        guard let list = pushDetail?.elements else { return }
        self.carouselElements = list
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "carousel.next" {
            self.scrollNextItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        }else if response.actionIdentifier == "carousel.previous" {
            self.scrollPreviousItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        }else {
            completion(UNNotificationContentExtensionResponseOption.dismissAndForwardAction)
        }
    }

    @IBAction func swipeLeft(_ sender: UISwipeGestureRecognizer) {
        scrollNextItem()
    }

    @IBAction func swipeRight(_ sender: UISwipeGestureRecognizer) {
        scrollPreviousItem()
    }

    private func scrollNextItem(){
        self.currentIndex == (self.carouselElements.count - 1) ? (self.currentIndex = 0) : ( self.currentIndex += 1 )
        let indexPath = IndexPath(row: self.currentIndex, section: 0)
        self.collectionView.contentInset.right = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1) ? 10.0 : 20.0
        self.collectionView.contentInset.left = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1) ? 10.0 : 20.0
        self.collectionView.scrollToItem(at: indexPath, at: UICollectionView.ScrollPosition.right, animated: true)
    }

    private func scrollPreviousItem(){
        self.currentIndex == 0 ? (self.currentIndex = self.carouselElements.count - 1) : ( self.currentIndex -= 1 )
        let indexPath = IndexPath(row: self.currentIndex, section: 0)
        self.collectionView.contentInset.right = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1) ? 10.0 : 20.0
        self.collectionView.contentInset.left = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1) ? 10.0 : 20.0
        self.collectionView.scrollToItem(at: indexPath, at: UICollectionView.ScrollPosition.left, animated: true)
    }

}

extension NotificationViewController : UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let userInfo = bestAttemptContent?.userInfo else { return }
        Euromsg.handlePush(pushDictionary: userInfo)
        guard let urlString = self.carouselElements[indexPath.row].url,
              let url = URL(string: urlString) else {
                let urlString = "euromsgExample://"
                if let url = URL(string: urlString) {
                    self.extensionContext?.open(url)
                 }
                return
        }
        self.extensionContext?.open(url)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.carouselElements.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = "CarouselCell"
        self.collectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! CarouselCell
        let element = self.carouselElements[indexPath.row]
        cell.setupCell(imageUrl: element.picture,
                       title: element.title,
                       content: element.content)
        cell.layer.cornerRadius = 8.0
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = self.collectionView.frame.width
        let cellWidth = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1) ? (width - 30) : (width - 40)
        return CGSize(width: cellWidth, height: width - 20.0)
    }

}
