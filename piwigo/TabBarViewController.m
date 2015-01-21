//
//  TabBarViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TabBarViewController.h"
#import "AlbumsViewController.h"
#import "UploadViewController.h"
#import "SettingsViewController.h"

@interface TabBarViewController ()

@end

@implementation TabBarViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.tabBar.tintColor = [UIColor whiteColor];
		self.tabBar.barTintColor = [UIColor piwigoOrange];
		
		AlbumsViewController *albums = [AlbumsViewController new];
		albums.title = @"Albums";
		albums.tabBarItem.image = [UIImage imageNamed:@"album"];
		albums.tabBarItem.selectedImage = [UIImage imageNamed:@"albumSelected"];
		
		UploadViewController *upload = [UploadViewController new];
		upload.title = @"Upload";
		upload.tabBarItem.image = [UIImage imageNamed:@"cloud"];
		upload.tabBarItem.selectedImage = [UIImage imageNamed:@"cloudSelected"];
		
		SettingsViewController *settings = [SettingsViewController new];
		settings.title = @"Settings";
		settings.tabBarItem.image = [UIImage imageNamed:@"preferences"];
		settings.tabBarItem.selectedImage = [UIImage imageNamed:@"preferencesSelected"];
		
		self.viewControllers = @[albums, upload, settings];
	}
	return self;
}

@end
