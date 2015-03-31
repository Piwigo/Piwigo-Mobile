//
//  SortSelectViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SortSelectViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
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
		self.title = NSLocalizedString(@"sortTitle", @"Sort Type");
		
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
		case kPiwigoSortByNewest:
			name = @"Newest"; // @TODO: localize this
			break;
		case kPiwigoSortByOldest:
			name = @"Oldest"; // @TODO: localize this
			break;
		case kPiwigoSortByName:
			name = NSLocalizedString(@"localImageSort_name", @"Name");
			break;
		case kPiwigoSortByNotUploaded:
			name = NSLocalizedString(@"localImageSort_notUploaded", @"Not Uploaded");
			break;
			
		default:
			name = NSLocalizedString(@"localImageSort_undefined", @"Undefined");
			break;
	}
	
	return name;
}

// on completion send back a list of image names (keys)
+(void)getSortedImageNameArrayFromSortType:(kPiwigoSortBy)sortType
							 forLocalAlbum:(NSURL*)localAlbum
							   forCategory:(NSInteger)category
							   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  onCompletion:(void (^)(NSArray *imageNames))completion
{
	switch(sortType)
	{
		case kPiwigoSortByNewest:
		{
			// @TODO: pass in the local album
			[self getByNewestFirstForAlbum:localAlbum onCompletion:completion];
			break;
		}
		case kPiwigoSortByOldest:
		{
			break;
		}
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

+(void)getByNewestFirstForAlbum:(NSURL*)albumURL onCompletion:(void (^)(NSArray *imageNames))completion
{
	[[PhotosFetch sharedInstance] updateLocalPhotosDictionary:^(id responseObject) {
		
		NSDictionary *imagesForAlbum = [responseObject objectForKey:albumURL];
		NSArray *sortedKeys = [[[imagesForAlbum.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] reverseObjectEnumerator] allObjects];
		
		if(completion)
		{
			completion(sortedKeys);
		}
		
	}];
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
