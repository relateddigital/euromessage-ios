//
//  EMNotificationCarousel.swift
//  Euromsg
//
//  Created by Muhammed ARAFA on 12.07.2020.
//  Copyright © 2020 Muhammed ARAFA. All rights reserved.
//

import UserNotifications
import UserNotificationsUI

public class EMNotificationCarousel: UIView {

    @IBOutlet var contentView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    let identifier = "CarouselCell"

    var bestAttemptContent: UNMutableNotificationContent?
    var carouselElements: [EMMessage.Element] = []
    var currentIndex: Int = 0
    var userInfo: [AnyHashable: Any]?
    public var completion: ((_ url: URL?, _ bestAttemptContent: UNMutableNotificationContent?) -> Void)?
    public weak var delegate: CarouselDelegate?
    
    

    public static func initView() -> EMNotificationCarousel {
        let view = EMNotificationCarousel()
        return view
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    func commonInit() {
        Bundle(for: type(of: self)).loadNibNamed("EMNotificationCarousel", owner: self, options: nil)
        contentView.fixInView(self)
    }

    public func didReceive(_ notification: UNNotification) {
        self.bestAttemptContent = (notification.request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let userInfo = bestAttemptContent?.userInfo,
            let data = try? JSONSerialization.data(withJSONObject: userInfo,
                                                   options: []) else { return }
        self.userInfo = userInfo
        let pushDetail = try? JSONDecoder.init().decode(EMMessage.self,
                                                        from: data)
        guard let list = pushDetail?.elements else { return }
        self.carouselElements = list
        DispatchQueue.main.async {
            self.collectionView.register(UINib(nibName: self.identifier, bundle: Bundle(for: type(of: self))), forCellWithReuseIdentifier: self.identifier)
            self.collectionView.delegate = self
            self.collectionView.dataSource = self
            self.collectionView.contentInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
            self.collectionView.reloadData()
        }
    }

    public func didReceive(_ response: UNNotificationResponse, completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void) {
        if response.actionIdentifier == "carousel.next" {
            self.scrollNextItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        } else if response.actionIdentifier == "carousel.previous" {
            self.scrollPreviousItem()
            completion(UNNotificationContentExtensionResponseOption.doNotDismiss)
        } else {
            completion(UNNotificationContentExtensionResponseOption.dismissAndForwardAction)
        }
    }
    

    @IBAction func swipeLeft(_ sender: UISwipeGestureRecognizer) {
        scrollNextItem()
    }

    @IBAction func swipeRight(_ sender: UISwipeGestureRecognizer) {
        scrollPreviousItem()
    }

    private func scrollNextItem() {
        self.currentIndex == (self.carouselElements.count - 1) ? (self.currentIndex = 0) : ( self.currentIndex += 1 )
        let indexPath = IndexPath(row: self.currentIndex, section: 0)
        let cond = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1)
        self.collectionView.contentInset.right = cond ? 10.0 : 20.0
        self.collectionView.contentInset.left = cond ? 10.0 : 20.0
        self.collectionView.scrollToItem(at: indexPath, at: UICollectionView.ScrollPosition.right, animated: true)
    }

    private func scrollPreviousItem() {
        self.currentIndex == 0 ? (self.currentIndex = self.carouselElements.count - 1) : ( self.currentIndex -= 1 )
        let indexPath = IndexPath(row: self.currentIndex, section: 0)
        let cond = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1)
        self.collectionView.contentInset.right = cond ? 10.0 : 20.0
        self.collectionView.contentInset.left = cond ? 10.0 : 20.0
        self.collectionView.scrollToItem(at: indexPath, at: UICollectionView.ScrollPosition.left, animated: true)
    }

}

extension EMNotificationCarousel: UICollectionViewDelegate, UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let userInfo = bestAttemptContent?.userInfo else { return }
        Euromsg.handlePush(pushDictionary: userInfo)
        guard indexPath.row < carouselElements.count else { return }
        self.delegate?.selectedItem(carouselElements[indexPath.row])
        if let urlString = self.carouselElements[indexPath.row].url, let url = URL(string: urlString) {
                completion?(url, bestAttemptContent)
        } else {
            completion?(nil, bestAttemptContent)
        }
        self.carouselElements = []
        collectionView.reloadData()
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
        return self.carouselElements.count
    }

    public func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? CarouselCell
        let element = self.carouselElements[indexPath.row]
        cell?.setupCell(imageUrl: element.picture,
                       title: element.title,
                       content: element.content)
        cell?.layer.cornerRadius = 8.0
        return cell!
    }
}

extension EMNotificationCarousel: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = self.collectionView.frame.width
        let cond = (indexPath.row == 0 || indexPath.row == self.carouselElements.count - 1)
        let cellWidth = cond ? (width - 30) : (width - 40)
        return CGSize(width: cellWidth, height: width - 20.0)
    }

}

extension UIView {
    func fixInView(_ container: UIView!) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.frame = container.frame
        container.addSubview(self)
        NSLayoutConstraint(item: self,
                           attribute: .leading,
                           relatedBy: .equal,
                           toItem: container,
                           attribute: .leading,
                           multiplier: 1.0,
                           constant: 0).isActive = true
        NSLayoutConstraint(item: self,
                           attribute: .trailing,
                           relatedBy: .equal,
                           toItem: container,
                           attribute: .trailing,
                           multiplier: 1.0,
                           constant: 0).isActive = true
        NSLayoutConstraint(item: self,
                           attribute: .top,
                           relatedBy: .equal,
                           toItem: container,
                           attribute: .top,
                           multiplier: 1.0,
                           constant: 0).isActive = true
        NSLayoutConstraint(item: self,
                           attribute: .bottom,
                           relatedBy: .equal,
                           toItem: container,
                           attribute: .bottom,
                           multiplier: 1.0,
                           constant: 0).isActive = true
    }
}

public protocol CarouselDelegate: AnyObject {
    func selectedItem(_ element: EMMessage.Element)
}
