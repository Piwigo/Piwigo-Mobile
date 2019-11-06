//
//  AppDelegate.h
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kPiwigoPaletteChangedNotification;
FOUNDATION_EXPORT NSString * const kPiwigoNetworkErrorEncounteredNotification;
FOUNDATION_EXPORT NSString * const kPiwigoAddRecentAlbumNotification;
FOUNDATION_EXPORT NSString * const kPiwigoRemoveRecentAlbumNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

-(void)loadLoginView;
-(void)loadNavigation;
-(void)screenBrightnessChanged;

@end
