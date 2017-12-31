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
#import "Model.h"

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
        self.sortSelectTableView.backgroundColor = [UIColor clearColor];
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
		[self.view addSubview:self.sortSelectTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.sortSelectTableView]];
		
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
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

    // Table view
    self.sortSelectTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.sortSelectTableView reloadData];
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
    // Header height?
    NSString *header = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:nil];
    return ceil(headerRect.size.height + 4.0 + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontSmall];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];
    
    // Header view
    UIView *header = [[UIView alloc] initWithFrame:headerRect];
    header.backgroundColor = [UIColor clearColor];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
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
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
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
