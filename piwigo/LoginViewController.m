//
//  LoginViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController.h"
#import "PiwigoButton.h"
#import "PiwigoTextField.h"
#import "KeychainAccess.h"
#import "Model.h"
#import "PiwigoNetwork.h"

@interface LoginViewController ()

@property (nonatomic, strong) UIImageView *piwigoLogo;
@property (nonatomic, strong) PiwigoTextField *serverTextField;
@property (nonatomic, strong) PiwigoTextField *userTextField;
@property (nonatomic, strong) PiwigoTextField *passwordTextField;
@property (nonatomic, strong) PiwigoButton *loginButton;

@end

@implementation LoginViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		
		self.piwigoLogo = [UIImageView new];
		self.piwigoLogo.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoLogo.image = [UIImage imageNamed:@"piwigoLogo"];
		self.piwigoLogo.contentMode = UIViewContentModeScaleAspectFit;
		[self.view addSubview:self.piwigoLogo];
		
		self.serverTextField = [PiwigoTextField new];
		self.serverTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.serverTextField.placeholder = NSLocalizedString(@"login_serverPlaceholder", @"Server");
		self.serverTextField.text = [Model sharedInstance].serverName;
		self.serverTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.serverTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.serverTextField.keyboardType = UIKeyboardTypeURL;
		[self.view addSubview:self.serverTextField];
		
		// @TODO: RETURN KEY IS NEXT, AND IT GOES TO THE NEXT FIELD
		
		self.userTextField = [PiwigoTextField new];
		self.userTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username");
		self.userTextField.text = [KeychainAccess getLoginUser];
		self.userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [KeychainAccess getLoginPassword];
		[self.view addSubview:self.passwordTextField];
		
		self.loginButton = [PiwigoButton new];
		self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loginButton setTitle:NSLocalizedString(@"login_loginButton", @"Login") forState:UIControlStateNormal];
		[self.loginButton addTarget:self action:@selector(performLogin) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.loginButton];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)]];
		
		[self setupAutoLayout];
	}
	return self;
}

-(void)setupAutoLayout
{
	NSInteger textFeildHeight = 64;
	
	NSDictionary *views = @{
							@"logo" : self.piwigoLogo,
							@"login" : self.loginButton,
							@"server" : self.serverTextField,
							@"user" : self.userTextField,
							@"password" : self.passwordTextField
							};
	NSDictionary *metrics = @{
							  @"imageSide" : @25,
							  @"imageTopBottom" : @40,
							  @"side" : @35
							  };
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-imageTopBottom-[logo]-imageTopBottom-[server]-[user]-[password]-[login]"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
	
	[self.piwigoLogo addConstraint:[NSLayoutConstraint constrainViewToHeight:self.piwigoLogo height:textFeildHeight + 36]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-imageSide-[logo]-imageSide-|"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
	
	[self.serverTextField addConstraint:[NSLayoutConstraint constrainViewToHeight:self.serverTextField height:textFeildHeight]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[server]-side-|"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
	
	[self.userTextField addConstraint:[NSLayoutConstraint constrainViewToHeight:self.userTextField height:textFeildHeight]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[user]-side-|"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
	
	[self.passwordTextField addConstraint:[NSLayoutConstraint constrainViewToHeight:self.passwordTextField height:textFeildHeight]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[password]-side-|"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
	
	[self.loginButton addConstraint:[NSLayoutConstraint constrainViewToHeight:self.loginButton height:textFeildHeight]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-side-[login]-side-|"
																	  options:kNilOptions
																	  metrics:metrics
																		views:views]];
}

-(void)dismissKeyboard
{
	[self.view endEditing:YES];
}

-(void)performLogin
{
	[PiwigoNetwork performLoginWithServer:self.serverTextField.text
								  andUser:self.userTextField.text
							  andPassword:self.passwordTextField.text
							 onCompletion:^(BOOL result, id response) {
								 if(result)
								 {
									 [KeychainAccess storeLoginInKeychainForUser:self.userTextField.text andPassword:self.passwordTextField.text];
								 }
								 else
								 {	// @TODO: error
									 
								 }
							 }];
}

@end
