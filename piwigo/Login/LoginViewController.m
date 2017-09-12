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
#import "MBProgressHUD.h"

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

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
		[self.loginButton addTarget:self action:@selector(launchLogin) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.loginButton];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)]];
		
		[self performSelector:@selector(setupAutoLayout) withObject:nil]; // now located in child VC, thus import .h files
	}
	return self;
}

-(void)launchLogin
{
    // User pressed "Login"
    [self.view endEditing:YES];

    // Default settings
    [Model sharedInstance].hasAdminRights = NO;
    [Model sharedInstance].usesCommunityPluginV29 = NO;
    [Model sharedInstance].canUploadVideos = YES;
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif

    // Check server address and cancel login if address not provided
    if(self.serverTextField.textField.text.length <= 0)
    {
        [UIAlertView showWithTitle:NSLocalizedString(@"loginEmptyServer_title", @"Enter a Web Address")
                           message:NSLocalizedString(@"loginEmptyServer_message", @"Please select a protocol and enter a Piwigo web address in order to proceed.")
                 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                 otherButtonTitles:nil
                          tapBlock:nil];
        return;
    }

    // Display HUD during login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });
    
    // Clean server address and save it to disk
    NSString *cleanServerString = [self cleanServerString:self.serverTextField.textField.text];
    self.serverTextField.textField.text = cleanServerString;
    
    [Model sharedInstance].serverName = cleanServerString;
    [Model sharedInstance].serverProtocol = [self.serverTextField getProtocolString];
    [[Model sharedInstance] saveToDisk];
    
    // If username exists, save credentials in Keychain (needed before login if using HTTP Authentication)
    if(self.userTextField.text.length > 0)
    {
        // Store credentials in Keychain
        [KeychainAccess storeLoginInKeychainForUser:self.userTextField.text andPassword:self.passwordTextField.text];
    }

    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
    [SessionService getMethodsListOnCompletion:^(NSDictionary *methodsList) {
        
        if(methodsList) {
            // Known methods, pursue logging in…
            [self performLogin];
        
        } else {
            // Methods unknown, so we cannot reach the server, inform user
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"serverMethodsError_message", @"Failed to get server methods.\nProblem with Piwigo server?"))];
        }
        
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // Display error message
        [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
    }];
}

-(void)performLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> performLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
    
    // Perform Login if username exists
	if((self.userTextField.text.length > 0) && (![Model sharedInstance].userCancelledCommunication))
	{
        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_newSession", @"Opening Session")];
        });
        
        // Perform login
        [SessionService performLoginWithUser:self.userTextField.text
								  andPassword:self.passwordTextField.text
								 onCompletion:^(BOOL result, id response) {
									 if(result)
									 {
                                         // Session now opened
                                         // First determine user rights if Community extension installed
                                         [self getCommunityStatusAtFirstLogin:YES];
                                      }
									 else
									 {
                                         // Don't keep credentials
                                         [KeychainAccess resetKeychain];

                                         // Session could not be re-opened
                                         [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server"))];
									 }
								 } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                     // Display message
                                     [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
                                 }];
	}
	else     // No username, get only server status
	{
        // Reset keychain and credentials
        [Model sharedInstance].username = @"";
        [KeychainAccess resetKeychain];

        // Check Piwigo version, get token, available sizes, etc.
        [self getCommunityStatusAtFirstLogin:YES];
    }
}

// Determine true user rights when Community extension installed
-(void)getCommunityStatusAtFirstLogin:(BOOL)isFirstLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> getCommunityStatusAtFirstLogin:%@ starting with…", isFirstLogin ? @"YES" : @"NO");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
    if(([Model sharedInstance].usesCommunityPluginV29) &&(![Model sharedInstance].userCancelledCommunication)) {

        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_communityParameters", @"Community Parameters")];
        });
        
        // Community extension installed
        [SessionService getCommunityStatusOnCompletion:^(NSDictionary *responseObject) {
            
            if(responseObject)
            {
                // Check Piwigo version, get token, available sizes, etc.
                [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin];
            
            } else {
                // Inform user that server failed to retrieve Community parameters
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"serverCommunityError_message", @"Failed to get Community extension parameters.\nTry logging in again."))];
            }
            
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
        }];

    } else {
        // Community extension not installed
        // Check Piwigo version, get token, available sizes, etc.
        [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin];
    }
}

// Check Piwigo version, get token, available sizes, etc.
-(void)getSessionStatusAtLogin:(BOOL)isLoggingIn andFirstLogin:(BOOL)isFirstLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> getSessionStatusAtLogin:%@ andFirstLogin:%@ starting with…",
          isLoggingIn ? @"YES" : @"NO", isFirstLogin ? @"YES" : @"NO");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
    if (![Model sharedInstance].userCancelledCommunication) {
        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_serverParameters", @"Piwigo Parameters")];
        });
        
        [SessionService getPiwigoStatusAtLogin:isLoggingIn
                                  OnCompletion:^(NSDictionary *responseObject) {
            if(responseObject)
            {
                if([@"2.7" compare:[Model sharedInstance].version options:NSNumericSearch] != NSOrderedAscending)
                {
                    // They need to update, ask user what to do
                    // Close loading or re-login view and ask what to do
                    [self hideLoadingWithCompletion:^{
                        [UIAlertView showWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible")
                                           message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.7. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), [Model sharedInstance].version]
                                 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
                                 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
                                          tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                              // Load navigation if user wants to
                                              if(buttonIndex == 1)
                                              {    // Proceed at their own risk
                                                  if (isFirstLogin) {
                                                      AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                                      [appDelegate loadNavigation];
                                                  }
                                              }
                                          }];
                    }];
                } else {
                    // Their version is Ok. Close HUD.
                    [self hideLoadingWithCompletion:^{
                        // Load navigation if needed
                        if (isFirstLogin) {
                            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                            [appDelegate loadNavigation];
                        }
                    }];
                }
            } else {
                // Inform user that we could not authenticate with server
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again."))];
            }
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
        }];
    } else {
        [self loggingInConnectionError:nil];
    }
}

-(void)checkSessionStatusAndTryRelogin
{
    // Display HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connectionChanged", @"Connection Changed!")];
    });
    
    // Check whether session is still active
    [SessionService getPiwigoStatusAtLogin:NO
                                   OnCompletion:^(NSDictionary *responseObject) {
        if(responseObject) {
            
            // When the session is closed, user becomes guest
            NSString *userName = [responseObject objectForKey:@"username"];
#if defined(DEBUG_SESSION)
            NSLog(@"=> checkSessionStatusAndTryRelogin: username=%@", userName);
#endif
            if (![userName isEqualToString:[Model sharedInstance].username]) {

                // Session was closed, try relogging in assuming server did not change for speed
                [Model sharedInstance].hadOpenedSession = NO;
                [self performRelogin];

            } else {
                // Connection still alive. Close HUD and do nothing.
                [self hideLoadingWithCompletion:^{
                }];
#if defined(DEBUG_SESSION)
                NSLog(@"=> checkSessionStatusAndTryRelogin: Connection still alive…");
                NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
                      ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
                      ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
                      ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
            }
        } else {
            // Connection really lost, inform user
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"internetErrorGeneral_broken", @"Sorry, the communication was broken.\nTry logging in again."))];
        }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // No connection or server down
        [Model sharedInstance].hadOpenedSession = NO;
        
        // Display message
        [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
    }];
}

-(void)performRelogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> performRelogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
    
    // Update HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });

    // Perform login
    NSString *user = [KeychainAccess getLoginUser];
    NSString *password = [KeychainAccess getLoginPassword];
    [SessionService performLoginWithUser:user
                             andPassword:password
                            onCompletion:^(BOOL result, id response) {
                                if(result)
                                {
                                    // Session now re-opened
                                    [Model sharedInstance].hadOpenedSession = YES;
                                    
                                    // First determine user rights if Community extension installed
                                    [self getCommunityStatusAtFirstLogin:NO];
                                }
                                else
                                {
                                    // Session could not be re-opened, inform user
                                    [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server"))];
                                }

                            } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Could not re-establish the session, login/pwd changed, something else ?
                                [Model sharedInstance].hadOpenedSession = NO;
                                
                                // Display error message
                                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
                            }];
}

#pragma mark -- HUD methods

-(void)showLoadingWithSubtitle:(NSString *)subtitle
{
    // Determine the present view controller (not necessarily self.view)
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topViewController.view];
    if (!hud) {
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:topViewController.view animated:YES];
        [hud setTag:loadingViewTag];

        // Change the background view shape, style and color.
        hud.square = NO;
        hud.animationType = MBProgressHUDAnimationFade;
        hud.contentColor = [UIColor piwigoWhiteCream];
        hud.bezelView.color = [UIColor colorWithWhite:0.f alpha:1.0];
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        
        // Set title
        hud.label.text = NSLocalizedString(@"login_loggingIn", @"Logging In...");
        hud.label.font = [UIFont piwigoFontNormal];
    
        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);

        // Configure the button.
        [hud.button setTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection") forState:UIControlStateNormal];
        [hud.button addTarget:self action:@selector(cancelLoggingIn) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // Update the subtitle
    hud.detailsLabel.text = subtitle;
    hud.detailsLabel.font = [UIFont piwigoFontSmall];
}

- (void)cancelLoggingIn
{
    // Propagate user's request
    [Model sharedInstance].userCancelledCommunication = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Determine the present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }

        // Update login HUD
        MBProgressHUD *hud = [topViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Update text
            hud.detailsLabel.text = NSLocalizedString(@"internetCancellingConnection_button", @"Cancelling Connection…");;
            
            // Reconfigure the button
            [hud.button isSelected];
            [hud.button removeTarget:self action:@selector(hideLoadingWithCompletion:) forControlEvents:UIControlEventTouchUpInside];
        }
    });
}

- (void)loggingInConnectionError:(NSString *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Determine the present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }
        
        // Update login HUD
        MBProgressHUD *hud = [topViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Show only text
            hud.mode = MBProgressHUDModeText;
            
            // Reconfigure the button
            [hud.button setTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss") forState:UIControlStateNormal];
            [hud.button addTarget:self action:@selector(hideLoadingWithCompletion:) forControlEvents:UIControlEventTouchUpInside];

            // Update text
            if (error == nil) {
                hud.label.text = NSLocalizedString(@"internetCancelledConnection_title", @"Connection Cancelled");
                hud.detailsLabel.text = @" ";
            } else {
                hud.label.text = NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error");
                hud.detailsLabel.text = [NSString stringWithFormat:@"%@", error];
            }
        }
    });
}

-(void)hideLoadingWithCompletion:(void (^ __nullable)(void))completion
{
    // Reinitialise flag
    [Model sharedInstance].userCancelledCommunication = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Determine the present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }
        
        // Hide and remove login HUD
        MBProgressHUD *hud = [topViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            [hud hideAnimated:YES];
        }
        completion();
    });
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
		[self launchLogin];
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


#pragma mark -- Utilities

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

@end
