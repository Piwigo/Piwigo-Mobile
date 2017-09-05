//
//  LoginViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoButton.h"
#import "PiwigoTextField.h"
#import "ServerField.h"

@interface LoginViewController : UIViewController

@property (nonatomic, strong) UIImageView *piwigoLogo;
@property (nonatomic, strong) ServerField *serverTextField;
@property (nonatomic, strong) PiwigoTextField *userTextField;
@property (nonatomic, strong) PiwigoTextField *passwordTextField;
@property (nonatomic, strong) PiwigoButton *loginButton;

@property (nonatomic, strong) NSLayoutConstraint *logoTopConstraint;
@property (nonatomic, assign) NSInteger topConstraintAmount;

@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UILabel *loggingInLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

-(void)launchLogin;
-(void)checkSessionStatusAndTryRelogin;

-(void)showLoginFail;
-(void)showLoading;
-(void)hideLoading;

@end
