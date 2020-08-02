//
//  AppDelegate.m
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <UserNotifications/UserNotifications.h>

#import "AppDelegate.h"
#import "LoginNavigationController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"

#import "AFNetworkActivityIndicatorManager.h"
#import "AlbumImagesViewController.h"
#import "IQKeyboardManager.h"
#import "KeychainAccess.h"
#import "Model.h"
#import "SAMKeychain.h"

//#ifndef DEBUG_NOCACHE
//#define DEBUG_NOCACHE
//#endif

NSString * const kPiwigoNotificationPaletteChanged = @"kPiwigoNotificationPaletteChanged";
NSString * const kPiwigoNotificationNetworkErrorEncountered = @"kPiwigoNotificationNetworkErrorEncountered";
NSString * const kPiwigoNotificationAddRecentAlbum = @"kPiwigoNotificationAddRecentAlbum";
NSString * const kPiwigoNotificationRemoveRecentAlbum = @"kPiwigoNotificationRemoveRecentAlbum";

@interface AppDelegate ()

@property (nonatomic, strong) LoginViewController *loginVC;

@end

@implementation AppDelegate

+ (void)initialize {}

-(void)loadNavigation
{
    // Resume upload manager
    [self resumeUploadManager];

    // Display default album
    AlbumImagesViewController *defaultAlbum = [[AlbumImagesViewController alloc] initWithAlbumId:[Model sharedInstance].defaultCategory inCache:NO];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:defaultAlbum];
    [self.loginVC removeFromParentViewController];
	self.loginVC = nil;
    
    // Observe the UIScreenBrightnessDidChangeNotification
    // When that notification is posted, the method screenBrightnessChanged will be called.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenBrightnessChanged) name:UIScreenBrightnessDidChangeNotification object:nil];

    // Observe the PiwigoNetworkErrorEncounteredNotification
    // When that notification is posted, the app checks the login.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkSessionStatusAndTryRelogin) name:kPiwigoNotificationNetworkErrorEncountered object:nil];
    
    // Observe the PiwigoAddRecentAlbumNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addRecentAlbumWithAlbumId:) name:kPiwigoNotificationAddRecentAlbum object:nil];

    // Observe the PiwigoRemoveRecentAlbumNotification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeRecentAlbumWithAlbumId:) name:kPiwigoNotificationRemoveRecentAlbum object:nil];

    // Set network reachability status change block
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
//#if defined(DEBUG)
//        NSLog(@"!!!!!! Network Reachability Changed!");
//        NSLog(@"       hadOpenedSession=%@, usesCommunityPluginV29=%@, hasAdminRights=%@",
//              ([Model sharedInstance].hadOpenedSession ? @"YES" : @"NO"),
//              ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
//              ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
//#endif

        if ([AFNetworkReachabilityManager sharedManager].reachable) {
            // Connection changed but again reachable — Login again?
            [self checkSessionStatusAndTryRelogin];
        }
    }];
}


#pragma mark - Login view

-(void)loadLoginView
{
    LoginNavigationController *nav = [[LoginNavigationController alloc] initWithRootViewController:self.loginVC];
	[nav setNavigationBarHidden:YES];
	self.window.rootViewController = nav;
    
    // Next line fixes #259 view not displayed with iOS 8 and 9 on iPad
    [self.window.rootViewController.view setNeedsUpdateConstraints];

    // Color palette depends on system settings
    if (@available(iOS 13.0, *)) {
        [Model sharedInstance].isSystemDarkModeActive = (self.loginVC.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
//        NSLog(@"•••> iOS mode: %@, app mode: %@, Brightness: %.1ld/%ld, app: %@", [Model sharedInstance].isSystemDarkModeActive ? @"Dark" : @"Light", [Model sharedInstance].isDarkPaletteModeActive ? @"Dark" : @"Light", lroundf([[UIScreen mainScreen] brightness] * 100.0), (long)[Model sharedInstance].switchPaletteThreshold, [Model sharedInstance].isDarkPaletteActive ? @"Dark" : @"Light");
    } else {
        // Fallback on earlier versions
        [Model sharedInstance].isSystemDarkModeActive = NO;
    }
    
    // Apply color palette
    [self screenBrightnessChanged];
}

-(LoginViewController*)loginVC
{
	if(_loginVC) return _loginVC;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        _loginVC = [LoginViewController_iPhone new];
    } else {
        _loginVC = [LoginViewController_iPad new];
    }
	return _loginVC;
}

-(void)checkSessionStatusAndTryRelogin
{
    BOOL hadOpenedSession = [Model sharedInstance].hadOpenedSession;
    NSString *server = [Model sharedInstance].serverName;
    NSString *user = [KeychainAccess getLoginUser];
    
    if(hadOpenedSession && (server.length > 0) && (user.length > 0))
    {
#if defined(DEBUG)
        NSLog(@"       Connection changed but again reachable: Login in again");
#endif
        [self.loginVC checkSessionStatusAndTryRelogin];
    }
}


#pragma mark - Settings bundle

// Updates the version and build numbers in the app's settings bundle.
- (void)setSettingsBundleData
{
    // Get the Settings.bundle object
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Get bunch of values from the .plist file and take note that the values that
    // we pull are generated in a Build Phase script that is definied in the Target.
    NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    // Create the version number
    NSString *versionNumberInSettings = [NSString stringWithFormat:@"%@ (%@)", appVersionString, appBuildString];
    
    // Set the build date and version number in the settings bundle reflected in app settings.
    [defaults setObject:versionNumberInSettings forKey:@"version_prefs"];
}


#pragma mark - Application delegate methods

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Register notifications for displaying number of uploads to perform in app badge
    if (@available(iOS 9.0, *)) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge) categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
    else if (@available(iOS 10.0, *)) {
        UNAuthorizationOptions options = (UNAuthorizationOptionBadge);
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) { NSLog(@"request succeeded!"); }
        }];
    }
        
    // IQKeyboardManager
    IQKeyboardManager *keyboardManager = [IQKeyboardManager sharedManager];
    keyboardManager.overrideKeyboardAppearance = YES;
    keyboardManager.shouldToolbarUsesTextFieldTintColor = YES;
    keyboardManager.shouldShowToolbarPlaceholder = YES;

    // Cache data in Core Data storage
    [self setManagedObjectContext:[DataController getContext]];

//    [self setDataController:[[DataController alloc] initWithCompletionBlock:^{
        //Complete user interface initialization
        // Login ?
        NSString *user, *password;
        NSString *server = [Model sharedInstance].serverName;
        [SAMKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlock];
        
        // Look for credentials if server address provided
        if (server.length > 0)
        {
            // Known acounts for that server?
            NSArray *accounts = [SAMKeychain accountsForService:server];
            if ((accounts == nil) || ([accounts count] <= 0))
            {
                // No credentials available for that server. And with the old methods?
                user = [KeychainAccess getLoginUser];
                password = [KeychainAccess getLoginPassword];
                
                // Store credentials with new method if found
                if (user.length > 0) {
                    [Model sharedInstance].username = user;
                    [[Model sharedInstance] saveToDisk];
                    [SAMKeychain setPassword:password forService:server account:user];
                }
            } else {
                // Credentials available
                user = [Model sharedInstance].username;
                if (user.length > 0) {
                    password = [SAMKeychain passwordForService:server account:user];
                }
            }
        }
        
        // Login?
        if(server.length > 0 || (user.length > 0 && password.length > 0))
        {
            [self.loginVC launchLogin];
        }
        
        // No login
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [self.window makeKeyAndVisible];
        [self loadLoginView];
//    }]];
    
    // Enable network activity indicator
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    // Enable network reachability monitoring
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    
    // Set Settings Bundle data
    [self setSettingsBundleData];
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(nonnull NSData *)deviceToken {
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(nonnull NSError *)error {
    NSLog(@"Did fail to register notifications");
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    
    // Save cached data
    [DataController saveContext];

    // Cancel tasks and close sessions
    [[Model sharedInstance].sessionManager invalidateSessionCancelingTasks:YES resetSession:YES];
    [[Model sharedInstance].imagesSessionManager invalidateSessionCancelingTasks:YES resetSession:YES];

    // Disable network activity indicator
    [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
    
    // Disable network reachability monitoring
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
    
    // Empty /tmp directory
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.

    // Save cached data
    [DataController saveContext];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    // Save cached data
    [DataController saveContext];

    // Disable network activity indicator
    [AFNetworkActivityIndicatorManager sharedManager].enabled = NO;
    
    // Disable network reachability monitoring
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

    // Enable network activity indicator
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    // Enable network reachability monitoring
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];

    // Should we reopen the session ?
    BOOL hadOpenedSession = [Model sharedInstance].hadOpenedSession;
    NSString *server = [Model sharedInstance].serverName;
    NSString *user = [Model sharedInstance].username;
    if (hadOpenedSession && (server.length > 0) && (user.length > 0))
    {
        // Let's see…
        [self.loginVC checkSessionStatusAndTryRelogin];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Piwigo Mobile will play audio even if the Silent switch set to silent or when the screen locks.
    // Furthermore, it will interrupt any other current audio sessions (no mixing)
    if (@available(iOS 9, *)) {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSArray<NSString *> *availableCategories = [audioSession availableCategories];
        if ([availableCategories containsObject:AVAudioSessionCategoryPlayback]) {
            [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
        }
    }
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)(void))completionHandler {
    NSLog(@"    > Handle events for background session with ID: %@", identifier);
    
    if ([identifier compare:[UploadSessionDelegate shared].uploadSessionIdentifier] == NSOrderedSame) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                              delegate:[UploadSessionDelegate shared]
                                                         delegateQueue:nil];
        [UploadSessionDelegate shared].uploadSessionCompletionHandler = completionHandler;
        NSLog(@"    > Rejoining session %@ with CompletionHandler", session);
    }
}


#pragma mark - Light and dark modes

// Called when the screen brightness has changed, when user changes settings
// and by traitCollectionDidChange: when the system switches between Light and Dark modes
-(void)screenBrightnessChanged
{
    if ([Model sharedInstance].isDarkPaletteModeActive || [Model sharedInstance].isSystemDarkModeActive)
    {
        if ([Model sharedInstance].isDarkPaletteActive) {
            // Already showing dark palette
            return;
        } else {
            // "Always Dark Mode" selected or iOS Dark Mode active => Dark palette
            [Model sharedInstance].isDarkPaletteActive = YES;
        }
    }
    else if ([Model sharedInstance].switchPaletteAutomatically)
    {
        // Dynamic palette mode chosen and iOS Light Mode active
        NSInteger currentBrightness = lroundf([[UIScreen mainScreen] brightness] * 100.0);
        if ([Model sharedInstance].isDarkPaletteActive) {
            // Dark palette displayed
            if (currentBrightness > [Model sharedInstance].switchPaletteThreshold)
            {
                // Screen brightness > thereshold, switch to light palette
                [Model sharedInstance].isDarkPaletteActive = NO;
            } else {
                // Keep dark palette
                return;
            }
        } else {
            // Light palette displayed
            if (currentBrightness < [Model sharedInstance].switchPaletteThreshold)
            {
                // Screen brightness < threshold, switch to dark palette
                [Model sharedInstance].isDarkPaletteActive = YES;
            } else {
                // Keep light palette
                return;
            }
        }
    } else {
        // Static light palette mode
        if ([Model sharedInstance].isDarkPaletteActive)
        {
            // Switch to light palette
            [Model sharedInstance].isDarkPaletteActive = NO;
        } else {
            // Keep light palette
            return;
        }
    }
    
    // Store modified settings
    [[Model sharedInstance] saveToDisk];
    
    // Tint colour
    [UIView appearance].tintColor = [UIColor piwigoColorOrange];
    
    // Activity indicator
    [UIActivityIndicatorView appearance].color = [UIColor piwigoColorOrange];

    // Tab bars
    [UITabBar appearance].barTintColor = [UIColor piwigoColorBackground];

    // Styles
    if ([Model sharedInstance].isDarkPaletteActive)
    {
        [UITabBar appearance].barStyle = UIBarStyleBlack;
        [UIToolbar appearance].barStyle = UIBarStyleBlack;
    }
    else {
        [UITabBar appearance].barStyle = UIBarStyleDefault;
        [UIToolbar appearance].barStyle = UIBarStyleDefault;
    }

    // Notify palette change to views
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationPaletteChanged object:nil];
//    NSLog(@"•••> app changed to %@ mode", [Model sharedInstance].isDarkPaletteActive ? @"Dark" : @"Light");
}


#pragma mark - Recent albums

-(void)addRecentAlbumWithAlbumId:(NSNotification *)notification
{
    // NOP if albumId undefined, root or smart album
    NSDictionary *userInfo = notification.userInfo;
    NSInteger categoryId = [[userInfo objectForKey:@"categoryId"] integerValue];
    if ((categoryId <= 0) || (categoryId == NSNotFound)) return;

    // Get current list of recent albums
    NSString *recentAlbumsStr = [Model sharedInstance].recentCategories;

    // Create new list of recent albums
    NSMutableArray *newList = [NSMutableArray new];
    
    // Compile new list
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", (long)categoryId];
    if (recentAlbumsStr.length == 0)
    {
        // Empty list => simply add albumId
        [newList addObject:categoryIdStr];
    }
    else {
        // Non-empty list
        NSMutableArray<NSString *> *recentCategories = [[recentAlbumsStr componentsSeparatedByString:@","] mutableCopy];
        
        // Add albumId to top of list
        [newList addObject:categoryIdStr];

        // Remove albumId from old list if necessary
        [recentCategories removeObjectIdenticalTo:categoryIdStr];
        
        // Append old list
        [newList addObjectsFromArray:recentCategories];

        // Will limit list to 3 - 10 objects (5 by default) when presenting albums
        // As some recent albums may not be suggested or other may be deleted, we store more than 10, say 20
        NSUInteger count = [newList count];
        if (count > 20) {
            NSRange range = NSMakeRange(20, count - 20);
            [newList removeObjectsInRange:range];
        }
    }

    // Update list
    [Model sharedInstance].recentCategories = [newList componentsJoinedByString:@","];
    [[Model sharedInstance] saveToDisk];
//    NSLog(@"•••> Recent albums: %@ (max: %lu)", [Model sharedInstance].recentCategories, (unsigned long)[Model sharedInstance].maxNberRecentCategories);
}

-(void)removeRecentAlbumWithAlbumId:(NSNotification *)notification
{
    // NOP if albumId undefined, root or smart album
    NSDictionary *userInfo = notification.userInfo;
    NSInteger categoryId = [[userInfo objectForKey:@"categoryId"] integerValue];
    if ((categoryId <= 0) || (categoryId == NSNotFound)) return;

    // Get current list of recent albums
    NSString *recentAlbumsStr = [Model sharedInstance].recentCategories;
    if (recentAlbumsStr.length == 0) return;

    // Non-empty list, continue
    NSString *categoryIdStr = [NSString stringWithFormat:@"%ld", (long)categoryId];
    NSMutableArray<NSString *> *recentCategories = [[recentAlbumsStr componentsSeparatedByString:@","] mutableCopy];
        
    // Remove albumId from list if necessary
    [recentCategories removeObjectIdenticalTo:categoryIdStr];
    
    // List should not be empty (add root album Id)
    if (recentCategories.count == 0) [recentCategories addObject:@"0"];
    
    // Update list
    [Model sharedInstance].recentCategories = [recentCategories componentsJoinedByString:@","];
    [[Model sharedInstance] saveToDisk];
//    NSLog(@"•••> Recent albums: %@", [Model sharedInstance].recentCategories);
}

#pragma mark - Upload Manager

-(void)resumeUploadManager {
    // Create dedicated background queue if needed
    if (self.uploadQueue == nil) {
        /* Create a serial queue. */
        dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, -1);
        self.uploadQueue = dispatch_queue_create("UploadManager", attributes);
    }
    
    // Resume upload tasks
    dispatch_async(self.uploadQueue, ^{
        [[UploadManager shared] resumeAll];
    });
}

-(void)triggerUploadManager {
    // Trigger upload tasks
    dispatch_async(self.uploadQueue, ^{
        [[UploadManager shared] findNextImageToUpload];
    });
}

@end
