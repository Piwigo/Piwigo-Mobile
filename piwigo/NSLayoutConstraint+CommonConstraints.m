//
//  NSLayoutConstraint+CommonConstraints.m
//
//  Created by Spencer Baker on 8/13/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "NSLayoutConstraint+CommonConstraints.h"

@implementation NSLayoutConstraint (CommonConstraints)

+(NSLayoutConstraint*)constraintCenterVerticalView:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeCenterX
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeCenterX
									   multiplier:1.0
										 constant:0];
}

+(NSLayoutConstraint*)constraintCenterHorizontalView:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeCenterY
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeCenterY
									   multiplier:1.0
										 constant:0];
}

+(NSArray*)constraintCenterView:(UIView*)view
{
	return @[
			 [NSLayoutConstraint constraintCenterHorizontalView:view],
			 [NSLayoutConstraint constraintCenterVerticalView:view]
			 ];
}

+(NSArray*)constraintFillWidth:(UIView*)view
{
	NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:view
															attribute:NSLayoutAttributeLeft
															relatedBy:NSLayoutRelationEqual
															   toItem:view.superview
															attribute:NSLayoutAttributeLeft
														   multiplier:1.0
															 constant:0];
	NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:view
															 attribute:NSLayoutAttributeRight
															 relatedBy:NSLayoutRelationEqual
																toItem:view.superview
															 attribute:NSLayoutAttributeRight
															multiplier:1.0
															  constant:0];
	return @[left, right];
}

+(NSArray*)constraintFillHeight:(UIView*)view
{
	NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:view
														   attribute:NSLayoutAttributeTop
														   relatedBy:NSLayoutRelationEqual
															  toItem:view.superview
														   attribute:NSLayoutAttributeTop
														  multiplier:1.0
															constant:0];
	NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:view
															  attribute:NSLayoutAttributeBottom
															  relatedBy:NSLayoutRelationEqual
																 toItem:view.superview
															  attribute:NSLayoutAttributeBottom
															 multiplier:1.0
															   constant:0];
	return @[top, bottom];
}

+(NSArray*)constraintFillSize:(UIView*)view
{
	NSMutableArray *array = [NSMutableArray new];
	[array addObjectsFromArray:[NSLayoutConstraint constraintFillWidth:view]];
	[array addObjectsFromArray:[NSLayoutConstraint constraintFillHeight:view]];
	return array;
}

+(NSLayoutConstraint*)constraintView:(UIView*)view toHeight:(CGFloat)height
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeHeight
										relatedBy:NSLayoutRelationEqual
										   toItem:nil
										attribute:NSLayoutAttributeNotAnAttribute
									   multiplier:1.0
										 constant:height];
}

+(NSLayoutConstraint*)constraintView:(UIView*)view toWidth:(CGFloat)width
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeWidth
										relatedBy:NSLayoutRelationEqual
										   toItem:nil
										attribute:NSLayoutAttributeNotAnAttribute
									   multiplier:1.0
										 constant:width];
}

+(NSArray*)constraintView:(UIView*)view toSize:(CGSize)size
{
	return @[
			 [NSLayoutConstraint constraintView:view toHeight:size.height],
			 [NSLayoutConstraint constraintView:view toWidth:size.width]
			 ];
}

+(NSLayoutConstraint*)constraintViewToSameBase:(UIView*)view1 equalToView:(UIView*)view2
{
	return [NSLayoutConstraint constraintWithItem:view1
										 attribute:NSLayoutAttributeBaseline
										 relatedBy:NSLayoutRelationEqual
											toItem:view2
										 attribute:NSLayoutAttributeBaseline
										multiplier:1.0
										  constant:0];
}

+(NSLayoutConstraint*)constraintViewFromLeft:(UIView*)view amount:(CGFloat)leftAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeLeft
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeLeft
									   multiplier:1.0
										 constant:leftAmount];
}

+(NSLayoutConstraint*)constraintViewFromRight:(UIView*)view amount:(CGFloat)rightAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeRight
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeRight
									   multiplier:1.0
										 constant:-rightAmount];
}

+(NSLayoutConstraint*)constraintViewFromTop:(UIView*)view amount:(CGFloat)topAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeTop
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeTop
									   multiplier:1.0
										 constant:topAmount];
}

+(NSLayoutConstraint*)constraintViewFromBottom:(UIView*)view amount:(CGFloat)bottomAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeBottom
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeBottom
									   multiplier:1.0
										 constant:-bottomAmount];
}

+(NSLayoutConstraint*)constraintViewWidthToEqualHeight:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeWidth
										relatedBy:NSLayoutRelationEqual
										   toItem:view
										attribute:NSLayoutAttributeHeight
									   multiplier:1.0
										 constant:0];
}


+(NSLayoutConstraint*)constraintViewHeightToEqualWidth:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeHeight
										relatedBy:NSLayoutRelationEqual
										   toItem:view
										attribute:NSLayoutAttributeWidth
									   multiplier:1.0
										 constant:0];
}

+(NSArray*)constraintViewToSameLocation:(UIView*)view asView:(UIView*)copyView
{
	return @[
			 [NSLayoutConstraint constraintWithItem:view
										  attribute:NSLayoutAttributeLeft
										  relatedBy:NSLayoutRelationEqual
											 toItem:copyView
										  attribute:NSLayoutAttributeLeft
										 multiplier:1.0
										   constant:0],
			 [NSLayoutConstraint constraintWithItem:view
										  attribute:NSLayoutAttributeTop
										  relatedBy:NSLayoutRelationEqual
											 toItem:copyView
										  attribute:NSLayoutAttributeTop
										 multiplier:1.0
										   constant:0]
			 ];
}

@end
