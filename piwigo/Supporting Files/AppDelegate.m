//
//  AppDelegate.m
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "LoginNavigationController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"
#import "TabBarViewController.h"
#import "SessionService.h"
#import "Model.h"
#import "KeychainAccess.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "Reachability.h"

#import "PhotosFetch.h"
#import "iRate.h"

@interface AppDelegate ()

@property (nonatomic, strong) LoginViewController *loginVC;
@property (nonatomic, strong) Reachability *internetReachability;

@end

@implementation AppDelegate

+ (void)initialize {
    //configure iRate
    [iRate sharedInstance].appStoreID       = 472225196;
    [iRate sharedInstance].daysUntilPrompt  = 5;
    [iRate sharedInstance].usesUntilPrompt  = 5;
    [iRate sharedInstance].promptForNewVersionIfUserRated = YES;
    [iRate sharedInstance].promptAtLaunch   = NO;
//#warning Preview mode
//    [iRate sharedInstance].previewMode      = YES;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	
    // Override point for customization after application launch.
	
	NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:[Model sharedInstance].memoryCache * 1024*1024
														 diskCapacity:[Model sharedInstance].diskCache * 1024*1024
															 diskPath:nil];
	[NSURLCache setSharedURLCache:URLCache];
	
	NSString *server = [Model sharedInstance].serverName;
	NSString *user = [KeychainAccess getLoginUser];
	NSString *password = [KeychainAccess getLoginPassword];
	if(server.length > 0 || (user.length > 0 && password.length > 0))
	{
		[self.loginVC performLogin];
	}
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[self.window makeKeyAndVisible];
	[self loadLoginView];
	
	[AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
	
	return YES;
}

-(void)loadNavigation
{
	TabBarViewController *navigation = [TabBarViewController new];
	self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:navigation];
	[self.loginVC removeFromParentViewController];
	self.loginVC = nil;
    
    // Observe the kNetworkReachabilityChangedNotification.
    // When that notification is posted, the method reachabilityChanged will be called.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    // Monitor Internet connection reachability
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
}

// Called by Reachability whenever Internet connection changes.
- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    NetworkStatus netStatus = [curReach currentReachabilityStatus];

    switch (netStatus)
    {
        case NotReachable:
        {
#if defined(DEBUG)
            NSLog(@"Access Not Available");
#endif
            break;
        }
        case ReachableViaWWAN:
        case ReachableViaWiFi:
        {
            // Connection changed but again reachable — Login again?
            BOOL hadOpenedSession = [Model sharedInstance].hadOpenedSession;
            NSString *server = [Model sharedInstance].serverName;
            NSString *user = [KeychainAccess getLoginUser];

            if(hadOpenedSession && (server.length > 0) && (user.length > 0))
            {
                [self.loginVC checkSessionStatusAndTryRelogin];
            }
            break;
        }
    }
}

-(void)loadLoginView
{
	LoginNavigationController *nav = [[LoginNavigationController alloc] initWithRootViewController:self.loginVC];
	[nav setNavigationBarHidden:YES];
	self.window.rootViewController = nav;
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

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

    // Should we reopen the session ?
    BOOL hadOpenedSession = [Model sharedInstance].hadOpenedSession;
    NSString *server = [Model sharedInstance].serverName;
    NSString *user = [KeychainAccess getLoginUser];
    if(hadOpenedSession && (server.length > 0) && (user.length > 0))
    {
        // Let's see…
        [self.loginVC checkSessionStatusAndTryRelogin];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
