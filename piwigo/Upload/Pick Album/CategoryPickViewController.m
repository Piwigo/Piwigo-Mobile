//
//  CategoryPickViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

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
		
        if (@available(iOS 11, *)) {
            [self.view addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"V:|-[admin]-[description]"
                                       options:kNilOptions metrics:nil
                                       views:@{@"admin" : adminLabel, @"description" : description}]];
        } else {
            [self.view addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"V:|-80-[admin]-[description]"
                                       options:kNilOptions metrics:nil
                                       views:@{@"admin" : adminLabel, @"description" : description}]];
        }

        // Background color of the view
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
}
	
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
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];

    // Text
    NSString *textString = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select an album to upload images to");
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];

    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select an album to upload images to");
    NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
    [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                 range:NSMakeRange(0, [textString length])];
    [headerAttributedString appendAttributedString:textAttributedString];

    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;

    // Header view
    UIView *header = [[UIView alloc] init];
	[header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
																   options:kNilOptions
																   metrics:nil
																	 views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    }
	return header;
}

@end
