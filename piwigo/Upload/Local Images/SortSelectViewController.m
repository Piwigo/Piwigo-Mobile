//
//  SortSelectViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

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
		self.title = NSLocalizedString(@"imageSortTitle", @"Sort Images");

		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.sortSelectTableView.backgroundColor = [UIColor piwigoGray];
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
			name = NSLocalizedString(@"localImageSort_newest", @"Newest");
			break;
		case kPiwigoSortByOldest:
			name = NSLocalizedString(@"localImageSort_oldest", @"Oldest");
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
+(void)getSortedImageArrayFromSortType:(kPiwigoSortBy)sortType
							 forImages:(NSArray*)images
						   forCategory:(NSInteger)category
						   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
						  onCompletion:(void (^)(NSArray *images))completion
{
	switch(sortType)
	{
		case kPiwigoSortByNewest:
		{
			[self organizeImages:images byNewestFirstOnCompletion:completion];
			break;
		}
		case kPiwigoSortByOldest:
		{
			[self organizeImages:images byOldestFirstOnCompletion:completion];
			break;
		}
		case kPiwigoSortByNotUploaded:
		{
			[self getNotUploadedImageListForCategory:category withImages:images forProgress:progress onCompletion:completion];
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

+(void)organizeImages:(NSArray*)images byNewestFirstOnCompletion:(void (^)(NSArray *images))completion
{
	NSArray *sortedImages = [images sortedArrayUsingComparator:^NSComparisonResult(PHAsset *obj1, PHAsset *obj2) {
		return [obj1.creationDate compare:obj2.creationDate] != NSOrderedDescending;
	}];
	
	if(completion)
	{
		completion(sortedImages);
	}
}

+(void)organizeImages:(NSArray*)images byOldestFirstOnCompletion:(void (^)(NSArray *images))completion
{
	NSArray *sortedImages = [images sortedArrayUsingComparator:^NSComparisonResult(PHAsset *obj1, PHAsset *obj2) {
		return [obj1.creationDate compare:obj2.creationDate] != NSOrderedAscending;
	}];
	
	if(completion)
	{
		completion(sortedImages);
	}
}

+(void)getNotUploadedImageListForCategory:(NSInteger)category
							   withImages:(NSArray*)images
							  forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							 onCompletion:(void (^)(NSArray *imageNames))completion
{
	[NotUploadedYet getListOfImageNamesThatArentUploadedForCategory:category
														 withImages:images
														forProgress:progress
													   onCompletion:completion];
}

#pragma mark UITableView Methods

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
    headerLabel.textColor = [UIColor piwigoOrange];
    headerLabel.text = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
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
    cell.textLabel.textColor = [UIColor piwigoGray];
    cell.textLabel.backgroundColor = [UIColor piwigoWhiteCream];
	
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
