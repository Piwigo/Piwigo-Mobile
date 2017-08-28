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

//static NSInteger const loginViewTag = 898;
static NSInteger const reloginViewTag = 899;

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

-(void)launchLogin
{
    // User pressed "Login"
    [self.view endEditing:YES];
    [self showLoading];
    
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
        
        [self hideLoading];
        return;
    }

    // Clean server address and save it to disk
    NSString *cleanServerString = [self cleanServerString:self.serverTextField.textField.text];
    self.serverTextField.textField.text = cleanServerString;
    
    [Model sharedInstance].serverName = cleanServerString;
    [Model sharedInstance].serverProtocol = [self.serverTextField getProtocolString];
    [[Model sharedInstance] saveToDisk];
    
    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
    [SessionService getMethodsListOnCompletion:^(NSDictionary *methodsList) {
        
        if(methodsList) {
            // Known methods, pursue logging in…
            [self performLogin];
        
        } else {
            // Methods unknown, so we cannot reach the server
            [self hideLoading];
            UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"serverMethodsError_title", @"Unknown Methods")
                                                                message:NSLocalizedString(@"serverMethodsError_message", @"Failed to get server methods.\nProblem with Piwigo server?")
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                                      otherButtonTitles:nil];
            [failAlert show];
        }
        
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        [self hideLoading];
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
	if(self.userTextField.text.length > 0)
	{
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
										 // No session opened
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
											  cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
											  otherButtonTitles:nil
													   tapBlock:nil];
								 }];
	}
	else     // No username, get only server status
	{
        // Reset keychain and credentials
//        [Model sharedInstance].username = @"";
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
    if([Model sharedInstance].usesCommunityPluginV29) {

        // Community extension installed
        [SessionService getCommunityStatusOnCompletion:^(NSDictionary *responseObject) {
            
            if(responseObject)
            {
                // Check Piwigo version, get token, available sizes, etc.
                [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin];
            
            } else {
                // Close loading or re-login view
                isFirstLogin ? [self hideLoading] : [self hideReLoggingIn];
                
                UIAlertView *failAlert = [[UIAlertView alloc]
                                          initWithTitle:NSLocalizedString(@"serverCommunityError_title", @"Community Error")
                                          message:NSLocalizedString(@"serverCommunityError_message", @"Failed to get Community extension parameters.\nTry logging in again.")
                                          delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                          otherButtonTitles:nil];
                [failAlert show];
            }
            
        } onFailure:^(NSURLSessionTask *task, NSError *error) {

            // Close loading or re-login view
            isFirstLogin ? [self hideLoading] : [self hideReLoggingIn];
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
    [SessionService getPiwigoStatusAtLogin:isLoggingIn
                              OnCompletion:^(NSDictionary *responseObject) {
		if(responseObject)
		{
			if([@"2.7" compare:[Model sharedInstance].version options:NSNumericSearch] != NSOrderedAscending)
			{
                // They need to update
                // Close loading or re-login view
                isFirstLogin ? [self hideLoading] : [self hideReLoggingIn];

                [UIAlertView showWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible")
								   message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.7. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), [Model sharedInstance].version]
						 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
						 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
									  if(buttonIndex == 1)
									  {	// proceed at their own risk
                                          if (isFirstLogin) {
                                              AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                              [appDelegate loadNavigation];
                                          }
									  }
								  }];
			} else {
                // Their version is Ok
                if (isFirstLogin)
                {
                    // Load interface
                    [self hideLoading];
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate loadNavigation];
                    
                } else {
                    // Close HUD and keep current view active
                    [self hideReLoggingIn];
                }
            }
            
		} else {
            // Close loading or re-login view
            isFirstLogin ? [self hideLoading] : [self hideReLoggingIn];

            UIAlertView *failAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"sessionStatusError_title", @"Authentication Fail")
                                                                message:NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again.")
															   delegate:nil
													  cancelButtonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
													  otherButtonTitles:nil];
			[failAlert show];
		}
	} onFailure:^(NSURLSessionTask *task, NSError *error) {

        // Close loading or re-login view
        isFirstLogin ? [self hideLoading] : [self hideReLoggingIn];
	}];
}

-(void)checkSessionStatusAndTryRelogin
{
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
                // Connection still alive… do nothing!
#if defined(DEBUG_SESSION)
                NSLog(@"=> checkSessionStatusAndTryRelogin: Connection still alive…");
                NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, canUploadVideos=%@",
                      ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
                      ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
                      ([Model sharedInstance].canUploadVideos ? @"YES" : @"NO"));
#endif
            }
        } else {
            // Connection really lost
            [Model sharedInstance].hadOpenedSession = NO;
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
        [Model sharedInstance].hadOpenedSession = NO;
        [UIAlertView showWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                           message:[error localizedDescription]
                 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                 otherButtonTitles:nil
                          tapBlock:nil];
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
    
    // Display HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showReLoggingIn];
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
                                    // Session could not be re-opened
                                    [Model sharedInstance].hadOpenedSession = NO;
                                    [self showLoginFail];
                                }

                            } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Could not re-establish the session, login/pwd changed, something else ?
                                [Model sharedInstance].hadOpenedSession = NO;
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

-(void)showLoading
{
    self.loadingView.hidden = NO;
    [self.spinner startAnimating];
    
//    // Determine the present view controller
//    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
//    while (topViewController.presentedViewController) {
//        topViewController = topViewController.presentedViewController;
//    }
//
//    // Create the popup window
//    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
//
//    // Change the background view style and color.
//    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
//    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
//
//    // Define the text
//    hud.label.text = NSLocalizedString(@"login_loggingIn", @"Logging In...");
//    [hud setTag:loginViewTag];
}

-(void)hideLoading
{
    [self.spinner stopAnimating];
    self.loadingView.hidden = YES;

//    // Remove the re-login window
//    MBProgressHUD *hud = [self.navigationController.view viewWithTag:loginViewTag];
//    [hud hideAnimated:YES];
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

-(void)showReLoggingIn
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }

    // Create the re-login HUD if needed (the reachability methods may send several notifications)
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topViewController.view];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:topViewController.view animated:YES];
    }

    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];

    // Define the text
    hud.label.text = NSLocalizedString(@"login_loggingIn", @"Logging In...");
    hud.detailsLabel.text = NSLocalizedString(@"login_connectionChanged", @"Connection Changed!");
    [hud setTag:reloginViewTag];
}

-(void)hideReLoggingIn
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Hide and remove the actual re-login HUD
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topViewController.view];
    if (hud) {
        [MBProgressHUD hideHUDForView:topViewController.view animated:YES];
    }
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
