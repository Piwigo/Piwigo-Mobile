//
//  NSLayoutConstraint+CommonConstraints.m
//  zombiekit
//
//  Created by Spencer Baker on 8/13/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "NSLayoutConstraint+CommonConstraints.h"

@implementation NSLayoutConstraint (CommonConstraints)

+(NSLayoutConstraint*)constraintHorizontalCenterView:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeCenterX
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeCenterX
									   multiplier:1.0
										 constant:0];
}

+(NSLayoutConstraint*)constraintVerticalCenterView:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeCenterY
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeCenterY
									   multiplier:1.0
										 constant:0];
}

+(NSArray*)constraintViewToCenter:(UIView*)view
{
	return @[
			 [NSLayoutConstraint constraintVerticalCenterView:view],
			 [NSLayoutConstraint constraintHorizontalCenterView:view]
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

+(NSLayoutConstraint*)constrainViewToHeight:(UIView*)view height:(NSInteger)height
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeHeight
										relatedBy:NSLayoutRelationEqual
										   toItem:nil
										attribute:NSLayoutAttributeNotAnAttribute
									   multiplier:1.0
										 constant:height];
}

+(NSLayoutConstraint*)constrainViewToWidth:(UIView*)view width:(NSInteger)width
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeWidth
										relatedBy:NSLayoutRelationEqual
										   toItem:nil
										attribute:NSLayoutAttributeNotAnAttribute
									   multiplier:1.0
										 constant:width];
}

+(NSArray*)constrainViewToSize:(UIView*)view size:(CGSize)size
{
	return @[
			 [NSLayoutConstraint constrainViewToHeight:view height:size.height],
			 [NSLayoutConstraint constrainViewToWidth:view width:size.width]
			 ];
}

+(NSLayoutConstraint*)constrainViewToSameBase:(UIView*)view equalBaseAsView:(UIView*)view2
{
	return [NSLayoutConstraint constraintWithItem:view
										 attribute:NSLayoutAttributeBaseline
										 relatedBy:NSLayoutRelationEqual
											toItem:view2
										 attribute:NSLayoutAttributeBaseline
										multiplier:1.0
										  constant:0];
}

+(NSLayoutConstraint*)constrainViewFromLeft:(UIView*)view amount:(CGFloat)leftAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeLeft
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeLeft
									   multiplier:1.0
										 constant:leftAmount];
}

+(NSLayoutConstraint*)constrainViewFromRight:(UIView*)view amount:(CGFloat)rightAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeRight
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeRight
									   multiplier:1.0
										 constant:-rightAmount];
}

+(NSLayoutConstraint*)constrainViewFromTop:(UIView*)view amount:(CGFloat)topAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeTop
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeTop
									   multiplier:1.0
										 constant:topAmount];
}

+(NSLayoutConstraint*)constrainViewFromBottom:(UIView*)view amount:(CGFloat)bottomAmount
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeBottom
										relatedBy:NSLayoutRelationEqual
										   toItem:view.superview
										attribute:NSLayoutAttributeBottom
									   multiplier:1.0
										 constant:-bottomAmount];
}

+(NSLayoutConstraint*)constrainViewWidthToEqualHeight:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeWidth
										relatedBy:NSLayoutRelationEqual
										   toItem:view
										attribute:NSLayoutAttributeHeight
									   multiplier:1.0
										 constant:0];
}


+(NSLayoutConstraint*)constrainViewHeightToEqualWidth:(UIView*)view
{
	return [NSLayoutConstraint constraintWithItem:view
										attribute:NSLayoutAttributeHeight
										relatedBy:NSLayoutRelationEqual
										   toItem:view
										attribute:NSLayoutAttributeWidth
									   multiplier:1.0
										 constant:0];
}

+(NSArray*)constrainViewToSameLocation:(UIView*)view asView:(UIView*)copyView
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
