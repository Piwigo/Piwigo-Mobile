//
//  EditPopDownView.m
//  piwigo
//
//  Created by Spencer Baker on 3/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditPopDownView.h"

@interface EditPopDownView() <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, copy) completed completeBlock;

@end

@implementation EditPopDownView

-(instancetype)initWithPlaceHolderText:(NSString*)placeholder
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor blackColor];
		self.translatesAutoresizingMaskIntoConstraints = NO;
		
		self.textField = [UITextField new];
		self.textField.translatesAutoresizingMaskIntoConstraints = NO;
		self.textField.backgroundColor = [UIColor piwigoWhiteCream];
		self.textField.delegate = self;
		self.textField.returnKeyType = UIReturnKeyDone;
		self.textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
		self.textField.placeholder = placeholder;
		self.textField.borderStyle = UITextBorderStyleRoundedRect;
		[self addSubview:self.textField];
		
		[self addConstraint:[NSLayoutConstraint constraintView:self toHeight:40]];
		
		[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[field]-10-|"
																	 options:kNilOptions
																	 metrics:nil
																	   views:@{@"field" : self.textField}]];
		[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-5-[field]-5-|"
																	 options:kNilOptions
																	 metrics:nil
																	   views:@{@"field" : self.textField}]];
	}
	return self;
}

-(void)presentFromView:(UIView*)view onCompletion:(completed)completedBlock
{
	self.completeBlock = completedBlock;
	
	[view addSubview:self];
	[view bringSubviewToFront:self];
	
	[view addConstraints:[NSLayoutConstraint constraintFillWidth:self]];
	
	self.topConstraint = [NSLayoutConstraint constraintViewFromTop:self amount:-40];
	[view addConstraint:self.topConstraint];
	[self layoutIfNeeded];
	
	if(IS_OS_7_OR_LATER)
	{
		[UIView animateWithDuration:1.0
							  delay:0
			 usingSpringWithDamping:0.5
			  initialSpringVelocity:25.0
							options:UIViewAnimationOptionCurveEaseIn
						 animations:^{
							 self.topConstraint.constant = 65;
							 [view layoutIfNeeded];
							 [self.textField becomeFirstResponder];
						 } completion:nil];
	}
	else
	{
		[UIView animateWithDuration:1.0 animations:^{
			self.topConstraint.constant = 65;
			[view layoutIfNeeded];
			[self.textField becomeFirstResponder];
		}];
	}
	
}

-(void)hide
{
	if(IS_OS_7_OR_LATER)
	{
		[UIView animateWithDuration:1.0
							  delay:0
			 usingSpringWithDamping:0.5
			  initialSpringVelocity:25.0
							options:UIViewAnimationOptionCurveEaseIn
						 animations:^{
							 self.topConstraint.constant = -40;
						 } completion:^(BOOL finished) {
							 [self removeFromSuperview];
						 }];
	}
	else
	{
		[UIView animateWithDuration:1.0 animations:^{
			self.topConstraint.constant = -40;
		} completion:^(BOOL finished) {
			[self removeFromSuperview];
		}];
	}
	[self.superview layoutIfNeeded];
}


#pragma mark UITextFieldDelegate Methods

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(self.completeBlock)
	{
		self.completeBlock(textField.text);
	}
	
	[self hide];
	
	return YES;
}

@end
