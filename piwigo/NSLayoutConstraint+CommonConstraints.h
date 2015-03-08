//
//  NSLayoutConstraint+CommonConstraints.h
//
//  Created by Spencer Baker on 8/13/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSLayoutConstraint (CommonConstraints)


// -------------------------- CENTERING --------------------------
/*! Centers the view vertically, this is left to right "|--here--|"
 * \param view The view to be centered
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintCenterVerticalView:(UIView*)view;

/*! Centers the view horizontally, this is top to bottom
 * \param view The view to be centered
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintCenterHorizontalView:(UIView*)view;

/*! Centers the view both horizontally and vertically
 * \param view The view to be centered
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintCenterView:(UIView*)view;



// -------------------------- SIZING --------------------------
/*! Match the view's width of it's superview
 * \param view The view to be matched
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintFillWidth:(UIView*)view;

/*! Match the view's height of it's superview
 * \param view The view to be matched
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintFillHeight:(UIView*)view;

/*! Match the view's width and height of it's superview
 * \param view The view to be matched in size
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintFillSize:(UIView*)view;

/*! Sets a view's height to a specific size
 * \param view The view whose height is to be changed
 * \param height The specific height wanted
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintView:(UIView*)view toHeight:(CGFloat)height;

/*! Sets a view's width to a specific size
 * \param view The view whose width is to be changed
 * \param width The specific width wanted
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintView:(UIView*)view toWidth:(CGFloat)width;

/*! Sets a view's size
 * \param view The view whose size is to be changed
 * \param size The specific CGSize wanted
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintView:(UIView*)view toSize:(CGSize)size;

/*! Sets view1's baseline equal to view2's baseline
 * \param view1 The view whose baseline is to be changed
 * \param view2 The view whose baseline is to be used to set the other
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewToSameBase:(UIView*)view1 equalToView:(UIView*)view2;

/*! Constrains a view's width to be equal to it's height
 * \param view The view to be constrained
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewWidthToEqualHeight:(UIView*)view;

/*! Constrains a view's height to be equal to it's width
 * \param view The view to be constrained
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewHeightToEqualWidth:(UIView*)view;



// -------------------------- FRAME --------------------------
/*! Constrains a view a specific amount from the left of it's superview
 * \param view The view to be constrained
 * \param leftAmount The specific amount of pixels for the view to be from the left
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewFromLeft:(UIView*)view amount:(CGFloat)leftAmount;

/*! Constrains a view a specific amount from the right of it's superview
 * \param view The view to be constrained
 * \param rightAmount The specific amount of pixels for the view to be from the right
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewFromRight:(UIView*)view amount:(CGFloat)rightAmount;

/*! Constrains a view a specific amount from the top of it's superview
 * \param view The view to be constrained
 * \param topAmount The specific amount of pixels for the view to be from the top
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewFromTop:(UIView*)view amount:(CGFloat)topAmount;

/*! Constrains a view a specific amount from the bottom of it's superview
 * \param view The view to be constrained
 * \param bottomAmount The specific amount of pixels for the view to be from the bottom
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintViewFromBottom:(UIView*)view amount:(CGFloat)bottomAmount;

/*! Constrains a view's origin to be the same as another
 * \param view The view to be moved to the other
 * \param copyView The view whose location is to be used
 * \returns An array of NSLayoutConstraints is returned
 */
+(NSArray*)constraintViewToSameLocation:(UIView*)view asView:(UIView*)copyView;

@end
