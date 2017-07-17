//
//  LoginViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"
#import "KeychainAccess.h"
#import "Model.h"
#import "SessionService.h"
#import "ClearCache.h"
#import "AppDelegate.h"

@interface LoginViewController () <UITextFieldDelegate>

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
		
		self.serverTextField = [ServerField new];
		self.serverTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.serverTextField.textField.placeholder = NSLocalizedString(@"login_serverPlaceholder", @"Server");
		self.serverTextField.textField.text = [Model sharedInstance].serverName;
		self.serverTextField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.serverTextField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.serverTextField.textField.keyboardType = UIKeyboardTypeURL;
		self.serverTextField.textField.returnKeyType = UIReturnKeyNext;
		self.serverTextField.textField.delegate = self;
		[self.view addSubview:self.serverTextField];
				
		self.userTextField = [PiwigoTextField new];
		self.userTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username (optional)");
		self.userTextField.text = [KeychainAccess getLoginUser];
		self.userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.userTextField.returnKeyType = UIReturnKeyNext;
		self.userTextField.delegate = self;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password (optional)");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [KeychainAccess getLoginPassword];
		self.passwordTextField.returnKeyType = UIReturnKeyGo;
		self.passwordTextField.delegate = self;
		[self.view addSubview:self.passwordTextField];
		
		self.loginButton = [PiwigoButton new];
		self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loginButton setTitle:NSLocalizedString(@"login", @"Login") forState:UIControlStateNormal];
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
		
		[self performSelector:@selector(setupAutoLayout) withObject:nil]; // now located in child VC, thus import .h files
	}
	return self;
}

-(void)moveTextFieldsBy:(NSInteger)amount
{
	self.logoTopConstraint.constant = amount;
	[UIView animateWithDuration:0.3 animations:^{
		[self.view layoutIfNeeded];
	}];
}

-(void)dismissKeyboard
{
	[self moveTextFieldsBy:self.topConstraintAmount];
	[self.view endEditing:YES];
}

-(void)performLogin
{
	[self.view endEditing:YES];
	[self showLoading];
	
	if(self.serverTextField.textField.text.length <= 0)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"loginEmptyServer_title", @"Enter a Web Address")
						   message:NSLocalizedString(@"loginEmptyServer_message", @"Please select a protocol and enter a Piwigo web address in order to proceed.")
				 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
				 otherButtonTitles:nil
						  tapBlock:nil];
		
		[self hideLoading];
		return;
	}
	
	NSString *cleanServerString = [self cleanServerString:self.serverTextField.textField.text];
	self.serverTextField.textField.text = cleanServerString;
	
	[Model sharedInstance].serverName = cleanServerString;
	[Model sharedInstance].serverProtocol = [self.serverTextField getProtocolString];
	[[Model sharedInstance] saveToDisk];

	if(self.userTextField.text.length > 0)      // Perform Login if username exists
	{
		[SessionService performLoginWithUser:self.userTextField.text
								  andPassword:self.passwordTextField.text
								 onCompletion:^(BOOL result, id response) {
									 if(result)
									 {
                                         // Session now opened
                                         [Model sharedInstance].hadOpenedSession = YES;
                                         
                                         // Get version, token, rights, available sizes and check Piwigo version
                                         [self getSessionStatus];
                                         if([Model sharedInstance].hasAdminRights) {
                                             [self getSessionPluginsList];      // To determine if VideoJS is available
                                         }
									 }
									 else
									 {
										 // No session opened
                                         [Model sharedInstance].hadOpenedSession = NO;
                                         [self hideLoading];
										 [self showLoginFail];
									 }
								 } onFailure:^(NSURLSessionTask *task, NSError *error) {
									 [self hideLoading];
#if defined(DEBUG)
									 NSLog(@"Error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                     [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
														message:[error localizedDescription]
											  cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
											  otherButtonTitles:nil
													   tapBlock:nil];
								 }];
	}
	else     // No username, get only session status
	{
		[Model sharedInstance].hadOpenedSession = NO;
        [self getSessionStatus];
		[KeychainAccess resetKeychain];
	}
}

-(NSString*)cleanServerString:(NSString*)serverString
{
	NSString *server = serverString;
	
	NSRange httpRange = [server rangeOfString:@"http://" options:NSCaseInsensitiveSearch];
	if(httpRange.location == 0)
	{
		server = [server substringFromIndex:7];
	}
	
	NSRange httpsRange = [server rangeOfString:@"https://" options:NSCaseInsensitiveSearch];
	if(httpsRange.location == 0)
	{
		server = [server substringFromIndex:8];
	}
	
	return server;
}

-(void)getSessionStatus
{
	[SessionService getStatusOnCompletion:^(NSDictionary *responseObject) {
		[self hideLoading];
		if(responseObject)
		{
			if([@"2.7" compare:[Model sharedInstance].version options:NSNumericSearch] != NSOrderedAscending)
			{	// they need to update
				[UIAlertView showWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible")
								   message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.7. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), [Model sharedInstance].version]
						 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
						 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
									  if(buttonIndex == 1)
									  {	// proceed at their own risk
										  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
										  [appDelegate loadNavigation];
									  }
								  }];
			}
			else
			{	// their version is Ok
				AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
				[appDelegate loadNavigation];
			}
		}
		else
		{
			UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"sessionStatusError_title", @"Authentication Fail")
                                                                message:NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again.")
															   delegate:nil
													  cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
													  otherButtonTitles:nil];
			[failAlert show];
		}
	} onFailure:^(NSURLSessionTask *task, NSError *error) {
		[self hideLoading];
	}];
}

-(void)getSessionPluginsList
{
    [SessionService getPluginsListOnCompletion:^(NSDictionary *responseObject) {
        [self hideLoading];
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        [self hideLoading];
    }];
}

// In case the connection was temporarily lost
-(void)getSessionStatusAfterReachabilityChanged
{
    [SessionService getStatusOnCompletion:^(NSDictionary *responseObject) {

    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                           message:[error localizedDescription]
                 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                 otherButtonTitles:nil
                          tapBlock:nil];
    }];
}

-(void)getSessionPluginsListAfterReachabilityChanged
{
    [SessionService getPluginsListOnCompletion:^(NSDictionary *responseObject) {

    } onFailure:^(NSURLSessionTask *task, NSError *error) {

    }];
}

// Check status of session and try logging in again if needed
-(void)checkSessionStatusAndTryRelogin
{
    NSString *user = [KeychainAccess getLoginUser];
    NSString *password = [KeychainAccess getLoginPassword];

    [SessionService getStatusOnCompletion:^(NSDictionary *responseObject) {
        if(responseObject) {
            NSString *userName = [responseObject objectForKey:@"username"];
            if (![userName isEqualToString:[[Model sharedInstance]username]]) {
#if defined(DEBUG)
                NSLog(@"checkSessionStatusBeforeAppEnterForeground: username \"%@\" ≠ \"%@\". Try logging in again…", user, userName);
#endif
                [SessionService performLoginWithUser:user
                                         andPassword:password
                                        onCompletion:^(BOOL result, id response) {
                                            [Model sharedInstance].hadOpenedSession = YES;
                                            [self getSessionStatusAfterReachabilityChanged];
                                            if([Model sharedInstance].hasAdminRights) {
                                                [self getSessionPluginsListAfterReachabilityChanged];   // To determine if VideoJS is available
                                            }
                                        }
                                           onFailure:^(NSURLSessionTask *task, NSError *error) {
                                               // Could not re-establish the session, login/pwd changed ?
                                               [Model sharedInstance].hadOpenedSession = NO;
                                               [ClearCache clearAllCache];
                                               AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                               [appDelegate loadLoginView];
#if defined(DEBUG)
                                               NSLog(@"Error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                               [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                                                                  message:[error localizedDescription]
                                                        cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                                                        otherButtonTitles:nil
                                                                 tapBlock:nil];
                                           }];
            }
        } else {
            // Connection lost
            [Model sharedInstance].hadOpenedSession = NO;
            [ClearCache clearAllCache];
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate loadLoginView];
#if defined(DEBUG)
            NSLog(@"Error: Broken connection");
#endif
            [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                               message:NSLocalizedString(@"internetErrorGeneral_broken", @"Sorry, the communication was broken.\nTry logging in again.")
                     cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                     otherButtonTitles:nil
                              tapBlock:nil];
        }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // No connection or server down
        [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                           message:[error localizedDescription]
                 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                 otherButtonTitles:nil
                          tapBlock:nil];
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
										  cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
										  otherButtonTitles:nil];
	[alert show];
}


#pragma mark -- UITextField Delegate Methods

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(textField == self.serverTextField.textField) {
		[self.userTextField becomeFirstResponder];
	} else if (textField == self.userTextField) {
		[self.passwordTextField becomeFirstResponder];
	} else if (textField == self.passwordTextField) {
		if(self.view.frame.size.height > 320)
		{
			[self moveTextFieldsBy:self.topConstraintAmount];
		}
		[self performLogin];
	}
	return YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
	if(self.view.frame.size.height > 500) return;
	
	NSInteger amount = 0;
	if (textField == self.userTextField)
	{
		amount = -self.topConstraintAmount;
	}
	else if (textField == self.passwordTextField)
	{
		amount = -self.topConstraintAmount * 2;
	}
	
	[self moveTextFieldsBy:amount];
}

@end
