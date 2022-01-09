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

@interface LoginViewController : UIViewController

@property (nonatomic, strong) UIButton *piwigoLogo;
@property (nonatomic, strong) UIButton *piwigoButton;
@property (nonatomic, strong) PiwigoTextField *serverTextField;
@property (nonatomic, strong) PiwigoTextField *userTextField;
@property (nonatomic, strong) PiwigoTextField *passwordTextField;
@property (nonatomic, strong) PiwigoButton *loginButton;
@property (nonatomic, strong) UILabel *websiteNotSecure;
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;

@property (nonatomic, assign) BOOL isAlreadyTryingToLogin;

-(void)launchLogin;
-(void)performReloginWithCompletion:(void (^)(void))reloginCompletion;
-(void)reloadCatagoryDataInBckgMode;

@end
