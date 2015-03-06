//
//  CategoryPickViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryPickViewController.h"
#import "CategoriesData.h"
#import "UploadViewController.h"
#import "Model.h"

@interface CategoryPickViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;

@end

@implementation CategoryPickViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		
		if([Model sharedInstance].hasAdminRights)
		{
			self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
			self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
			self.categoriesTableView.delegate = self;
			self.categoriesTableView.dataSource = self;
			self.categoriesTableView.backgroundColor = [UIColor piwigoWhiteCream];
			[self.view addSubview:self.categoriesTableView];
			[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.categoriesTableView]];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		}
		else
		{
			UILabel *adminLabel = [UILabel new];
			adminLabel.translatesAutoresizingMaskIntoConstraints = NO;
			adminLabel.font = [UIFont piwigoFontNormal];
			adminLabel.font = [adminLabel.font fontWithSize:20];
			adminLabel.textColor = [UIColor piwigoOrange];
			adminLabel.text = NSLocalizedString(@"adminRights_title", @"Admin Rights Needed");
			[self.view addSubview:adminLabel];
			[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:adminLabel]];
			
			UILabel *description = [UILabel new];
			description.translatesAutoresizingMaskIntoConstraints = NO;
			description.font = [UIFont piwigoFontNormal];
			description.textColor = [UIColor piwigoGray];
			description.numberOfLines = 4;
			description.textAlignment = NSTextAlignmentCenter;
			description.text = NSLocalizedString(@"adminRights_message", @"You're not an admin.\nYou have to be an admin to be able to upload images.");
			[self.view addSubview:description];
			[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:description]];
			[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[description]-|"
																			  options:kNilOptions
																			  metrics:nil
																				views:@{@"description" : description}]];
			
			[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[admin]-[description]"
																			  options:kNilOptions
																			  metrics:nil
																				views:@{@"admin" : adminLabel,
																						@"description" : description}]];
			
		}
		
	}
	return self;
}

-(void)categoryDataUpdated
{
	[self.categoriesTableView reloadData];
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [CategoriesData sharedInstance].categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 50.0;
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
	
	UILabel *headerLabel = [UILabel new];
	headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoGray];
	headerLabel.text = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select an album to upload images to");
	[header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
	[header addConstraint:[NSLayoutConstraint constraintViewFromLeft:headerLabel amount:15]];
	
	return header;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
	}
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectAtIndex:indexPath.row];
	
	cell.textLabel.text = albumData.name;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectAtIndex:indexPath.row];
	
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:albumData.albumId];
	[self.navigationController pushViewController:uploadVC animated:YES];
}

@end
