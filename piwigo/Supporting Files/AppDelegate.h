//
//  AppDelegate.h
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UploadManager;

FOUNDATION_EXPORT NSString * const kPiwigoNotificationPaletteChanged;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationNetworkErrorEncountered;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationAddRecentAlbum;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationRemoveRecentAlbum;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) UploadManager *uploadManager;
@property (nonatomic, strong) dispatch_queue_t uploadQueue;

-(void)loadLoginView;
-(void)loadNavigation;
-(void)screenBrightnessChanged;
-(void)resumeUploadManager;
-(void)triggerUploadManager;

@end
