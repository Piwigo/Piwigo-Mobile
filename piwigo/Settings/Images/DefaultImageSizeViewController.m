//
//  DefaultImageSizeViewController.m
//  piwigo
//
//  Created by Spencer Baker on 5/12/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "DefaultImageSizeViewController.h"
#import "PiwigoImageData.h"
#import "Model.h"

@interface DefaultImageSizeViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DefaultImageSizeViewController

-(instancetype)init
{
	self = [super init];
    if(self)
    {
        self.title = NSLocalizedString(@"settingsHeader_images", @"Images");
        
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        [self.view addSubview:self.tableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
        
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPaletteSettings) name:kPiwigoNotificationPaletteChanged object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)applyPaletteSettings
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    // Table view
    self.tableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyPaletteSettings];
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];
        if (hasUserInterfaceStyleChanged) {
            NSLog(@"AlbumImages => did change, previous was %@", previousTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? @"Dark" :  @"Light");
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate setColorPalette];
        }
    } else {
        // Fallback on earlier versions
    }
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"defaultPreviewFile>414px", @"Preview Image File")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    
    // Text
    NSString *textString = NSLocalizedString(@"defaultImageSizeHeader", @"Please select an image size");
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
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"defaultPreviewFile>414px", @"Preview Image File")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString = NSLocalizedString(@"defaultImageSizeHeader", @"Please select an image size");
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
	return kPiwigoImageSizeEnumCount;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell) {
		cell = [UITableViewCell new];
	}
    kPiwigoImageSize imageSize = (kPiwigoImageSize)indexPath.row;

    // Name of the image size
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    
    // Add checkmark in front of selected item
	if([Model sharedInstance].defaultImagePreviewSize == indexPath.row) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
    // Disable unavailable sizes
    switch (indexPath.row) {
        case kPiwigoImageSizeSquare:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasSquareSizeImages) {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            } else {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            }
            break;
        case kPiwigoImageSizeThumb:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasThumbSizeImages) {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            } else {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            }
            break;
        case kPiwigoImageSizeXXSmall:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasXXSmallSizeImages) {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            } else {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            }
            break;
        case kPiwigoImageSizeXSmall:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasXSmallSizeImages) {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            } else {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            }
            break;
        case kPiwigoImageSizeSmall:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasSmallSizeImages) {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            } else {
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            }
            break;
        case kPiwigoImageSizeMedium:
            if ([Model sharedInstance].hasMediumSizeImages) {
                cell.userInteractionEnabled = YES;
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeLarge:
            if ([Model sharedInstance].hasLargeSizeImages) {
                cell.userInteractionEnabled = YES;
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXLarge:
            if ([Model sharedInstance].hasXLargeSizeImages) {
                cell.userInteractionEnabled = YES;
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if ([Model sharedInstance].hasXXLargeSizeImages) {
                cell.userInteractionEnabled = YES;
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:NO];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeFullRes:
            cell.userInteractionEnabled = YES;
            cell.textLabel.text = [PiwigoImageData nameForImageSizeType:imageSize withInfo:YES];
            break;
            
        default:
            break;
    }
    
	return cell;
}


#pragma mark - UITableView - Footer

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // Footer height?
    NSString *footer = NSLocalizedString(@"defaultSizeFooter", @"Greyed sizes are not advised or not available on Piwigo server.");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    
    return fmax(44.0, ceil(footerRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // Footer label
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontSmall];
    footerLabel.textColor = [UIColor piwigoHeaderColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.text = NSLocalizedString(@"defaultSizeFooter", @"Greyed sizes are not advised or not available on Piwigo server.");
    footerLabel.adjustsFontSizeToFitWidth = NO;
    footerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Footer view
    UIView *footer = [[UIView alloc] init];
    footer.backgroundColor = [UIColor clearColor];
    [footer addSubview:footerLabel];
    [footer addConstraint:[NSLayoutConstraint constraintViewFromTop:footerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[footer]-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"footer" : footerLabel}]];
    } else {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[footer]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    }
    
    return footer;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	[Model sharedInstance].defaultImagePreviewSize = (kPiwigoImageSize)indexPath.row;
	[[Model sharedInstance] saveToDisk];
	[self.tableView reloadData];
	
	[self.navigationController popViewControllerAnimated:YES];
}

@end
