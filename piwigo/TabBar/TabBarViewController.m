//
//  TabBarViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TabBarViewController.h"
#import "AlbumsViewController.h"
#import "CategoryPickViewController.h"
#import "SettingsViewController.h"

@interface TabBarViewController ()

@end

@implementation TabBarViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		NSMutableArray *tabs = [NSMutableArray new];
		
		AlbumsViewController *albums = [AlbumsViewController new];
		albums.title = NSLocalizedString(@"tabBar_albums", @"Albums");
		albums.tabBarItem.image = [[UIImage imageNamed:@"album"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		albums.tabBarItem.selectedImage = [UIImage imageNamed:@"albumSelected"];
		[tabs addObject:[[UINavigationController alloc] initWithRootViewController:albums]];
		
		CategoryPickViewController *upload = [CategoryPickViewController new];
		upload.title = NSLocalizedString(@"tabBar_upload", @"Upload");
		upload.tabBarItem.image = [[UIImage imageNamed:@"cloud"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		upload.tabBarItem.selectedImage = [UIImage imageNamed:@"cloudSelected"];
		[tabs addObject:[[UINavigationController alloc] initWithRootViewController:upload]];
		
		SettingsViewController *settings = [SettingsViewController new];
		settings.title = NSLocalizedString(@"tabBar_preferences", @"Preferences");
		settings.tabBarItem.image = [[UIImage imageNamed:@"preferences"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		settings.tabBarItem.selectedImage = [UIImage imageNamed:@"preferencesSelected"];
		[tabs addObject:[[UINavigationController alloc] initWithRootViewController:settings]];
		
        self.tabBar.tintColor = [UIColor piwigoOrange];
        self.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
        if (@available(iOS 10, *)) {
            self.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
        }
		[[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
		[[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];
		
		self.viewControllers = tabs;
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationController.navigationBarHidden = YES;
}

@end
