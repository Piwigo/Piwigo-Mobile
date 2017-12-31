//
//  CategoryPickViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <sys/utsname.h>                    // For determining iOS device model

#import "CategoryPickViewController.h"
#import "CategoriesData.h"
#import "LocalAlbumsViewController.h"
#import "Model.h"
#import "AlbumService.h"
#import "PhotosFetch.h"

@interface CategoryPickViewController () <CategoryListDelegate>

@end

@implementation CategoryPickViewController

-(instancetype)init
{
	// User can upload images/videos if he/she has:
    // — admin rights
    // — opened a session on a server having Community extension installed
    if(([Model sharedInstance].hasAdminRights) ||
       ([Model sharedInstance].usesCommunityPluginV29 && [Model sharedInstance].hadOpenedSession))
	{
		self = [super init];
		self.categoryListDelegate = self;
		
		[[PhotosFetch sharedInstance] getLocalGroupsOnCompletion:nil];
	}
	else
	{
		self = (CategoryPickViewController*)[[UIViewController alloc] init];
		
		UILabel *adminLabel = [UILabel new];
		adminLabel.translatesAutoresizingMaskIntoConstraints = NO;
		adminLabel.font = [UIFont piwigoFontNormal];
		adminLabel.font = [adminLabel.font fontWithSize:20];
		adminLabel.textColor = [UIColor piwigoWhiteCream];
		adminLabel.text = NSLocalizedString(@"uploadRights_title", @"Upload Rights Needed");
		adminLabel.minimumScaleFactor = 0.5;
		adminLabel.adjustsFontSizeToFitWidth = YES;
		adminLabel.textAlignment = NSTextAlignmentCenter;
		[self.view addSubview:adminLabel];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:adminLabel]];
		[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[admin]-10-|"
																		  options:kNilOptions
																		  metrics:nil
																			views:@{@"admin" : adminLabel}]];
		
		UILabel *description = [UILabel new];
		description.translatesAutoresizingMaskIntoConstraints = NO;
		description.font = [UIFont piwigoFontNormal];
		description.textColor = [UIColor piwigoWhiteCream];
		description.numberOfLines = 4;
		description.textAlignment = NSTextAlignmentCenter;
		description.text = NSLocalizedString(@"uploadRights_message", @"You must have upload rights to be able to upload images or videos.");
		description.adjustsFontSizeToFitWidth = YES;
		description.minimumScaleFactor = 0.5;
		[self.view addSubview:description];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:description]];
		[self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"|-[description]-|"
                                   options:kNilOptions metrics:nil
                                   views:@{@"description" : description}]];
		
        // iPhone X ?
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        
        if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"]) {
            // Add 25px for iPhone X (not great in landscape mode but temporary solution)
            [self.view addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"V:|-105-[admin]-[description]"
                                       options:kNilOptions metrics:nil
                                       views:@{@"admin" : adminLabel, @"description" : description}]];
        } else {
            [self.view addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"V:|-80-[admin]-[description]"
                                       options:kNilOptions metrics:nil
                                       views:@{@"admin" : adminLabel, @"description" : description}]];
        }
		
	}
	
	self.view.backgroundColor = [UIColor piwigoBackgroundColor];
	
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;

    // Tab bar appearance
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];
}

-(void)selectedCategory:(PiwigoAlbumData *)category
{
	if(category)
	{
		LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:category.albumId];
		[self.navigationController pushViewController:localAlbums animated:YES];
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 64.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
	
	UILabel *headerLabel = [UILabel new];
	headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoHeaderColor];
	headerLabel.text = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select an album to upload images to");
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
	[header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
	[header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
																   options:kNilOptions
																   metrics:nil
																	 views:@{@"header" : headerLabel}]];
	
	return header;
}

@end
