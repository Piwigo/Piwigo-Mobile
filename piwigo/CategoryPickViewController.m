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
#import "CategoryTableViewCell.h"
#import "AlbumService.h"

@interface CategoryPickViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableDictionary *categoriesThatHaveLoadedSubCategories;

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
			self.categories = [NSMutableArray new];
			self.categoriesThatHaveLoadedSubCategories = [NSMutableDictionary new];
			[self buildCategoryArray];
			
			self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
			self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
			self.categoriesTableView.delegate = self;
			self.categoriesTableView.dataSource = self;
			self.categoriesTableView.backgroundColor = [UIColor piwigoWhiteCream];
			[self.categoriesTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
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
			description.textColor = [UIColor piwigoGray];
			description.numberOfLines = 4;
			description.textAlignment = NSTextAlignmentCenter;
			description.text = NSLocalizedString(@"adminRights_message", @"You're not an admin.\nYou have to be an admin to be able to upload images.");
			description.adjustsFontSizeToFitWidth = YES;
			description.minimumScaleFactor = 0.5;
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
	[self buildCategoryArray];
	[self.categoriesTableView reloadData];
}

-(void)buildCategoryArray
{
	NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
	NSMutableArray *diff = [NSMutableArray new];
	for(PiwigoAlbumData *category in allCategories)
	{
		BOOL doesNotExist = YES;
		for(PiwigoAlbumData *existingCat in self.categories)
		{
			if(category.albumId == existingCat.albumId)
			{
				doesNotExist = NO;
				break;
			}
		}
		if(doesNotExist)
		{
			[diff addObject:category];
		}
	}
	
	for(PiwigoAlbumData *category in diff)
	{
		if(category.upperCategories.count > 1)
		{
			NSInteger indexOfParent = 0;
			for(PiwigoAlbumData *existingCategory in self.categories)
			{
				if([category containsUpperCategory:existingCategory.albumId])
				{
					[self.categories insertObject:category atIndex:indexOfParent+1];
					break;
				}
				indexOfParent++;
			}
		}
		else
		{
			[self.categories addObject:category];
		}
	}
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.categories.count;
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
	headerLabel.adjustsFontSizeToFitWidth = YES;
	headerLabel.minimumScaleFactor = 0.5;
	[header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
	[header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
																   options:kNilOptions
																   metrics:nil
																	 views:@{@"header" : headerLabel}]];
	
	return header;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	cell.categoryDelegate = self;
	
	PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
	
	[cell setupWithCategoryData:categoryData];
	if([self.categoriesThatHaveLoadedSubCategories objectForKey:[NSString stringWithFormat:@"%@", @(categoryData.albumId)]])
	{
		cell.hasLoadedSubCategories = YES;
	}
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];

	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:categoryData.albumId];
	[self.navigationController pushViewController:uploadVC animated:YES];
}

#pragma mark CategoryCellDelegate Methods

-(void)tappedDisclosure:(PiwigoAlbumData *)categoryTapped
{
	[AlbumService getAlbumListForCategory:categoryTapped.albumId
							 OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
								 [self.categoriesThatHaveLoadedSubCategories setValue:@(categoryTapped.albumId) forKey:[NSString stringWithFormat:@"%@", @(categoryTapped.albumId)]];
	} onFailure:nil];
	
}

@end
