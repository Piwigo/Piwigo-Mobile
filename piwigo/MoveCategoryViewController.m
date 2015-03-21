//
//  MoveCategoryViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "MoveCategoryViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"

@interface MoveCategoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) PiwigoAlbumData *selectedCategory;
@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSArray *categories;

@end

@implementation MoveCategoryViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.title = NSLocalizedString(@"moveCategory", @"Move Album");
		self.selectedCategory = category;
		
		self.categories = [CategoriesData sharedInstance].allCategories;
		NSMutableArray *newCategoryArray = [[NSMutableArray alloc] initWithArray:self.categories];
		for(PiwigoAlbumData *categoryData in self.categories)
		{
			if(categoryData.albumId == category.albumId)
			{
				[newCategoryArray removeObject:categoryData];
				break;
			}
		}
		
		PiwigoAlbumData *rootAlbum = [PiwigoAlbumData new];
		rootAlbum.albumId = 0;
		rootAlbum.name = @"------------";
		[newCategoryArray insertObject:rootAlbum atIndex:0];
		self.categories = newCategoryArray;
		
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

-(void)categoryDataUpdated
{
	[self.categoriesTableView reloadData];
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
	headerLabel.text = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectParent", @"Select an album to move album \"%@\" into"), self.selectedCategory.name];
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

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
	}
	
	PiwigoAlbumData *albumData = [self.categories objectAtIndex:indexPath.row];
	
	NSInteger depth = [albumData getDepthOfCategory];
	NSString *front = [@"" stringByPaddingToLength:depth withString:@" " startingAtIndex:0];
	
	cell.textLabel.text = [NSString stringWithFormat:@"%@%@", front, albumData.name];
	cell.textLabel.lineBreakMode = NSLineBreakByTruncatingHead;
	
	if(albumData.albumId == self.selectedCategory.parentAlbumId)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *indexSelectedCategory = [self.categories objectAtIndex:indexPath.row];
	
	[UIAlertView showWithTitle:NSLocalizedString(@"moveCategory", @"Move Album")
					   message:[NSString stringWithFormat:NSLocalizedString(@"moveCategory_message", @"Are you sure you want to move \"%@\" into the album \"%@\"?"), self.selectedCategory.name, indexSelectedCategory.name]
			 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  [self makeSelectedCategoryAChildOf:indexSelectedCategory.albumId];
						  }
					  }];
}

-(void)makeSelectedCategoryAChildOf:(NSInteger)categoryId
{
	[AlbumService moveCategory:self.selectedCategory.albumId
				  intoCategory:categoryId
				  OnCompletion:^(AFHTTPRequestOperation *operation, BOOL movedSuccessfully) {
					  if(movedSuccessfully)
					  {
						  self.selectedCategory.parentAlbumId = categoryId;
						  [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
						  [self.navigationController popViewControllerAnimated:YES];
					  }
					  else
					  {
						  [self showMoveCategoryError:nil];
					  }
				  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					  [self showMoveCategoryError:[error localizedDescription]];
				  }];
}
-(void)showMoveCategoryError:(NSString*)message
{
	NSString *errorMessage = NSLocalizedString(@"moveCategoryError_message", @"Failed to move your album");
	if(message)
	{
		errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
	}
	[UIAlertView showWithTitle:NSLocalizedString(@"moveCategoryError_title", @"Move Fail")
					   message:errorMessage
			 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
			 otherButtonTitles:nil
					  tapBlock:nil];
}

@end
