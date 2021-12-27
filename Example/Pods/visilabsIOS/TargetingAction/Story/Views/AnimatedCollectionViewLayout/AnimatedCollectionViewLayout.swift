//
//  AnimatedCollectionViewLayout.swift
//  AnimatedCollectionViewLayout
//
//  Created by Jin Wang on Feb 8, 2017.
//  Copyright © 2017 Uthoft. All rights reserved.
//

import Foundation
import UIKit

/// A `UICollectionViewFlowLayout` subclass enables custom transitions between cells.
open class AnimatedCollectionViewLayout: UICollectionViewFlowLayout {

    /// The animator that would actually handle the transitions.
    open var animator: LayoutAttributesAnimator?

    /// Overrided so that we can store extra information in the layout attributes.
    open override class var layoutAttributesClass: AnyClass { return AnimatedCollectionViewLayoutAttributes.self }

    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        return attributes.compactMap { $0.copy() as?
            AnimatedCollectionViewLayoutAttributes }.map { self.transformLayoutAttributes($0) }
    }

    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // We have to return true here so that the layout attributes would be recalculated
        // everytime we scroll the collection view.
        return true
    }

    /////// START - Added code additionally to fix content not displayed properly when rotating device.
    private var focusedIndexPath: IndexPath?

    override open func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
        super.prepare(forAnimatedBoundsChange: oldBounds)
        focusedIndexPath = collectionView?.indexPathsForVisibleItems.first
    }

    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        guard let indexPath = focusedIndexPath,
              let attributes = layoutAttributesForItem(at: indexPath),
              let collectionView = collectionView else {
                return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
        }
        return CGPoint(x: attributes.frame.origin.x - collectionView.contentInset.left,
                       y: attributes.frame.origin.y - collectionView.contentInset.top)
    }

    override open func finalizeAnimatedBoundsChange() {
        super.finalizeAnimatedBoundsChange()
        focusedIndexPath = nil
    }
    /////// END

    private func transformLayoutAttributes(_ attributes: AnimatedCollectionViewLayoutAttributes)
    -> UICollectionViewLayoutAttributes {

        guard let collectionView = self.collectionView else { return attributes }

        let attr = attributes

        /**
         The position for each cell is defined as the ratio of the distance between
         the center of the cell and the center of the collectionView and the collectionView width/height
         depending on the scroll direction. It can be negative if the cell is, for instance,
         on the left of the screen if you're scrolling horizontally.
         */

        let distance: CGFloat
        let itemOffset: CGFloat

        if scrollDirection == .horizontal {
            distance = collectionView.frame.width
            itemOffset = attr.center.x - collectionView.contentOffset.x
            attr.startOffset = (attr.frame.origin.x - collectionView.contentOffset.x) / attr.frame.width
            attr.endOffset = (attr.frame.origin.x - collectionView.contentOffset.x - collectionView.frame.width)
                / attr.frame.width
        } else {
            distance = collectionView.frame.height
            itemOffset = attr.center.y - collectionView.contentOffset.y
            attr.startOffset = (attr.frame.origin.y - collectionView.contentOffset.y) / attr.frame.height
            attr.endOffset = (attr.frame.origin.y - collectionView.contentOffset.y - collectionView.frame.height)
                / attr.frame.height
        }

        attr.scrollDirection = scrollDirection
        attr.middleOffset = itemOffset / distance - 0.5

        // Cache the contentView since we're going to use it a lot.
        if attr.contentView == nil,
            let contentView = collectionView.cellForItem(at: attributes.indexPath)?.contentView {
            attr.contentView = contentView
        }

        animator?.animate(collectionView: collectionView, attributes: attr)

        return attr
    }
}

/// A custom layout attributes that contains extra information.
open class AnimatedCollectionViewLayoutAttributes: UICollectionViewLayoutAttributes {
    public var contentView: UIView?
    public var scrollDirection: UICollectionView.ScrollDirection = .vertical

    /// The ratio of the distance between the start of the cell and the start of the collectionView
    ///  and the height/width of the cell depending on the scrollDirection.
    ///   It's 0 when the start of the cell aligns the start of the collectionView.
    ///    It gets positive when the cell moves towards the scrolling direction (right/down)
    ///     while getting negative when moves opposite.
    public var startOffset: CGFloat = 0

    /// The ratio of the distance between the center of the cell and the center of the collectionView
    ///  and the height/width of the cell depending on the scrollDirection. It's 0 when the center of the cell aligns
    ///   the center of the collectionView. It gets positive when the cell moves
    ///    towards the scrolling direction (right/down) while getting negative when moves opposite.
    public var middleOffset: CGFloat = 0

    /// The ratio of the distance between the **start** of the cell and the end of the collectionView
    /// and the height/width of the cell depending on the scrollDirection. It's 0 when the
    /// **start** of the cell aligns the end of the collectionView. It gets positive when the cell moves
    /// towards the scrolling direction (right/down) while getting negative when moves opposite.
    public var endOffset: CGFloat = 0

    open override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as? AnimatedCollectionViewLayoutAttributes
            ?? AnimatedCollectionViewLayoutAttributes()
        copy.contentView = contentView
        copy.scrollDirection = scrollDirection
        copy.startOffset = startOffset
        copy.middleOffset = middleOffset
        copy.endOffset = endOffset
        return copy
    }

    open override func isEqual(_ object: Any?) -> Bool {
        guard let obj = object as? AnimatedCollectionViewLayoutAttributes else { return false }

        return super.isEqual(obj)
            && obj.contentView == contentView
            && obj.scrollDirection == scrollDirection
            && obj.startOffset == startOffset
            && obj.middleOffset == middleOffset
            && obj.endOffset == endOffset
    }
}
