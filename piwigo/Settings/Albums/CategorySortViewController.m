//
//  CategorySortViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "CategorySortViewController.h"
#import "Model.h"

@interface CategorySortViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *sortSelectTableView;

@end


@implementation CategorySortViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
		
		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.sortSelectTableView.backgroundColor = [UIColor clearColor];
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
        [self.sortSelectTableView setAccessibilityIdentifier:@"sortSelect"];
		[self.view addSubview:self.sortSelectTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.sortSelectTableView]];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoPaletteChangedNotification object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];

    // Table view
    self.sortSelectTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.sortSelectTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.sortSelectTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if([self.sortDelegate respondsToSelector:@selector(didSelectCategorySortType:)])
	{
		[self.sortDelegate didSelectCategorySortType:self.currentCategorySortType];
	}
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"defaultImageSort>414px", @"Default Sort of Images")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    
    // Text
    NSString *textString = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"defaultImageSort>414px", @"Default Sort of Images")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
    [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                 range:NSMakeRange(0, [textString length])];
    [headerAttributedString appendAttributedString:textAttributedString];
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;
    
    // Header view
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    }
    
    return header;
}


#pragma mark - UITableView - Rows

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
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
	cell.textLabel.text = [CategorySortViewController getNameForCategorySortType:(kPiwigoSortCategory)indexPath.row];
	cell.textLabel.minimumScaleFactor = 0.5;
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    if (indexPath.row == 0)
        [cell setAccessibilityIdentifier:@"sortAZ"];

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


#pragma mark - UITableViewDelegate Methods

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
	switch (sortType)
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
        case kPiwigoSortCategoryRatingScoreDescending:
            name = NSLocalizedString(@"categorySort_ratingScoreDescending", @"Rating Score, high → low");
            break;
        case kPiwigoSortCategoryRatingScoreAscending:
            name = NSLocalizedString(@"categorySort_ratingScoreAscending", @"Rating Score, low → high");
            break;
        case kPiwigoSortCategoryVisitsDescending:
            name = NSLocalizedString(@"categorySort_visitsDescending", @"Visits, high → low");
            break;
        case kPiwigoSortCategoryVisitsAscending:
            name = NSLocalizedString(@"categorySort_visitsAscending", @"Visits, low → high");
            break;
        case kPiwigoSortCategoryManual:
            name = NSLocalizedString(@"categorySort_manual", @"Manual Order");

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

@end
