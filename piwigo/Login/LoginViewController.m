//
//  LoginViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AFNetworking/AFImageDownloader.h>
#import <sys/utsname.h>

#import "CategoriesData.h"
#import "LoginViewController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"
#import "MBProgressHUD.h"

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

NSString * const kPiwigoSupport = @"— iOS@piwigo.org —";

@interface LoginViewController () <UITextFieldDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) UIAlertController *httpAlertController;
@property (nonatomic, strong) UIAlertAction *httpLoginAction;
@property (nonatomic, strong) UIViewController *hudViewController;

@end

@implementation LoginViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoColorBrown];
		
        self.piwigoLogo = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.piwigoLogo setImage:[UIImage imageNamed:@"piwigoLogo"] forState:UIControlStateNormal];
		self.piwigoLogo.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoLogo.contentMode = UIViewContentModeScaleAspectFit;
        [self.piwigoLogo addTarget:self action:@selector(openPiwigoURL) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.piwigoLogo];
		
        self.piwigoButton = [UIButton new];
        self.piwigoButton.backgroundColor = [UIColor clearColor];
        self.piwigoButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoButton.titleLabel.font = [UIFont piwigoFontNormal];
        [self.piwigoButton setTitleColor:[UIColor piwigoColorOrange] forState:UIControlStateNormal];
        [self.piwigoButton setTitle:kPiwigoSupport forState:UIControlStateNormal];
        [self.piwigoButton addTarget:self action:@selector(mailPiwigoSupport) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.piwigoButton];

        self.serverTextField = [PiwigoTextField new];
		self.serverTextField.placeholder = NSLocalizedString(@"login_serverPlaceholder", @"example.com");
		self.serverTextField.text = [NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];
		self.serverTextField.keyboardType = UIKeyboardTypeURL;
		self.serverTextField.returnKeyType = UIReturnKeyNext;
		self.serverTextField.delegate = self;
		[self.view addSubview:self.serverTextField];
				
		self.userTextField = [PiwigoTextField new];
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username (optional)");
		self.userTextField.text = NetworkVarsObjc.username;
        self.userTextField.keyboardType = UIKeyboardTypeDefault;
		self.userTextField.returnKeyType = UIReturnKeyNext;
        if (@available(iOS 11.0, *)) {
            self.userTextField.textContentType = UITextContentTypeUsername;
        }
		self.userTextField.delegate = self;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password (optional)");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [KeychainUtilitiesObjc passwordForService:NetworkVarsObjc.serverPath account:NetworkVarsObjc.username];
        self.passwordTextField.keyboardType = UIKeyboardTypeDefault;
        if (@available(iOS 11.0, *)) {
            self.passwordTextField.textContentType = UITextContentTypePassword;
        }
		self.passwordTextField.returnKeyType = UIReturnKeyGo;
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

    return self;
}

-(UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}


#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self applyColorPalette];
    
    // Not yet trying to login
    self.isAlreadyTryingToLogin = NO;

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:PwgNotificationsObjc.paletteChanged object:nil];
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
    if (AppVars.shared.isDarkPaletteActive) {
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
            AppVars.shared.isSystemDarkModeActive = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate screenBrightnessChanged];
        }
    } else {
        // Fallback on earlier versions
    }
}

-(void)dealloc
{
    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PwgNotificationsObjc.paletteChanged object:nil];
    
    // Release memory
    self.hudViewController = nil;
}


#pragma mark - Login business

-(void)launchLogin
{
    // User pressed "Login"
    [self.view endEditing:YES];

    // Default settings
    self.isAlreadyTryingToLogin = YES;
    NetworkVarsObjc.hasAdminRights = NO;
    NetworkVarsObjc.hasNormalRights = NO;
    NetworkVarsObjc.usesCommunityPluginV29 = NO;
    
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          (NetworkVarsObjc.usesCommunityPluginV29 ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasAdminRights ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasNormalRights ? @"YES" : @"NO"));
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
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
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
//    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
//    self.hudViewController = rootViewController.childViewControllers.firstObject;
    self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"login_loggingIn", @"Logging In...")
              detail:NSLocalizedString(@"login_connecting", @"Connecting")
         buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
        buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
              inMode:MBProgressHUDModeIndeterminate];
    
    // Save credentials in Keychain (needed before login when using HTTP Authentication)
    if(self.userTextField.text.length > 0)
    {
        // Store credentials in Keychain
        [KeychainUtilitiesObjc setPassword:self.passwordTextField.text forService:NetworkVarsObjc.serverPath account:self.userTextField.text];
    }

    // Create permanent session managers for retrieving data and downloading images
    [NetworkHandler createJSONdataSessionManager];      // 30s timeout, 4 connections max
    [NetworkHandler createFavoritesDataSessionManager]; // 30s timeout, 1 connection max
    [NetworkHandler createImagesSessionManager];        // 60s timeout, 4 connections max
    
    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: getMethodsList using %@", NetworkVarsObjc.serverProtocol);
#endif
    NetworkVarsObjc.sessionManager.session.configuration.timeoutIntervalForRequest = 10;
    [LoginUtilities getMethodsWithCompletion:^{
        
        // Back to default timeout
        NetworkVarsObjc.sessionManager.session.configuration.timeoutIntervalForRequest = 30;

        // Known methods, pursue logging in…
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performLogin];
        });
        
    } failure:^(NSError * _Nonnull error) {

        // If Piwigo used a non-trusted certificate, ask permission
        if (NetworkVarsObjc.didRejectCertificate) {
            // The SSL certificate is not trusted
            [self requestCertificateApprovalAfterError:error];
            return;
        }
        
        // HTTP Basic authentication required?
        if (error.code == 401 || error.code == 403 || NetworkVarsObjc.didFailHTTPauthentication) {
            // Without prior knowledge, the app already tried Piwigo credentials
            // but unsuccessfully, so we request HTTP credentials
            [self requestHttpCredentialsAfterError:error];
            return;
        }
        
        switch ([error code]) {
            case NSURLErrorUserAuthenticationRequired:
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so must now request HTTP credentials
                [self requestHttpCredentialsAfterError:error];
                return;

            case NSURLErrorUserCancelledAuthentication:
                [self loggingInConnectionError:nil];
                return;
                
            case NSURLErrorBadServerResponse:
            case NSURLErrorBadURL:
            case NSURLErrorCallIsActive:
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
            case NSURLErrorTimedOut:
            case NSURLErrorUnknown:
            case NSURLErrorUnsupportedURL:
            case NSURLErrorZeroByteResource:
                [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
                return;
                
            case NSURLErrorCannotConnectToHost:
                // Happens when the server does not reply to the request (HTTP or HTTPS)
            case NSURLErrorSecureConnectionFailed:
                // HTTPS request failed ?
                if ([NetworkVarsObjc.serverProtocol isEqualToString:@"https://"] &&
                    !NetworkVarsObjc.userCancelledCommunication)
                {
                    // Suggest HTTP connection if HTTPS attempt failed
                    [self requestNonSecuredAccessAfterError:error];
                    return;
                }
                return;
                
            case NSURLErrorClientCertificateRejected:
            case NSURLErrorServerCertificateHasBadDate:
            case NSURLErrorServerCertificateHasUnknownRoot:
            case NSURLErrorServerCertificateNotYetValid:
            case NSURLErrorServerCertificateUntrusted:
                // The SSL certificate is not trusted
                [self requestCertificateApprovalAfterError:error];
                return;

            default:
                break;
        }
        
        // Display error message
        [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
    }];
}

-(void)requestCertificateApprovalAfterError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [NSString stringWithFormat:@"%@\r\r%@", NSLocalizedString(@"loginCertFailed_message", @"Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"), NetworkVarsObjc.certificateInformation];
        self.httpAlertController = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"loginCertFailed_title", @"Connection Not Private")
            message:message
            preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* cancelAction = [UIAlertAction
               actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
               style:UIAlertActionStyleCancel
               handler:^(UIAlertAction * action) {
                    // Should forget certificate
            NetworkVarsObjc.didApproveCertificate = NO;
                    // Report error
                    [self loggingInConnectionError:error];
               }];
        
        UIAlertAction* acceptAction = [UIAlertAction
              actionWithTitle:NSLocalizedString(@"alertOkButton", "OK")
              style:UIAlertActionStyleDefault
              handler:^(UIAlertAction * action) {
                    // Cancel task
                    [NetworkVarsObjc.sessionManager invalidateSessionCancelingTasks:YES resetSession:YES];
                    // Will accept certificate
                    NetworkVarsObjc.didApproveCertificate = YES;
                    // Try logging in with approved certificate
                    [self launchLogin];
              }];
        
        [self.httpAlertController addAction:cancelAction];
        [self.httpAlertController addAction:acceptAction];
        self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        if (@available(iOS 13.0, *)) {
            self.httpAlertController.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [self presentViewController:self.httpAlertController animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        }];
    });
}

-(void)requestHttpCredentialsAfterError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *user = NetworkVarsObjc.httpUsername;
        NSString *password = [KeychainUtilitiesObjc passwordForService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:user];
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
            userTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
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
            pwdTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
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
                  NetworkVarsObjc.httpUsername = [self.httpAlertController.textFields objectAtIndex:0].text;
                  [KeychainUtilitiesObjc setPassword:[self.httpAlertController.textFields objectAtIndex:1].text forService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:[self.httpAlertController.textFields objectAtIndex:0].text];
                  // Try logging in with new HTTP credentials
                  [self launchLogin];
              }];
        
        [self.httpAlertController addAction:cancelAction];
        [self.httpAlertController addAction:self.httpLoginAction];
        self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        if (@available(iOS 13.0, *)) {
            self.httpAlertController.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [self presentViewController:self.httpAlertController animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        }];
    });
}

-(void)requestNonSecuredAccessAfterError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
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
            self.httpAlertController.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [self presentViewController:self.httpAlertController animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            self.httpAlertController.view.tintColor = UIColor.piwigoColorOrange;
        }];
    });
}

-(void)tryNonSecuredAccessAfterError:(NSError *)error
{
    // Proceed at their own risk
    NetworkVarsObjc.serverProtocol = @"http://";
    
    // Update URL on UI
    self.serverTextField.text = [NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];

    // Display security message below credentials
    self.websiteNotSecure.hidden = NO;

    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin using http: getMethodsList…");
#endif
    [LoginUtilities getMethodsWithCompletion:^{
        // Back to default timeout
        NetworkVarsObjc.sessionManager.session.configuration.timeoutIntervalForRequest = 30;
        
        // Known methods, pursue logging in…
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performLogin];
        });

    } failure:^(NSError * _Nonnull error) {
        // Get Piwigo methods failed
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
        });
    }];
}

-(void)performLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          (NetworkVarsObjc.usesCommunityPluginV29 ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasAdminRights ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> performLogin: starting…");
#endif
    
    // Perform login if username exists
    NSString *username = self.userTextField.text;
    NSString *password = self.passwordTextField.text;
	if((self.userTextField.text.length > 0) && (!NetworkVarsObjc.userCancelledCommunication))
	{
        // Update HUD during login
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"login_loggingIn", @"Logging In...")
                  detail:NSLocalizedString(@"login_newSession", @"Opening Session")
             buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
            buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
                  inMode:MBProgressHUDModeIndeterminate];
        
        // Perform login
        [LoginUtilities sessionLoginWithUsername:username password:password
                                      completion:^(void) {
            // Session now opened
            // First determine user rights if Community extension installed
            [self getCommunityStatusAtFirstLogin:YES withReloginCompletion:^{}];
            
        } failure:^(NSError * _Nonnull error) {
            // Don't keep unaccepted credentials
            [KeychainUtilitiesObjc deletePasswordForService:NetworkVarsObjc.serverPath
                                                    account:username];
            // Login request failed
            [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
        }];
	}
	else     // No username or user cancelled communication, get only server status
	{
        // Reset keychain and credentials
        [KeychainUtilitiesObjc deletePasswordForService:NetworkVarsObjc.serverPath
                                                account:NetworkVarsObjc.username];
        NetworkVarsObjc.username = @"";

        // Check Piwigo version, get token, available sizes, etc.
        [self getCommunityStatusAtFirstLogin:YES withReloginCompletion:^{}];
    }
}

// Determine true user rights when Community extension installed
-(void)getCommunityStatusAtFirstLogin:(BOOL)isFirstLogin
                withReloginCompletion:(void (^)(void))reloginCompletion
{
#if defined(DEBUG_SESSION)
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          (NetworkVarsObjc.usesCommunityPluginV29 ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasAdminRights ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> getCommunityStatusAtFirstLogin:%@ starting…", isFirstLogin ? @"YES" : @"NO");
#endif
    if ((NetworkVarsObjc.usesCommunityPluginV29) &&
        (!NetworkVarsObjc.userCancelledCommunication))
    {
        // Update HUD during login
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"login_loggingIn", @"Logging In...")
                  detail:NSLocalizedString(@"login_communityParameters", @"Community Parameters")
             buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
            buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
                  inMode:MBProgressHUDModeIndeterminate];
        
        // Community extension installed
        [LoginUtilities communityGetStatusWithCompletion:^{
            // Check Piwigo version, get token, available sizes, etc.
            [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin withReloginCompletion:reloginCompletion];
        }
        failure:^(NSError * _Nonnull error) {
            // Inform user that server failed to retrieve Community parameters
            NetworkVarsObjc.hadOpenedSession = NO;
            self.isAlreadyTryingToLogin = NO;
            [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
        }];
    } else {
        // Community extension not installed
        // Check Piwigo version, get token, available sizes, etc.
        [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin withReloginCompletion:reloginCompletion];
    }
}

// Check Piwigo version, get token, available sizes, etc.
-(void)getSessionStatusAtLogin:(BOOL)isLoggingIn
                 andFirstLogin:(BOOL)isFirstLogin
         withReloginCompletion:(void (^)(void))reloginCompletion
{
#if defined(DEBUG_SESSION)
    NSLog(@"   hudViewController=%@, hasAdminRights=%@, hasNormalRights=%@",
          (NetworkVarsObjc.usesCommunityPluginV29 ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasAdminRights ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> getSessionStatusAtLogin:%@ andFirstLogin:%@ starting…",
          isLoggingIn ? @"YES" : @"NO", isFirstLogin ? @"YES" : @"NO");
#endif
    if (!NetworkVarsObjc.userCancelledCommunication) {
        // Update HUD during login
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"login_loggingIn", @"Logging In...")
                  detail:NSLocalizedString(@"login_serverParameters", @"Piwigo Parameters")
             buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
            buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
                  inMode:MBProgressHUDModeIndeterminate];
        
        [LoginUtilities sessionGetStatusAtLogin:isLoggingIn completion:^{
            if([@"2.8.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedAscending)
            {   // They need to update, ask user what to do
                // Reinitialise flag
                NetworkVarsObjc.userCancelledCommunication = NO;
                
                // Close loading or re-login view and ask what to do
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.hudViewController hidePiwigoHUDWithCompletion:^{
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
                                [self launchAppAtFirstLogin:isFirstLogin
                                      withReloginCompletion:reloginCompletion];
                                }];
                        [self presentPiwigoAlertWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible") message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.8. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), NetworkVarsObjc.version] actions:@[defaultAction, continueAction]];
                    }];
                });
            } else {
                // Their version is Ok. Close HUD.
                [self launchAppAtFirstLogin:isFirstLogin
                      withReloginCompletion:reloginCompletion];
            }
        } failure:^(NSError * _Nonnull error) {
            NetworkVarsObjc.hadOpenedSession = NO;
            self.isAlreadyTryingToLogin = NO;
            // Display error message
            [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
        }];
    } else {
        NetworkVarsObjc.hadOpenedSession = NO;
        self.isAlreadyTryingToLogin = NO;
        [self loggingInConnectionError:nil];
    }
}

-(void)launchAppAtFirstLogin:(BOOL)isFirstLogin
       withReloginCompletion:(void (^)(void))reloginCompletion
{
    self.isAlreadyTryingToLogin = NO;
    NetworkVarsObjc.dateOfLastLogin = [NSDate date];

    // Load navigation if needed
    if (isFirstLogin) {
        // Update HUD during login
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")
                  detail:NSLocalizedString(@"tabBar_albums", @"Albums")
             buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
            buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
                  inMode:MBProgressHUDModeIndeterminate];

        // Load category data in recursive mode
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),^{
            [AlbumService getAlbumDataOnCompletion:^(NSURLSessionTask *task, BOOL didChange) {
                // Reinitialise flag
                NetworkVarsObjc.userCancelledCommunication = NO;
                
                // Hide HUD and present root album
                if (self.hudViewController) {
                    [self.hudViewController hidePiwigoHUDWithCompletion:^{
                        // Present Album/Images view and resume uploads
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate loadNavigation];
                    }];
                } else {
                    [self hidePiwigoHUDWithCompletion:^{
                        // Present Album/Images view and resume uploads
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate loadNavigation];
                    }];
                }
                
                // Load favorites in the background if necessary
                if (!NetworkVarsObjc.hasGuestRights &&
                    ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending))
                {
                    // Initialise favorites album
                    PiwigoAlbumData *favoritesAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
                    [CategoriesData.sharedInstance updateCategories:@[favoritesAlbum]];
                    
                    // Load favorites data in the background with dedicated URL session
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0),^{
                        [[CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)AlbumVars.shared.defaultSort
                        forProgress:nil onCompletion:nil onFailure:nil];
                    });
                }
            }
            onFailure:^(NSURLSessionTask *task, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Inform user that we could not load album data
                    NetworkVarsObjc.hadOpenedSession = NO;
                    [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
                });
            }];
        });
    }
    else {
        // Hide HUD if needed
        if (self.hudViewController) {
            [self.hudViewController hidePiwigoHUDWithCompletion:^{
                if (reloginCompletion) { reloginCompletion(); }
            }];
        } else {
            [self hidePiwigoHUDWithCompletion:^{
                if (reloginCompletion) { reloginCompletion(); }
            }];
        }
    }
}

-(void)performReloginWithCompletion:(void (^)(void))reloginCompletion
{
#if defined(DEBUG_SESSION)
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@, hasNormalRights=%@",
          (NetworkVarsObjc.usesCommunityPluginV29 ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasAdminRights ? @"YES" : @"NO"),
          (NetworkVarsObjc.hasNormalRights ? @"YES" : @"NO"));
    NSLog(@"=> performRelogin: starting…");
#endif
    
    // Don't try to relogin in if already being trying
    if (self.isAlreadyTryingToLogin) return;
    
    // Do not present HUD during re-login
    self.hudViewController = nil;

    // Perform re-login
    NSString *username = NetworkVarsObjc.username;
    NSString *password = [KeychainUtilitiesObjc passwordForService:NetworkVarsObjc.serverPath account:username];
    self.isAlreadyTryingToLogin = YES;
    [LoginUtilities sessionLoginWithUsername:username password:password completion:^{
        // Session re-opened
        // First determine user rights if Community extension installed
        [self getCommunityStatusAtFirstLogin:NO
                       withReloginCompletion:reloginCompletion];
    }
    failure:^(NSError * _Nonnull error) {
        // Could not re-establish the session, login/pwd changed, something else ?
        self.isAlreadyTryingToLogin = NO;
        
        // Return to login view
        dispatch_async(dispatch_get_main_queue(), ^{
            [ClearCache closeSessionAndClearCacheWithCompletion:^{
                // Display error message
                self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
                [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
            }];
        });
    }];
}

-(void)reloadCatagoryDataInBckgMode
{
    // Load category data in recursive mode in the background
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),^{
        [AlbumService getAlbumDataOnCompletion:^(NSURLSessionTask *task, BOOL didChange) {
            UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController.childViewControllers.lastObject;
            if ([viewController isKindOfClass:[AlbumImagesViewController class]]) {
                // Check data source and reload collection if needed
                AlbumImagesViewController *vc = (AlbumImagesViewController *)viewController;
                [vc checkDataSourceWithChangedCategories:didChange];
            }

            // Resume uploads
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate resumeAll];
            
            // Load favorites in the background if necessary
//            if (!NetworkVarsObjc.hasGuestRights &&
//                ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending))
//            {
//                // Initialise favorites album
//                PiwigoAlbumData *favoritesAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
//                [CategoriesData.sharedInstance updateCategories:@[favoritesAlbum]];
//
//                // Load favorites data in the background with dedicated URL session
//                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0),^{
//                    [[CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] loadAllCategoryImageDataWithSort:(kPiwigoSortObjc)AlbumVars.shared.defaultSort
//                    forProgress:nil onCompletion:nil onFailure:nil];
//                });
//            }
        }
        onFailure:^(NSURLSessionTask *task, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Inform user that we could not load album data
                [self loggingInConnectionError:(NetworkVarsObjc.userCancelledCommunication ? nil : error)];
            });
        }];
    });
}


#pragma mark - HUD methods

- (void)cancelLoggingIn
{
    // Propagate user's request
    NetworkVarsObjc.userCancelledCommunication = YES;
    [NetworkVarsObjc.dataSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
        for (NSURLSessionTask *task in tasks) {
            [task cancel];
        }
    }];
    NSArray <NSURLSessionTask *> *tasks = [NetworkVarsObjc.sessionManager tasks];
    for (NSURLSessionTask *task in tasks) {
        [task cancel];
    }

    // Update login HUD
    [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"login_loggingIn", @"Logging In...")
              detail:NSLocalizedString(@"internetCancellingConnection_button", @"Cancelling Connection…")
         buttonTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection")
        buttonTarget:self buttonSelector:@selector(cancelLoggingIn)
              inMode:MBProgressHUDModeIndeterminate];
}

- (void)loggingInConnectionError:(NSError *)error
{
    // Do not present error message when executing background task
    if (UploadVarsObjc.isExecutingBackgroundUploadTask) {
        [self hideLoading];
        return;
    }

    if (error == nil) {
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"internetCancelledConnection_title", @"Connection Cancelled")
                  detail:@" "
             buttonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            buttonTarget:self buttonSelector:@selector(hideLoading)
                  inMode:MBProgressHUDModeText];
    } else {
        NSString *detail = [error localizedDescription];
        if (detail.length == 0) {
            detail = [NSString stringWithFormat:@"%ld", error.code];
        }
        [self.hudViewController showPiwigoHUDWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                  detail:detail
             buttonTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            buttonTarget:self buttonSelector:@selector(hideLoading)
                  inMode:MBProgressHUDModeText];
    }
}

-(void)hideLoading
{
    // Reinitialise flag
    NetworkVarsObjc.userCancelledCommunication = NO;

    // Hide and remove login HUD
    [self.hudViewController hidePiwigoHUDWithCompletion:^{ }];
}


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable HTTP login action until user provides credentials
    if (self.httpAlertController != nil) {
        // Requesting autorisation to access non secure web site
        // or asking HTTP basic authentication credentials
        if (self.httpAlertController.textFields.count > 0) {
            // Being requesting HTTP basic authentication credentials
            if (textField == [self.httpAlertController.textFields objectAtIndex:0]) {
                if ([self.httpAlertController.textFields objectAtIndex:0].text.length == 0)
                    [self.httpLoginAction setEnabled:NO];
            } else if (textField == [self.httpAlertController.textFields objectAtIndex:1]) {
                if ([self.httpAlertController.textFields objectAtIndex:1].text.length == 0)
                    [self.httpLoginAction setEnabled:NO];
            }
        }
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable login buttons
    if(textField == self.serverTextField) {
        [self.loginButton setEnabled:NO];
    }
    else if (self.httpAlertController != nil) {
        // Requesting autorisation to access non secure web site
        // or asking HTTP basic authentication credentials
        if (self.httpAlertController.textFields.count > 0) {
            // Being requesting HTTP basic authentication credentials
            if ((textField == [self.httpAlertController.textFields objectAtIndex:0]) ||
                (textField == [self.httpAlertController.textFields objectAtIndex:1])) {
                [self.httpLoginAction setEnabled:NO];
            }
        }
    }
    
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if (textField == self.serverTextField) {
        // Disable Login button if URL invalid
        [self saveServerAddress:finalString andUsername:self.userTextField.text];
        [self.loginButton setEnabled:YES];
    }
    else if (self.httpAlertController != nil) {
        // Requesting autorisation to access non secure web site
        // or asking HTTP basic authentication credentials
        if (self.httpAlertController.textFields.count > 0) {
            // Being requesting HTTP basic authentication credentials
            if ((textField == [self.httpAlertController.textFields objectAtIndex:0]) ||
                (textField == [self.httpAlertController.textFields objectAtIndex:1])) {
                // Enable HTTP Login action if field not empty
                [self.httpLoginAction setEnabled:(finalString.length >= 1)];
            }
        }
    }
    
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == self.serverTextField) {
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
        NSString *pwd = [KeychainUtilitiesObjc passwordForService:self.serverTextField.text account:self.userTextField.text];
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
                NetworkVarsObjc.serverProtocol = @"http://";
                break;
                
            case 443:
                NetworkVarsObjc.serverProtocol = @"https://";
                break;
                
            default:
                NetworkVarsObjc.serverProtocol = [NSString stringWithFormat:@"%@://", serverURL.scheme];
                break;
        }

        // Hide/show warning
        if ([NetworkVarsObjc.serverProtocol isEqual:@"https://"]) {
            // Hide security message below credentials if needed
            self.websiteNotSecure.hidden = YES;
        } else {
            // Show security message below credentials if needed
            self.websiteNotSecure.hidden = NO;
        }

        // Save username, server address and protocol to disk
        NetworkVarsObjc.serverPath = [NSString stringWithFormat:@"%@:%@%@", serverURL.host, serverURL.port, serverURL.path];
        NetworkVarsObjc.username = user;
        return YES;
    }
    
    // Store scheme
    NetworkVarsObjc.serverProtocol = [NSString stringWithFormat:@"%@://", serverURL.scheme];

    // Hide/show warning
    if ([NetworkVarsObjc.serverProtocol isEqual:@"https://"]) {
        // Hide security message below credentials if needed
        self.websiteNotSecure.hidden = YES;
    } else {
        // Show security message below credentials if needed
        self.websiteNotSecure.hidden = NO;
    }

    // Save username, server address and protocol to disk
    NetworkVarsObjc.serverPath = [NSString stringWithFormat:@"%@%@", serverURL.host, serverURL.path];
    NetworkVarsObjc.username = user;
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
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
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

-(void)mailPiwigoSupport
{
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController* composeVC = [[MFMailComposeViewController alloc] init];
        composeVC.mailComposeDelegate = self;
        
        // Configure the fields of the interface.
        [composeVC setToRecipients:@[NSLocalizedStringFromTableInBundle(@"contact_email", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact email")]];
        
        // Collect version and build numbers
        NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        
        // Compile ticket number from current date
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:NetworkVarsObjc.language]];
        NSDate *date = [NSDate date];
        NSString *ticketDate = [dateFormatter stringFromDate:date];

        // Set subject
        [composeVC setSubject:[NSString stringWithFormat:@"[Ticket#%@]: %@", ticketDate, NSLocalizedString(@"settings_appName", @"Piwigo Mobile")]];
        
        // Collect system and device data
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString* deviceModel = [DeviceUtilities nameForCode:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding]];
        NSString *deviceOS = [[UIDevice currentDevice] systemName];
        NSString *deviceOSversion = [[UIDevice currentDevice] systemVersion];
        
        // Set message body
        [composeVC setMessageBody:[NSString stringWithFormat:@"%@ %@ (%@)\n%@ — %@ %@\n==============>>\n\n", NSLocalizedString(@"settings_appName", @"Piwigo Mobile"), appVersionString, appBuildString, deviceModel, deviceOS, deviceOSversion] isHTML:NO];
        
        // Present the view controller modally.
        [self presentViewController:composeVC animated:YES completion:nil];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
