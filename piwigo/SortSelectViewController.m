//
//  SortSelectViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SortSelectViewController.h"
#import "NotUploadedYet.h"
#import "PhotosFetch.h"

@interface SortSelectViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *sortSelectTableView;

@end

@implementation SortSelectViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		self.title = @"Sort Type"; // @TODO: Localize this!
		
		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
		[self.view addSubview:self.sortSelectTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.sortSelectTableView]];
		
	}
	return self;
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if([self.delegate respondsToSelector:@selector(didSelectSortTypeOf:)])
	{
		[self.delegate didSelectSortTypeOf:self.currentSortType];
	}
}

+(NSString*)getNameForSortType:(kPiwigoSortBy)sortType
{
	NSString *name = @"";
	
	switch(sortType)
	{
		case kPiwigoSortByName:
			name = @"Name"; // @TODO: Localize this!
			break;
		case kPiwigoSortByNotUploaded:
			name = @"Not Uploaded"; // @TODO: Localize this!
			break;
			
		default:
			name = @"Undefined"; // @TODO: Localize this!
			break;
	}
	
	return name;
}

+(void)getSortedImageNameArrayFromSortType:(kPiwigoSortBy)sortType
							   forCategory:(NSInteger)category
							   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  onCompletion:(void (^)(NSArray *imageNames))completion
{
	switch(sortType)
	{
		case kPiwigoSortByName:
		{
			[self getByNameImageListForCategory:category onCompletion:completion];
			break;
		}
		case kPiwigoSortByNotUploaded:
		{
			[self getNotUploadedImageListForCategory:category forProgress:progress onCompletion:completion];
			break;
		}
		
		default:
		{
			if(completion)
			{
				completion(nil);
			}
		}
	}
}

+(void)getByNameImageListForCategory:(NSInteger)category onCompletion:(void (^)(NSArray *imageNames))completion
{
	[[PhotosFetch sharedInstance] updateLocalPhotosDictionary:^(id responseObject) {
		if(completion)
		{
			completion([PhotosFetch sharedInstance].sortedImageKeys);
		}
	}];
}

+(void)getNotUploadedImageListForCategory:(NSInteger)category
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							 onCompletion:(void (^)(NSArray *imageNames))completion
{
	[NotUploadedYet getListOfImageNamesThatArentUploadedForCategory:category
														forProgress:progress
													   onCompletion:^(NSArray *missingImages) {
															if(completion)
															{
																completion(missingImages);
															}
													   }];
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kPiwigoSortByCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
	
	cell.textLabel.text = [SortSelectViewController getNameForSortType:(kPiwigoSortBy)indexPath.row];
	
	if(indexPath.row == self.currentSortType)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	self.currentSortType = (kPiwigoSortBy)indexPath.row;
	[tableView reloadData];
	[self.navigationController popViewControllerAnimated:YES];
}

@end
