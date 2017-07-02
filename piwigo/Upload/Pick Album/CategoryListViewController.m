//
//  CategoryListViewController.m
//  piwigo
//
//  Created by Spencer Baker on 4/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryListViewController.h"
#import "CategoriesData.h"
#import "CategoryTableViewCell.h"
#import "AlbumService.h"

@interface CategoryListViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSMutableDictionary *categoriesThatHaveLoadedSubCategories;

@end

@implementation CategoryListViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.categories = [NSMutableArray new];
		self.categoriesThatHaveLoadedSubCategories = [NSMutableDictionary new];
		[self buildCategoryArray];
		
		self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.categoriesTableView.delegate = self;
		self.categoriesTableView.dataSource = self;
		self.categoriesTableView.backgroundColor = [UIColor piwigoGray];
		[self.categoriesTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.categoriesTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.categoriesTableView]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
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
	
    // Look for missing categories
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
	
    // Append missing categories below their parent categories
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
	
	if(self.categories.count > indexPath.row)
	{
		PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
		
		if([self.categoryListDelegate respondsToSelector:@selector(selectedCategory:)])
		{
			[self.categoryListDelegate selectedCategory:categoryData];
		}
	}
}

#pragma mark CategoryCellDelegate Methods

-(void)tappedDisclosure:(PiwigoAlbumData *)categoryTapped
{
	[AlbumService getAlbumListForCategory:categoryTapped.albumId
							 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
								 [self.categoriesThatHaveLoadedSubCategories setValue:@(categoryTapped.albumId) forKey:[NSString stringWithFormat:@"%@", @(categoryTapped.albumId)]];
							 } onFailure:nil];
	
}


@end
