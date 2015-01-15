//
//  NSLayoutConstraint+CommonConstraints.h
//  zombiekit
//
//  Created by Spencer Baker on 8/13/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSLayoutConstraint (CommonConstraints)

/*! Centers the view left to right |--here--|
 * \param view View to be centered
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintHorizontalCenterView:(UIView*)view;

/*! Centers the view top to bottom
 * \param view View to be centered
 * \returns A NSLayoutConstraint is returned
 */
+(NSLayoutConstraint*)constraintVerticalCenterView:(UIView*)view;

+(NSArray*)constraintViewToCenter:(UIView*)view;

+(NSArray*)constraintFillWidth:(UIView*)view;

+(NSArray*)constraintFillHeight:(UIView*)view;

+(NSArray*)constraintFillSize:(UIView*)view;

+(NSLayoutConstraint*)constrainViewToHeight:(UIView*)view height:(NSInteger)height;
+(NSLayoutConstraint*)constrainViewToWidth:(UIView*)view width:(NSInteger)width;
+(NSArray*)constrainViewToSize:(UIView*)view size:(CGSize)size;

+(NSLayoutConstraint*)constrainViewToSameBase:(UIView*)view equalBaseAsView:(UIView*)view2;
+(NSLayoutConstraint*)constrainViewFromLeft:(UIView*)view amount:(CGFloat)leftAmount;
+(NSLayoutConstraint*)constrainViewFromRight:(UIView*)view amount:(CGFloat)rightAmount;
+(NSLayoutConstraint*)constrainViewFromTop:(UIView*)view amount:(CGFloat)topAmount;
+(NSLayoutConstraint*)constrainViewFromBottom:(UIView*)view amount:(CGFloat)bottomAmount;

+(NSLayoutConstraint*)constrainViewWidthToEqualHeight:(UIView*)view;
+(NSLayoutConstraint*)constrainViewHeightToEqualWidth:(UIView*)view;
+(NSArray*)constrainViewToSameLocation:(UIView*)view asView:(UIView*)copyView;

@end
