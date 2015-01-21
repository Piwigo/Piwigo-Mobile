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
		
		UploadViewController *upload = [UploadViewController new];
		upload.title = @"Upload";
		
		SettingsViewController *settings = [SettingsViewController new];
		settings.title = @"Settings";
		
		self.viewControllers = @[albums, upload, settings];
	}
	return self;
}

@end
