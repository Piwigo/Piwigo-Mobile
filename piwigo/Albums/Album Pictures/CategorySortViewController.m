//
//  CategorySortViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategorySortViewController.h"

@interface CategorySortViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *sortSelectTableView;

@end

NSInteger const kBorderSpacing = 10;                // Spacing between collection items

@implementation CategorySortViewController

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
	
	if([self.sortDelegate respondsToSelector:@selector(didSelectCategorySortType:)])
	{
		[self.sortDelegate didSelectCategorySortType:self.currentCategorySortType];
	}
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kPiwigoSortCategoryCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
	
	cell.textLabel.text = [CategorySortViewController getNameForCategorySortType:(kPiwigoSortCategory)indexPath.row];
	cell.textLabel.minimumScaleFactor = 0.5;
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
	
	if(indexPath.row == self.currentCategorySortType)
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
	
	self.currentCategorySortType = (kPiwigoSortCategory)indexPath.row;
	[tableView reloadData];
	[self.navigationController popViewControllerAnimated:YES];
}


+(NSString*)getNameForCategorySortType:(kPiwigoSortCategory)sortType
{
	NSString *name = @"";
	switch(sortType)
	{
		case kPiwigoSortCategoryNameAscending:
			name = NSLocalizedString(@"categorySort_nameAscending", @"Photo Title, A → Z");
			break;
		case kPiwigoSortCategoryNameDescending:
			name = NSLocalizedString(@"categorySort_nameDescending", @"Photo Title, Z → A");
			break;
		case kPiwigoSortCategoryFileNameAscending:
			name = NSLocalizedString(@"categorySort_fileNameAscending", @"File Name, A → Z");
			break;
		case kPiwigoSortCategoryFileNameDescending:
			name = NSLocalizedString(@"categorySort_fileNameDescending", @"File Name, Z → A");
			break;
        case kPiwigoSortCategoryDateCreatedDescending:
            name = NSLocalizedString(@"categorySort_dateCreatedDescending", @"Date Created, new → old");
            break;
        case kPiwigoSortCategoryDateCreatedAscending:
            name = NSLocalizedString(@"categorySort_dateCreatedAscending", @"Date Created, old → new");
            break;
		case kPiwigoSortCategoryDatePostedDescending:
			name = NSLocalizedString(@"categorySort_datePostedDescending", @"Date Posted, new → old");
			break;
		case kPiwigoSortCategoryDatePostedAscending:
			name = NSLocalizedString(@"categorySort_datePostedAscending", @"Date Posted, old → new");
			break;
//		case kPiwigoSortCategoryVideoOnly:
//			name = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case kPiwigoSortCategoryImageOnly:
//			name = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;
			
		case kPiwigoSortCategoryCount:
			break;
	}
	return name;
}

#pragma mark Determine number of images per row

+(int)numberOfImagesPerRowForCollectionView:(UICollectionView *)collectionView
{
    // Thumbnails should always be available on server (default size of 144x144 pixels)
    // We display at least 3 thumbnails per row whilst not exceeding thumbnails size
    return (int)fmax(3.0, ceilf((collectionView.frame.size.width - kBorderSpacing) / (kBorderSpacing + 144.0)));
}

@end
