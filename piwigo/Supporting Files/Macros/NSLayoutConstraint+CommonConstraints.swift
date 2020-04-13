//
//  NSLayoutConstraint+CommonConstraints.swift
//
//  Created by Spencer Baker on 8/13/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 13/04/2020
//

import UIKit

extension NSLayoutConstraint {
    // -------------------------- CENTERING --------------------------
    /// Centers the view vertically, this is left to right "|--here--|"
    /// \param view The view to be centered
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintCenterVerticalView(_ view: UIView?) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .centerX, relatedBy: .equal,
                                      toItem: view.superview, attribute: .centerX, multiplier: 1.0, constant: 0)
        }
        return nil
    }

    /// Centers the view horizontally, this is top to bottom
    /// \param view The view to be centered
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintCenterHorizontalView(_ view: UIView?) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .centerY, relatedBy: .equal,
                                      toItem: view.superview, attribute: .centerY, multiplier: 1.0, constant: 0)
        }
        return nil
    }

    /// Centers the view both horizontally and vertically
    /// \param view The view to be centered
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintCenter(_ view: UIView?) -> [NSLayoutConstraint]? {
        return [
        NSLayoutConstraint.constraintCenterHorizontalView(view),
        NSLayoutConstraint.constraintCenterVerticalView(view)
        ].compactMap { $0 }
    }

    // -------------------------- SIZING --------------------------
    /// Match the view's width of it's superview
    /// \param view The view to be matched
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintFillWidth(_ view: UIView?) -> [NSLayoutConstraint]? {
        var left: NSLayoutConstraint? = nil
        if let view = view {
            left = NSLayoutConstraint(item: view, attribute: .left, relatedBy: .equal,
                                      toItem: view.superview, attribute: .left, multiplier: 1.0, constant: 0)
        }
        var right: NSLayoutConstraint? = nil
        if let view = view {
            right = NSLayoutConstraint(item: view, attribute: .right, relatedBy: .equal,
                                       toItem: view.superview, attribute: .right, multiplier: 1.0, constant: 0)
        }
        return [left, right].compactMap { $0 }
    }

    /// Match the view's height of it's superview
    /// \param view The view to be matched
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintFillHeight(_ view: UIView?) -> [NSLayoutConstraint]? {
        var top: NSLayoutConstraint? = nil
        if let view = view {
            top = NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal,
                                     toItem: view.superview, attribute: .top, multiplier: 1.0, constant: 0)
        }
        var bottom: NSLayoutConstraint? = nil
        if let view = view {
            bottom = NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal,
                                        toItem: view.superview, attribute: .bottom, multiplier: 1.0, constant: 0)
        }
        return [top, bottom].compactMap { $0 }
    }

    /// Match the view's width and height of it's superview
    /// \param view The view to be matched in size
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintFillSize(_ view: UIView?) -> [NSLayoutConstraint]? {
        var array: [NSLayoutConstraint] = []
        if let constraint = NSLayoutConstraint.constraintFillWidth(view) {
            array.append(contentsOf: constraint)
        }
        if let constraint = NSLayoutConstraint.constraintFillHeight(view) {
            array.append(contentsOf: constraint)
        }
        return array
    }

    /// Sets a view's height to a specific size
    /// \param view The view whose height is to be changed
    /// \param height The specific height wanted
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(_ view: UIView?, toHeight height: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal,
                                      toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: height)
        }
        return nil
    }

    /// Sets a view's width to a specific size
    /// \param view The view whose width is to be changed
    /// \param width The specific width wanted
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(_ view: UIView?, toWidth width: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal,
                                      toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: width)
        }
        return nil
    }

    /// Sets a view's size
    /// \param view The view whose size is to be changed
    /// \param size The specific CGSize wanted
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintView(_ view: UIView?, to size: CGSize) -> [NSLayoutConstraint]? {
        if let view = view {
            return [NSLayoutConstraint.constraintView(view, toHeight: size.height),
                    NSLayoutConstraint.constraintView(view, toWidth: size.width)
            ].compactMap { $0 }
        }
        return nil
    }

    /// Sets view1's baseline equal to view2's baseline
    /// \param view1 The view whose baseline is to be changed
    /// \param view2 The view whose baseline is to be used to set the other
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(toSameBase view1: UIView?, equalTo view2: UIView?) -> NSLayoutConstraint? {
        if let view1 = view1 {
            if let view2 = view2 {
                return NSLayoutConstraint(item: view1, attribute: NSLayoutConstraint.Attribute.lastBaseline, relatedBy: .equal,
                                          toItem: view2, attribute: NSLayoutConstraint.Attribute.lastBaseline, multiplier: 1.0, constant: 0)
            }
        }
        return nil
    }

    /// Constrains a view's width to be equal to it's height
    /// \param view The view to be constrained
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintViewWidth(toEqualHeight view: UIView?) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal,
                                      toItem: view, attribute: .height, multiplier: 1.0, constant: 0)
        }
        return nil
    }

    /// Constrains a view's height to be equal to it's width
    /// \param view The view to be constrained
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintViewHeight(toEqualWidth view: UIView?) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal,
                                      toItem: view, attribute: .width, multiplier: 1.0, constant: 0)
        }
        return nil
    }

    // -------------------------- FRAME --------------------------
    /// Constrains a view a specific amount from the left of it's superview
    /// \param view The view to be constrained
    /// \param leftAmount The specific amount of pixels for the view to be from the left
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(fromLeft view: UIView?, amount leftAmount: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .left, relatedBy: .equal,
                                      toItem: view.superview, attribute: .left, multiplier: 1.0, constant: leftAmount)
        }
        return nil
    }

    /// Constrains a view a specific amount from the right of it's superview
    /// \param view The view to be constrained
    /// \param rightAmount The specific amount of pixels for the view to be from the right
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(fromRight view: UIView?, amount rightAmount: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .right, relatedBy: .equal,
                                      toItem: view.superview, attribute: .right, multiplier: 1.0, constant: -rightAmount)
        }
        return nil
    }

    /// Constrains a view a specific amount from the top of it's superview
    /// \param view The view to be constrained
    /// \param topAmount The specific amount of pixels for the view to be from the top
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(fromTop view: UIView?, amount topAmount: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal,
                                      toItem: view.superview, attribute: .top, multiplier: 1.0, constant: topAmount)
        }
        return nil
    }

    /// Constrains a view a specific amount from the bottom of it's superview
    /// \param view The view to be constrained
    /// \param bottomAmount The specific amount of pixels for the view to be from the bottom
    /// \returns A NSLayoutConstraint is returned
    @objc
    class func constraintView(fromBottom view: UIView?, amount bottomAmount: CGFloat) -> NSLayoutConstraint? {
        if let view = view {
            return NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal,
                                      toItem: view.superview, attribute: .bottom, multiplier: 1.0, constant: -bottomAmount)
        }
        return nil
    }

    /// Constrains a view's origin to be the same as another
    /// \param view The view to be moved to the other
    /// \param copyView The view whose location is to be used
    /// \returns An array of NSLayoutConstraints is returned
    @objc
    class func constraintView(toSameLocation view: UIView?, as copyView: UIView?) -> [NSLayoutConstraint]? {
        if let view = view {
            return [
            NSLayoutConstraint(item: view, attribute: .left, relatedBy: .equal,
                               toItem: copyView, attribute: .left, multiplier: 1.0, constant: 0),
            NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal,
                               toItem: copyView, attribute: .top, multiplier: 1.0, constant: 0)
            ]
        }
        return nil
    }
}
