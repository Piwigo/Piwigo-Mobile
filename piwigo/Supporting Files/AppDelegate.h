//
//  AppDelegate.h
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

FOUNDATION_EXPORT NSString * const kPiwigoNotificationPaletteChanged;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationNetworkErrorEncountered;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationAddRecentAlbum;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationRemoveRecentAlbum;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

#ifdef __IPHONE_10_0
@property (strong, readonly) NSPersistentContainer *persistentContainer;
#endif
@property (strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

-(void)loadLoginView;
-(void)loadNavigation;
-(void)screenBrightnessChanged;
-(void)saveContext;

@end
