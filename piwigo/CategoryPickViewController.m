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
		
		self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.categoriesTableView.delegate = self;
		self.categoriesTableView.dataSource = self;
		self.categoriesTableView.backgroundColor = [UIColor piwigoWhiteCream];
		[self.view addSubview:self.categoriesTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.categoriesTableView]];
		
		
	}
	return self;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[CategoriesData sharedInstance].categories allKeys].count;
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
	[header addConstraint:[NSLayoutConstraint constrainViewFromBottom:headerLabel amount:10]];
	[header addConstraint:[NSLayoutConstraint constrainViewFromLeft:headerLabel amount:15]];
	
	return header;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
	}
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectForKey:[[CategoriesData sharedInstance].categories.allKeys objectAtIndex:indexPath.row]];
	
	cell.textLabel.text = albumData.name;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectForKey:[[CategoriesData sharedInstance].categories.allKeys objectAtIndex:indexPath.row]];
	
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:albumData.albumId];
	[self.navigationController pushViewController:uploadVC animated:YES];
}

@end
