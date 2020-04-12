//
//  LoginViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AFNetworking/AFImageDownloader.h>

#import "LoginViewController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"
#import "SAMKeychain.h"
#import "Model.h"
#import "SessionService.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "CategoriesData.h"

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

NSString * const kPiwigoURL = @"— https://piwigo.org —";

@interface LoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIAlertController *httpAlertController;
@property (nonatomic, strong) UIAlertAction *httpLoginAction;

@end

@implementation LoginViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoColorBrown];
		
		self.piwigoLogo = [UIImageView new];
		self.piwigoLogo.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoLogo.image = [UIImage imageNamed:@"piwigoLogo"];
		self.piwigoLogo.contentMode = UIViewContentModeScaleAspectFit;
		[self.view addSubview:self.piwigoLogo];
		
        self.piwigoButton = [UIButton new];
        self.piwigoButton.backgroundColor = [UIColor clearColor];
        self.piwigoButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoButton.titleLabel.font = [UIFont piwigoFontNormal];
        [self.piwigoButton setTitleColor:[UIColor piwigoColorOrange] forState:UIControlStateNormal];
        [self.piwigoButton setTitle:kPiwigoURL forState:UIControlStateNormal];
        [self.piwigoButton addTarget:self action:@selector(openPiwigoURL) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.piwigoButton];

        self.serverTextField = [PiwigoTextField new];
		self.serverTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.serverTextField.placeholder = NSLocalizedString(@"login_serverPlaceholder", @"example.com");
		self.serverTextField.text = [NSString stringWithFormat:@"%@", [Model sharedInstance].serverName];
		self.serverTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.serverTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.serverTextField.keyboardType = UIKeyboardTypeURL;
		self.serverTextField.returnKeyType = UIReturnKeyNext;
        self.serverTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        self.serverTextField.clearButtonMode = YES;
		self.serverTextField.delegate = self;
		[self.view addSubview:self.serverTextField];
				
		self.userTextField = [PiwigoTextField new];
		self.userTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username (optional)");
		self.userTextField.text = [Model sharedInstance].username;
		self.userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.userTextField.keyboardType = UIKeyboardTypeDefault;
		self.userTextField.returnKeyType = UIReturnKeyNext;
        self.userTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        self.userTextField.clearButtonMode = YES;
		self.userTextField.delegate = self;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password (optional)");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:[Model sharedInstance].username];
        self.passwordTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        self.passwordTextField.keyboardType = UIKeyboardTypeDefault;
		self.passwordTextField.returnKeyType = UIReturnKeyGo;
        self.passwordTextField.clearButtonMode = YES;
		[self.view addSubview:self.passwordTextField];
		
		self.loginButton = [PiwigoButton new];
		self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loginButton setTitle:NSLocalizedString(@"login", @"Login") forState:UIControlStateNormal];
		[self.loginButton addTarget:self action:@selector(launchLogin) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.loginButton];
		
        self.websiteNotSecure = [UILabel new];
        self.websiteNotSecure.translatesAutoresizingMaskIntoConstraints = NO;
        self.websiteNotSecure.font = [UIFont piwigoFontSmall];
        self.websiteNotSecure.text = NSLocalizedString(@"settingsHeader_notSecure", @"Website Not Secure!");
        self.websiteNotSecure.textAlignment = NSTextAlignmentCenter;
        self.websiteNotSecure.textColor = [UIColor whiteColor];
        self.websiteNotSecure.adjustsFontSizeToFitWidth = YES;
        self.websiteNotSecure.minimumScaleFactor = 0.8;
        self.websiteNotSecure.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.view addSubview:self.websiteNotSecure];
        
        self.byLabel1 = [UILabel new];
        self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel1.font = [UIFont piwigoFontSmall];
        self.byLabel1.textColor = [UIColor piwigoColorOrangeLight];
        self.byLabel1.text = NSLocalizedStringFromTableInBundle(@"authors1", @"About", [NSBundle mainBundle], @"By Spencer Baker, Olaf Greck,");
        [self.view addSubview:self.byLabel1];
        
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontSmall];
        self.byLabel2.textColor = [UIColor piwigoColorOrangeLight];
        self.byLabel2.text = NSLocalizedStringFromTableInBundle(@"authors2", @"About", [NSBundle mainBundle], @"and Eddy Lelièvre-Berna");
        [self.view addSubview:self.byLabel2];
        
        self.versionLabel = [UILabel new];
        self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.versionLabel.font = [UIFont piwigoFontTiny];
        self.versionLabel.textColor = [UIColor piwigoColorOrangeLight];
        [self.view addSubview:self.versionLabel];
        
        NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        self.versionLabel.text = [NSString stringWithFormat:@"— %@ %@ (%@) —", NSLocalizedStringFromTableInBundle(@"version", @"About", [NSBundle mainBundle], @"Version:"), appVersionString, appBuildString];

        [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)]];
		
		[self performSelector:@selector(setupAutoLayout) withObject:nil]; // now located in child VC, thus import .h files
    }

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];

    return self;
}


#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self applyColorPalette];
    
    // Not yet trying to login
    self.isAlreadyTryingToLogin = NO;
}

-(void)applyColorPalette
{
    // Server
    self.serverTextField.textColor = [UIColor piwigoColorText];
    self.serverTextField.backgroundColor = [UIColor piwigoColorBackground];
    
    // Username
    self.userTextField.textColor = [UIColor piwigoColorText];
    self.userTextField.backgroundColor = [UIColor piwigoColorBackground];
    
    // Password
    self.passwordTextField.textColor = [UIColor piwigoColorText];
    self.passwordTextField.backgroundColor = [UIColor piwigoColorBackground];
    
    // Login button
    if ([Model sharedInstance].isDarkPaletteActive) {
        self.loginButton.backgroundColor = [UIColor piwigoColorOrangeSelected];
    } else {
        self.loginButton.backgroundColor = [UIColor piwigoColorOrange];
    }
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle);
        if (hasUserInterfaceStyleChanged) {
            [Model sharedInstance].isSystemDarkModeActive = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate screenBrightnessChanged];
        }
    } else {
        // Fallback on earlier versions
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}


#pragma mark - Login business

-(void)launchLogin
{
    // User pressed "Login"
    [self.view endEditing:YES];

    // Default settings
    self.isAlreadyTryingToLogin = YES;
    self.usesCommunityPluginV29 = NO;
    [Model sharedInstance].hasAdminRights = NO;
    [Model sharedInstance].hasNormalRights = NO;
    [Model sharedInstance].usesCommunityPluginV29 = NO;
    
    // To remember app received anthentication challenge
    [Model sharedInstance].didRequestCertificateApproval = NO;
    [Model sharedInstance].didRequestHTTPauthentication = NO;
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].hasNormalRights ? @"YES" : @"NO"));
#endif

    // Check server address and cancel login if address not provided
    if(self.serverTextField.text.length <= 0)
    {
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"loginEmptyServer_title", @"Enter a Web Address")
                message:NSLocalizedString(@"loginEmptyServer_message", @"Please select a protocol and enter a Piwigo web address in order to proceed.")
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        alert.view.tintColor = UIColor.piwigoColorOrange;
        if (@available(iOS 13.0, *)) {
            alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [self presentViewController:alert animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange;
        }];
        
        return;
    }

    // Display HUD during login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });
    
    // Save credentials in Keychain (needed before login when using HTTP Authentication)
    if(self.userTextField.text.length > 0)
    {
        // Store credentials in Keychain
        [SAMKeychain setPassword:self.passwordTextField.text forService:[Model sharedInstance].serverName account:self.userTextField.text];
    }

    // Create permanent session managers for retrieving data and downloading images
    [NetworkHandler createJSONdataSessionManager];      // 30s timeout, 4 connections max
    [NetworkHandler createImagesSessionManager];        // 60s timeout, 4 connections max
    
    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: getMethodsList using %@", [Model sharedInstance].serverProtocol);
#endif
    [Model sharedInstance].sessionManager.session.configuration.timeoutIntervalForRequest = 10;
    [SessionService getMethodsListOnCompletion:^(NSDictionary *methodsList) {
        
        // Back to default timeout
        [Model sharedInstance].sessionManager.session.configuration.timeoutIntervalForRequest = 30;

        if(methodsList) {
            // Community extension installed and active ?
            for (NSString *method in methodsList) {
                
                // Check if the Community extension is installed and active (> 2.9a)
                if([method isEqualToString:@"community.session.getStatus"]) {
                    self.usesCommunityPluginV29 = YES;
                }
            }
            // Known methods, pursue logging in…
            [self performLogin];
        } else {
            // Methods unknown, so we cannot reach the server, inform user
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"serverMethodsError_message", @"Failed to get server methods.\nProblem with Piwigo server?")}];
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
        }
        
    } onFailure:^(NSURLSessionTask *task, NSError *error) {

        // Return immadiately an error in some cases
        switch ([error code]) {
            case NSURLErrorBadServerResponse:
            case NSURLErrorBadURL:
            case NSURLErrorCallIsActive:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorCannotDecodeContentData:
            case NSURLErrorCannotDecodeRawData:
            case NSURLErrorCannotFindHost:
            case NSURLErrorCannotParseResponse:
            case NSURLErrorClientCertificateRequired:
            case NSURLErrorDataLengthExceedsMaximum:
            case NSURLErrorDataNotAllowed:
            case NSURLErrorDNSLookupFailed:
            case NSURLErrorHTTPTooManyRedirects:
            case NSURLErrorInternationalRoamingOff:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorNotConnectedToInternet:
            case NSURLErrorRedirectToNonExistentLocation:
            case NSURLErrorRequestBodyStreamExhausted:
            case NSURLErrorSecureConnectionFailed:
            case NSURLErrorTimedOut:
            case NSURLErrorUnknown:
            case NSURLErrorUnsupportedURL:
            case NSURLErrorUserCancelledAuthentication:
            case NSURLErrorZeroByteResource:
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                return;
                
            case NSURLErrorClientCertificateRejected:
            case NSURLErrorServerCertificateHasBadDate:
            case NSURLErrorServerCertificateHasUnknownRoot:
            case NSURLErrorServerCertificateNotYetValid:
            case NSURLErrorServerCertificateUntrusted:
                // The SSL certificate is not trusted
                [self requestCertificateApprovalAfterError:error];
                return;

            case NSURLErrorUserAuthenticationRequired:
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so must now request HTTP credentials
                [self requestHttpCredentialsAfterError:error];
                return;

            default:
                break;
        }
        
        // If Piwigo used a non-trusted certificate, ask permission
        if ([Model sharedInstance].didRequestCertificateApproval) {
            // The SSL certificate is not trusted
            [self requestCertificateApprovalAfterError:error];
            return;
        }
        
        // If Piwigo server requires HTTP basic authentication, ask credentials
        if ([Model sharedInstance].didRequestHTTPauthentication){
            // Without prior knowledge, the app already tried Piwigo credentials
            // but unsuccessfully, so must now request HTTP credentials
            [self requestHttpCredentialsAfterError:error];
            return;
        }

        // HTTPS login request failed ?
        if ([[Model sharedInstance].serverProtocol isEqualToString:@"https://"] &&
            ![Model sharedInstance].userCancelledCommunication)
        {
            // Suggest HTTP connection if HTTPS attempt failed
            [self requestNonSecuredAccessAfterError:error];
            return;
        }
        
        // Display error message
        [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
    }];
}

-(void)requestCertificateApprovalAfterError:(NSError *)error
{
    NSString *message = [NSString stringWithFormat:@"%@\r\r%@", NSLocalizedString(@"loginCertFailed_message", @"Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"), [Model sharedInstance].certificateInformation];
    self.httpAlertController = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"loginCertFailed_title", @"Connection Not Private")
        message:message
        preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {
                // Should forget certificate
                [Model sharedInstance].didApproveCertificate = NO;
                // Report error
                [self loggingInConnectionError:error];
           }];
    
    UIAlertAction* acceptAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"alertOkButton", "OK")
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction * action) {
                // Will accept certificate
                [Model sharedInstance].didApproveCertificate = YES;
                // Try logging in with new HTTP credentials
                [self launchLogin];
          }];
    
    [self.httpAlertController addAction:cancelAction];
    [self.httpAlertController addAction:acceptAction];
    self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        self.httpAlertController.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:self.httpAlertController animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        }];
    });
}

-(void)requestHttpCredentialsAfterError:(NSError *)error
{
    NSString *user = [Model sharedInstance].HttpUsername;
    NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
    if (password == nil) password = @"";

    self.httpAlertController = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"loginHTTP_title", @"HTTP Credentials")
        message:NSLocalizedString(@"loginHTTP_message", @"HTTP basic authentification is required by the Piwigo server:")
        preferredStyle:UIAlertControllerStyleAlert];
    
    [self.httpAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull userTextField) {
        userTextField.placeholder = NSLocalizedString(@"loginHTTPuser_placeholder", @"username");
        userTextField.text = (user.length > 0) ? user : @"";
        userTextField.clearButtonMode = UITextFieldViewModeAlways;
        userTextField.keyboardType = UIKeyboardTypeDefault;
        userTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        userTextField.returnKeyType = UIReturnKeyContinue;
        userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
//        userTextField.delegate = self;
    }];
    
    [self.httpAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull pwdTextField) {
        pwdTextField.placeholder = NSLocalizedString(@"loginHTTPpwd_placeholder", @"password");
        pwdTextField.text = (password.length > 0) ? password : @"";
        pwdTextField.clearButtonMode = UITextFieldViewModeAlways;
        pwdTextField.keyboardType = UIKeyboardTypeDefault;
        pwdTextField.secureTextEntry = YES;
        pwdTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        pwdTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        pwdTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        pwdTextField.returnKeyType = UIReturnKeyContinue;
//        pwdTextField.delegate = self;
    }];

    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {
               // Stop logging in action, display error message
               [self loggingInConnectionError:error];
           }];
    
    self.httpLoginAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"alertOkButton", "OK")
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction * action) {
              // Store credentials
              [Model sharedInstance].HttpUsername = [self.httpAlertController.textFields objectAtIndex:0].text;
              [SAMKeychain setPassword:[self.httpAlertController.textFields objectAtIndex:1].text forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:[self.httpAlertController.textFields objectAtIndex:0].text];
              // Try logging in with new HTTP credentials
              [self launchLogin];
          }];
    
    [self.httpAlertController addAction:cancelAction];
    [self.httpAlertController addAction:self.httpLoginAction];
    self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        self.httpAlertController.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:self.httpAlertController animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)requestNonSecuredAccessAfterError:(NSError *)error
{
    self.httpAlertController = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"loginHTTPSfailed_title", @"Secure Connection Failed")
        message:NSLocalizedString(@"loginHTTPSfailed_message", @"Piwigo cannot establish a secure connection. Do you want to try to establish an insecure connection?")
        preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* cancelAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
           style:UIAlertActionStyleCancel
           handler:^(UIAlertAction * action) {
                // Stop logging in action, display error message
                [self loggingInConnectionError:error];
           }];
    
    UIAlertAction* acceptAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"alertYesButton", "Yes")
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction * action) {
                // Try logging in with HTTP scheme
                [self tryNonSecuredAccessAfterError:error];
          }];
    
    [self.httpAlertController addAction:cancelAction];
    [self.httpAlertController addAction:acceptAction];
    self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        self.httpAlertController.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:self.httpAlertController animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        }];
    });
}

-(void)tryNonSecuredAccessAfterError:(NSError *)error
{
    // Retrieve the HTTP status code (see http://www.ietf.org/rfc/rfc2616.txt)
//    NSInteger statusCode = [[[error userInfo] valueForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];

    // Proceed at their own risk
    [Model sharedInstance].serverProtocol = @"http://";

    // Display security message below credentials if needed
    self.websiteNotSecure.hidden = NO;

    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin using http: getMethodsList…");
#endif
    [SessionService getMethodsListOnCompletion:^(NSDictionary *methodsList) {
        
        // Back to default timeout
        [Model sharedInstance].sessionManager.session.configuration.timeoutIntervalForRequest = 30;

        if(methodsList) {
            // Community extension installed and active ?
            for (NSString *method in methodsList) {
                
                // Check if the Community extension is installed and active (> 2.9a)
                if([method isEqualToString:@"community.session.getStatus"]) {
                    self.usesCommunityPluginV29 = YES;
                }
            }
            // Known methods, pursue logging in…
            [self performLogin];
            
        } else {
            // Methods unknown, so we cannot reach the server, inform user
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"serverMethodsError_message", @"Failed to get server methods.\nProblem with Piwigo server?")}];
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
        }
        
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // If Piwigo server requires HTTP basic authentication, ask credentials
        if ([Model sharedInstance].didRequestHTTPauthentication){
            // Without prior knowledge, the app already tried Piwigo credentials
            // But unsuccessfully, so must now request HTTP credentials
            [self requestHttpCredentialsAfterError:error];
        } else {
            // HTTP(S) login requests failed - display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
        }
    }];
}

-(void)performLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> performLogin: starting…");
#endif
    
    // Perform login if username exists
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
                         // Don't keep unaccepted credentials
                         [SAMKeychain deletePasswordForService:[Model sharedInstance].serverName account:self.userTextField.text];

                         // Session could not be opened
                         NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server")}];
                         [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                     }
                 } onFailure:^(NSURLSessionTask *task, NSError *error) {
                     // HTTPS login request failed ?
                     if ([[Model sharedInstance].serverProtocol isEqualToString:@"https://"])
                     {
                         // Try HTTP connection if HTTPS attempt failed
                         [self tryNonSecuredAccessAfterError:error];
                     } else {
                         // Display message
                         [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                     }
                 }];
	}
	else     // No username or user cancelled communication, get only server status
	{
        // Reset keychain and credentials
        [SAMKeychain deletePasswordForService:[Model sharedInstance].serverName account:[Model sharedInstance].username];
        [Model sharedInstance].username = @"";
        [[Model sharedInstance] saveToDisk];

        // Check Piwigo version, get token, available sizes, etc.
        [self getCommunityStatusAtFirstLogin:YES];
    }
}

// Determine true user rights when Community extension installed
-(void)getCommunityStatusAtFirstLogin:(BOOL)isFirstLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> getCommunityStatusAtFirstLogin:%@ starting…", isFirstLogin ? @"YES" : @"NO");
#endif
    if((self.usesCommunityPluginV29) && (![Model sharedInstance].userCancelledCommunication)) {

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
                [Model sharedInstance].hadOpenedSession = NO;
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"serverCommunityError_message", @"Failed to get Community extension parameters.\nTry logging in again.")}];
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                self.isAlreadyTryingToLogin = NO;
            }
            
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
            [Model sharedInstance].hadOpenedSession = NO;
            self.isAlreadyTryingToLogin = NO;
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
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> getSessionStatusAtLogin:%@ andFirstLogin:%@ starting…",
          isLoggingIn ? @"YES" : @"NO", isFirstLogin ? @"YES" : @"NO");
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
                if([@"2.8.0" compare:[Model sharedInstance].version options:NSNumericSearch] == NSOrderedDescending)
                {
                    // They need to update, ask user what to do
                    // Close loading or re-login view and ask what to do
                    [self hideLoadingWithCompletion:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible")
                                    message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.8. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), [Model sharedInstance].version]
                                    preferredStyle:UIAlertControllerStyleAlert];
                            
                            UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {
                                        self.isAlreadyTryingToLogin = NO;
                                    }];
                            
                            UIAlertAction* continueAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                    style:UIAlertActionStyleDestructive
                                    handler:^(UIAlertAction * action) {
                                        // Proceed at their own risk
                                        self.isAlreadyTryingToLogin = NO;
                                        if (isFirstLogin) {
                                            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                            [appDelegate loadNavigation];
                                        }
                                    }];
                            
                            [alert addAction:defaultAction];
                            [alert addAction:continueAction];
                            alert.view.tintColor = UIColor.piwigoColorOrange;
                            if (@available(iOS 13.0, *)) {
                                alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                            } else {
                                // Fallback on earlier versions
                            }
                            [self presentViewController:alert animated:YES completion:^{
                                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                                alert.view.tintColor = UIColor.piwigoColorOrange;
                            }];
                        });
                    }];
                } else {
                    // Their version is Ok. Close HUD.
                    self.isAlreadyTryingToLogin = NO;
                    [self hideLoadingWithCompletion:^{
                        // Load navigation if needed
                        if (isFirstLogin) {
                            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                            [appDelegate loadNavigation];
                        } else {
                            // Refresh category data
                            NSDictionary *userInfo = @{@"NoHUD" : @"NO", @"fromCache" : @"NO", @"albumId" : @(0)};
                            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationGetCategoryData object:nil userInfo:userInfo];
                        }
                    }];
                }
            } else {
                // Inform user that we could not authenticate with server
                [Model sharedInstance].hadOpenedSession = NO;
                self.isAlreadyTryingToLogin = NO;
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again.")}];
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
            }
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            [Model sharedInstance].hadOpenedSession = NO;
            self.isAlreadyTryingToLogin = NO;
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
        }];
    } else {
        [Model sharedInstance].hadOpenedSession = NO;
        self.isAlreadyTryingToLogin = NO;
        [self loggingInConnectionError:nil];
    }
}

-(void)checkSessionStatusAndTryRelogin
{
    // Display HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connectionChanged", @"Connection Changed!")];
    });
    
    // Don't try to login in if already being trying
    if (self.isAlreadyTryingToLogin) return;
    
    // Check whether session is still active
    self.isAlreadyTryingToLogin = YES;
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
                    [self performRelogin];

                } else {
                    // Connection still alive. Do nothing.
                    self.isAlreadyTryingToLogin = NO;
                    [self hideLoading];
#if defined(DEBUG_SESSION)
                    NSLog(@"=> checkSessionStatusAndTryRelogin: Connection still alive…");
                    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
                          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
                          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
                }
            } else {
                // Display HUD
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showLoadingWithSubtitle:NSLocalizedString(@"login_connectionChanged", @"Connection Changed!")];
                });

                // Connection really lost, inform user
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"internetErrorGeneral_broken", @"Sorry, the communication was broken.\nTry logging in again.")}];
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                [Model sharedInstance].hadOpenedSession = NO;
                self.isAlreadyTryingToLogin = NO;
            }
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // No connection or server down
            self.isAlreadyTryingToLogin = NO;
            [Model sharedInstance].hadOpenedSession = NO;
            
            // Display message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
        }
     ];
}

-(void)performRelogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> performRelogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"),
          ([Model sharedInstance].hasNormalRights ? @"YES" : @"NO"));
#endif
    
    // Update HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });

    // Perform re-login
    NSString *user = [Model sharedInstance].username;
    NSString *password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
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
                                    [Model sharedInstance].hadOpenedSession = NO;
                                    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] code:-1 userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server")}];
                                    [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                                    self.isAlreadyTryingToLogin = NO;
                                }

                            } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Could not re-establish the session, login/pwd changed, something else ?
                                self.isAlreadyTryingToLogin = NO;
                                [Model sharedInstance].hadOpenedSession = NO;
                                
                                // Display error message
                                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : error)];
                            }];
}

#pragma mark - HUD methods

-(void)showLoadingWithSubtitle:(NSString *)subtitle
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {        
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];

        // Change the background view shape, style and color.
        hud.square = NO;
        hud.animationType = MBProgressHUDAnimationFade;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        hud.contentColor = [UIColor piwigoColorHudContent];
        hud.bezelView.color = [UIColor piwigoColorHudBezelView];
        
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
    NSArray <NSURLSessionTask *> *tasks = [[Model sharedInstance].sessionManager tasks];
    for (NSURLSessionTask *task in tasks) {
        [task cancel];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // Update login HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Update text
            hud.detailsLabel.text = NSLocalizedString(@"internetCancellingConnection_button", @"Cancelling Connection…");;
        }
    });
}

- (void)loggingInConnectionError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update login HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Show only text
            hud.mode = MBProgressHUDModeText;
            
            // Reconfigure the button
            [hud.button setTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss") forState:UIControlStateNormal];
            [hud.button addTarget:self action:@selector(hideLoading) forControlEvents:UIControlEventTouchUpInside];

            // Update text
            if (error == nil) {
                hud.label.text = NSLocalizedString(@"internetCancelledConnection_title", @"Connection Cancelled");
                hud.detailsLabel.text = @" ";
            } else {
                hud.label.text = NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error");
                hud.detailsLabel.text = [NSString stringWithFormat:@"%@", [error localizedDescription]];

                // Return to secured connection mode before user retries with updated address and/or credentials
                [Model sharedInstance].serverProtocol = @"https://";
                self.websiteNotSecure.hidden = YES;
            }
        }
    });
}

-(void)hideLoading
{
    // Reinitialise flag
    [Model sharedInstance].userCancelledCommunication = NO;

    // Hide and remove login HUD
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    [self.hudViewController resignFirstResponder];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}

-(void)hideLoadingWithCompletion:(void (^ __nullable)(void))completion
{
    // Reinitialise flag
    [Model sharedInstance].userCancelledCommunication = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Hide and remove the HUD
        [self hideLoading];
        
        // Execute block
        if (completion) {
            completion();
        }
    });
}


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable HTTP login action until user provides infos
    if (textField == [self.httpAlertController.textFields objectAtIndex:0]) {
        if ([self.httpAlertController.textFields objectAtIndex:0].text.length == 0)
            [self.httpLoginAction setEnabled:NO];
    }
    else if (textField == [self.httpAlertController.textFields objectAtIndex:1]) {
        if ([self.httpAlertController.textFields objectAtIndex:1].text.length == 0)
            [self.httpLoginAction setEnabled:NO];
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable login buttons
    if(textField == self.serverTextField) {
        [self.loginButton setEnabled:NO];
    }
    else if ((textField == [self.httpAlertController.textFields objectAtIndex:0]) ||
        (textField == [self.httpAlertController.textFields objectAtIndex:1])) {
        [self.httpLoginAction setEnabled:NO];
    }
    
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if ((textField == [self.httpAlertController.textFields objectAtIndex:0]) ||
        (textField == [self.httpAlertController.textFields objectAtIndex:1])) {
        // Enable HTTP Login action if field not empty
        [self.httpLoginAction setEnabled:(finalString.length >= 1)];
    }
    else if(textField == self.serverTextField) {
        // Disable Login button if URL invalid
        BOOL validURL = [self saveServerAddress:finalString andUsername:self.userTextField.text];
        if (!validURL) {
            [self showIncorrectWebAddressAlert];
        }
        [self.loginButton setEnabled:validURL];
    }
    
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(textField == self.serverTextField) {
        // Save server address and username to disk
        BOOL validURL = [self saveServerAddress:self.serverTextField.text andUsername:self.userTextField.text];
        [self.loginButton setEnabled:validURL];
        if (!validURL) {
            // Incorrect URL
            [self showIncorrectWebAddressAlert];
            return NO;
        }

        // User entered acceptable server address
		[self.userTextField becomeFirstResponder];
	}
    else if (textField == self.userTextField) {
        // User entered username
        NSString *pwd = [SAMKeychain passwordForService:self.serverTextField.text account:self.userTextField.text];
        if (pwd != nil) {
            self.passwordTextField.text = pwd;
        }
        [self.passwordTextField becomeFirstResponder];
	}
    else if (textField == self.passwordTextField) {
        // User entered password —> Launch login
        [self launchLogin];
	}
	return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    if(textField == self.serverTextField) {
        // Save server address and username to disk
        BOOL validURL = [self saveServerAddress:self.serverTextField.text andUsername:self.userTextField.text];
        [self.loginButton setEnabled:validURL];
        if (!validURL) {
            // Incorrect URL
            [self showIncorrectWebAddressAlert];
            return NO;
        }
    }
    return YES;
}


#pragma mark - Utilities

-(BOOL)saveServerAddress:(NSString *)serverString andUsername:(NSString *)user
{
    if (serverString.length == 0) {
        // The URL is not correct
//        NSLog(@"ATTENTION!!! Incorrect URL");
        return NO;
    }

    // Remove extra "/" at the end of the server address
    while ([serverString hasSuffix:@"/"]) {
        serverString = [serverString substringWithRange:NSMakeRange(0, serverString.length-1)];
    }
    
    // Remove extra " " at the end of the server address
    while ([serverString hasSuffix:@" "]) {
        serverString = [serverString substringWithRange:NSMakeRange(0, serverString.length-1)];
    }
    
    // User may have entered an incorrect URLs (would lead to a crash)
    NSURL *serverURL = nil;
    if ([serverString containsString:@"http://"] || [serverString containsString:@"https://"]) {
        serverURL = [NSURL URLWithString:serverString];
    }
    else {
        // Add HTTPS scheme if not provided
        serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", serverString]];
    }
    if (serverURL == nil) {
        // The URL is not correct
//        NSLog(@"ATTENTION!!! Incorrect URL");
        return NO;
    }
    
    // Is the port provided ?
//    NSLog(@"sheme:%@, user:%@, pwd:%@, host:%@, port:%@, path:%@", serverURL.scheme, serverURL.user, serverURL.password, serverURL.host, serverURL.port, serverURL.path);
    if (serverURL.port != NULL) {
        // Port provided => Adopt user choice but check protocol
        // Save username, server address and protocol to disk
        switch (serverURL.port.integerValue) {
            case 80:
                [Model sharedInstance].serverProtocol = @"http://";
                break;
                
            case 443:
                [Model sharedInstance].serverProtocol = @"https://";
                break;
                
            default:
                [Model sharedInstance].serverProtocol = [NSString stringWithFormat:@"%@://", serverURL.scheme];
                break;
        }
        [Model sharedInstance].serverName = [NSString stringWithFormat:@"%@:%@%@", serverURL.host, serverURL.port, serverURL.path];
        [Model sharedInstance].username = user;
        [[Model sharedInstance] saveToDisk];
        return YES;
    }
    
    // Will try to force HTTPS protocol
    [Model sharedInstance].serverProtocol = @"https://";
    
    // Save username, server address and protocol to disk
    [Model sharedInstance].serverName = [NSString stringWithFormat:@"%@%@", serverURL.host, serverURL.path];
    [Model sharedInstance].username = user;
    [[Model sharedInstance] saveToDisk];
    return YES;
}

-(void)showIncorrectWebAddressAlert
{
    // The URL is not correct —> inform user
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"serverURLerror_title", @"Incorrect URL")
        message:NSLocalizedString(@"serverURLerror_message", @"Please correct the Piwigo web server address.")
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)dismissKeyboard
{
    [self.view endEditing:YES];
}

-(void)openPiwigoURL
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://piwigo.org"]];
}

@end
