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
    
    self.view.backgroundColor = [UIColor piwigoGray];
    self.title = NSLocalizedString(@"defaultThumbnailSizeTitle", @"Default Size");
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor piwigoGray];
    [self.view addSubview:self.tableView];
    [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
    
    return self;
}

#pragma mark - UITableView Methods

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
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"defaultThumbnailSizeHeader", @"Please Select a Thumbnail Size");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
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
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoGray];
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
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeThumb:
            if ([Model sharedInstance].hasThumbSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if ([Model sharedInstance].hasXXSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXSmall:
            if ([Model sharedInstance].hasXSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeSmall:
            if ([Model sharedInstance].hasSmallSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeMedium:
            if ([Model sharedInstance].hasMediumSizeImages) {
                cell.userInteractionEnabled = YES;
            } else {
                cell.userInteractionEnabled = NO;
                cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
            if (![Model sharedInstance].hasLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
            if (![Model sharedInstance].hasXLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeXXLarge:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
            if (![Model sharedInstance].hasXXLargeSizeImages) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:NSLocalizedString(@"defaultSize_disabled", @" (disabled on server)")];
            }
            break;
        case kPiwigoImageSizeFullRes:
            cell.userInteractionEnabled = NO;
            cell.textLabel.textColor = [UIColor piwigoGrayUltraLight];
            break;
            
        default:
            break;
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 100.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 100)];
    
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontNormal];
    footerLabel.textColor = [UIColor piwigoOrange];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.text = NSLocalizedString(@"defaultSizeFooter", @"Greyed sizes are not advised or not available on Piwigo server.");
    footerLabel.adjustsFontSizeToFitWidth = NO;
    footerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [footer addSubview:footerLabel];
    [footer addConstraint:[NSLayoutConstraint constraintViewFromTop:footerLabel amount:10]];
    [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[footer]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"footer" : footerLabel}]];
    
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
