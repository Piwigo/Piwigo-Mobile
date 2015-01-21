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
#import "PiwigoSession.h"
#import "AppDelegate.h"

@interface LoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIImageView *piwigoLogo;
@property (nonatomic, strong) PiwigoTextField *serverTextField;
@property (nonatomic, strong) PiwigoTextField *userTextField;
@property (nonatomic, strong) PiwigoTextField *passwordTextField;
@property (nonatomic, strong) PiwigoButton *loginButton;

@property (nonatomic, strong) UIView *loadingView;
@property (nonatomic, strong) UILabel *loggingInLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

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
		self.serverTextField.returnKeyType = UIReturnKeyNext;
		self.serverTextField.delegate = self;
		[self.view addSubview:self.serverTextField];
				
		self.userTextField = [PiwigoTextField new];
		self.userTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username");
		self.userTextField.text = [KeychainAccess getLoginUser];
		self.userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.userTextField.returnKeyType = UIReturnKeyNext;
		self.userTextField.delegate = self;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [KeychainAccess getLoginPassword];
		self.passwordTextField.returnKeyType = UIReturnKeyGo;
		self.passwordTextField.delegate = self;
		[self.view addSubview:self.passwordTextField];
		
		self.loginButton = [PiwigoButton new];
		self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loginButton setTitle:NSLocalizedString(@"login_loginButton", @"Login") forState:UIControlStateNormal];
		[self.loginButton addTarget:self action:@selector(performLogin) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.loginButton];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)]];
		
		self.loadingView = [UIView new];
		self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
		self.loadingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
		self.loadingView.hidden = YES;
		[self.view addSubview:self.loadingView];
		
		self.loggingInLabel = [UILabel new];
		self.loggingInLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.loggingInLabel.text = NSLocalizedString(@"login_loggingIn", @"Logging In...");
		self.loggingInLabel.font = [UIFont piwigoFontNormal];
		self.loggingInLabel.textColor = [UIColor whiteColor];
		[self.loadingView addSubview:self.loggingInLabel];
		
		self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loadingView addSubview:self.spinner];
		
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
	
	
	[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.loadingView]];
	[self.loadingView addConstraints:[NSLayoutConstraint constraintViewToCenter:self.spinner]];
	[self.loadingView addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.loggingInLabel]];
	[self.loadingView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[label]-[spinner]"
																			 options:kNilOptions
																			 metrics:nil
																			   views:@{@"spinner" : self.spinner,
																					   @"label" : self.loggingInLabel}]];
}

-(void)dismissKeyboard
{
	[self.view endEditing:YES];
}

-(void)performLogin
{
	[self showLoading];
	
	[PiwigoSession performLoginWithServer:self.serverTextField.text
								  andUser:self.userTextField.text
							  andPassword:self.passwordTextField.text
							 onCompletion:^(BOOL result, id response) {
								 if(result)
								 {
									 [self getSessionStatus];
								 }
								 else
								 {
									 [self hideLoading];
									 [self showLoginFail];
								 }
							 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
								 [self hideLoading];
							 }];
}

-(void)getSessionStatus
{
	[PiwigoSession getStatusOnCompletion:^(NSDictionary *responseObject) {
		[self hideLoading];
		if(responseObject)
		{
			AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
			[appDelegate loadNavigation];
		}
		else
		{
			UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"sessionStatusError_title", @"Authentication Fail")
																message:NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again.")
															   delegate:nil
													  cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Okay")
													  otherButtonTitles:nil];
			[failAlert show];
		}
	} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
		[self hideLoading];
	}];
}

-(void)showLoading
{
	self.loadingView.hidden = NO;
	[self.spinner startAnimating];
}
-(void)hideLoading
{
	[self.spinner stopAnimating];
	self.loadingView.hidden = YES;
}

-(void)showLoginFail
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"loginError_title", @"Login Fail")
													message:NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server")
												   delegate:nil
										  cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Okay")
										  otherButtonTitles:nil];
	[alert show];
}


#pragma mark -- UITextField Delegate Methods

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(textField == self.serverTextField) {
		[self.userTextField becomeFirstResponder];
	} else if (textField == self.userTextField) {
		[self.passwordTextField becomeFirstResponder];
	} else if (textField == self.passwordTextField) {
		[self performLogin];
	}
	return YES;
}

@end
