//
//  AppDelegate.h
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

//#import "DataController.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationPaletteChanged;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationNetworkErrorEncountered;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationAddRecentAlbum;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationRemoveRecentAlbum;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
//@property (strong, nonatomic) DataController *dataController;

//#ifdef __IPHONE_10_0
//@property (nonatomic, strong) NSPersistentContainer *persistentContainer;
//#endif
//@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
//@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
//@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

-(void)loadLoginView;
-(void)loadNavigation;
-(void)screenBrightnessChanged;

//-(NSManagedObjectContext *)managedObjectContext;
//-(void)saveContext;

@end
