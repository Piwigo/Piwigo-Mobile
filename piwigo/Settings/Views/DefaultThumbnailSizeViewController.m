//
//  DeafultThumbnailSizeViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/06/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "DefaultThumbnailSizeViewController.h"
#import "PiwigoImageData.h"
#import "Model.h"

@interface DefaultThumbnailSizeViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DefaultThumbnailSizeViewController

-(instancetype)init
{
    self = [super init];
    
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    self.title = NSLocalizedString(@"defaultThumbnailSizeTitle", @"Default Size");
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
    
    return self;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
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
    
    // Tab bar appearance
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];

    // Table view
    self.tableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.tableView reloadData];
}


#pragma mark - UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header = NSLocalizedString(@"defaultThumbnailSizeHeader", @"Please Select a Thumbnail Size");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
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
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"defaultThumbnailSizeHeader", @"Please Select a Thumbnail Size");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;

    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];

    // Header view
    UIView *header = [[UIView alloc] initWithFrame:headerRect];
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

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return kPiwigoImageSizeEnumCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(!cell) {
        cell = [UITableViewCell new];
    }
    
    // Name of the thumbnail size
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.text = [PiwigoImageData nameForThumbnailSizeType:(kPiwigoImageSize)indexPath.row];
    
    // Add checkmark in front of selected item
    if([Model sharedInstance].defaultThumbnailSize == indexPath.row) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // Disable unavailable sizes and full resolution
    switch (indexPath.row) {
        case kPiwigoImageSizeSquare:
            if ([Model sharedInstance].hasSquareSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeThumb:
            if ([Model sharedInstance].hasThumbSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if ([Model sharedInstance].hasXXSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXSmall:
            if ([Model sharedInstance].hasXSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeSmall:
            if ([Model sharedInstance].hasSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeMedium:
            if ([Model sharedInstance].hasMediumSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasXLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXXLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            if (![Model sharedInstance].hasXXLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeFullRes:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoRightLabelColor];
            break;
            
        default:
            break;
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // Footer height?
    NSString *footer = NSLocalizedString(@"defaultSizeFooter", @"Greyed sizes are not advised or not available on Piwigo server.");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:nil];

    return ceil(footerRect.size.height + 4.0 + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // Footer label
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontNormal];
    footerLabel.textColor = [UIColor piwigoHeaderColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.text = NSLocalizedString(@"defaultSizeFooter", @"Greyed sizes are not advised or not available on Piwigo server.");
    footerLabel.adjustsFontSizeToFitWidth = NO;
    footerLabel.lineBreakMode = NSLineBreakByWordWrapping;

    // Footer height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect footerRect = [footerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];

    // Footer view
    UIView *footer = [[UIView alloc] initWithFrame:footerRect];
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

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [Model sharedInstance].defaultThumbnailSize = (kPiwigoImageSize)indexPath.row;
    [[Model sharedInstance] saveToDisk];
    [self.tableView reloadData];
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
