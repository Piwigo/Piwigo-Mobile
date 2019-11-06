//
//  ShareMetadataViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "LabelImageTableViewCell.h"
#import "ShareMetadataViewController.h"

@interface ShareMetadataViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *privacyTableView;
@property (nonatomic, strong) NSArray *activitiesSharingMetadata;
@property (nonatomic, strong) NSArray *activitiesNotSharingMetadata;
@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation ShareMetadataViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.title = NSLocalizedString(@"settingsHeader_images", @"Images");
        
        // Table
        self.privacyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.privacyTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.privacyTableView.backgroundColor = [UIColor clearColor];
        self.privacyTableView.alwaysBounceVertical = YES;
        self.privacyTableView.showsVerticalScrollIndicator = YES;
        self.privacyTableView.delegate = self;
        self.privacyTableView.dataSource = self;
        [self.privacyTableView registerNib:[UINib nibWithNibName:@"LabelImageTableViewCell" bundle:nil] forCellReuseIdentifier:@"LabelImageTableViewCell"];
        [self.view addSubview:self.privacyTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.privacyTableView]];
        
        // Buttons
        self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(stopEditingOptions)];
        
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

    // Navigation bar appearence
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
    self.privacyTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.privacyTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.privacyTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Add Edit button
    [self.navigationItem setRightBarButtonItem:self.editBarButton animated:NO];

    // Prepare data source
    NSMutableArray *activitiesSharingMetadata = [NSMutableArray new];
    NSMutableArray *activitiesNotSharingMetadata = [NSMutableArray new];
    
    // Activity types
    if ([Model sharedInstance].shareMetadataTypeAirDrop) {
        [activitiesSharingMetadata addObject:UIActivityTypeAirDrop];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeAirDrop];
    }
    if ([Model sharedInstance].shareMetadataTypeAssignToContact) {
        [activitiesSharingMetadata addObject:UIActivityTypeAssignToContact];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeAssignToContact];
    }
    if ([Model sharedInstance].shareMetadataTypeCopyToPasteboard) {
        [activitiesSharingMetadata addObject:UIActivityTypeCopyToPasteboard];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeCopyToPasteboard];
    }
    if ([Model sharedInstance].shareMetadataTypeMail) {
        [activitiesSharingMetadata addObject:UIActivityTypeMail];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeMail];
    }
    if ([Model sharedInstance].shareMetadataTypeMessage) {
        [activitiesSharingMetadata addObject:UIActivityTypeMessage];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeMessage];
    }
    if ([Model sharedInstance].shareMetadataTypePostToFacebook) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToFacebook];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToFacebook];
    }
    if ([Model sharedInstance].shareMetadataTypeMessenger) {
        [activitiesSharingMetadata addObject:kPiwigoActivityTypeMessenger];
    } else {
        [activitiesNotSharingMetadata addObject:kPiwigoActivityTypeMessenger];
    }
    if ([Model sharedInstance].shareMetadataTypePostToFlickr) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToFlickr];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToFlickr];
    }
    if ([Model sharedInstance].shareMetadataTypePostInstagram) {
        [activitiesSharingMetadata addObject:kPiwigoActivityTypePostInstagram];
    } else {
        [activitiesNotSharingMetadata addObject:kPiwigoActivityTypePostInstagram];
    }
    if ([Model sharedInstance].shareMetadataTypePostToSignal) {
        [activitiesSharingMetadata addObject:kPiwigoActivityTypePostToSignal];
    } else {
        [activitiesNotSharingMetadata addObject:kPiwigoActivityTypePostToSignal];
    }
    if ([Model sharedInstance].shareMetadataTypePostToSnapchat) {
        [activitiesSharingMetadata addObject:kPiwigoActivityTypePostToSnapchat];
    } else {
        [activitiesNotSharingMetadata addObject:kPiwigoActivityTypePostToSnapchat];
    }
    if ([Model sharedInstance].shareMetadataTypePostToTencentWeibo) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToTencentWeibo];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToTencentWeibo];
    }
    if ([Model sharedInstance].shareMetadataTypePostToTwitter) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToTwitter];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToTwitter];
    }
    if ([Model sharedInstance].shareMetadataTypePostToVimeo) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToVimeo];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToVimeo];
    }
    if ([Model sharedInstance].shareMetadataTypePostToWeibo) {
        [activitiesSharingMetadata addObject:UIActivityTypePostToWeibo];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypePostToWeibo];
    }
    if ([Model sharedInstance].shareMetadataTypePostToWhatsApp) {
     [activitiesSharingMetadata addObject:kPiwigoActivityTypePostToWhatsApp];
    } else {
     [activitiesNotSharingMetadata addObject:kPiwigoActivityTypePostToWhatsApp];
    }
    if ([Model sharedInstance].shareMetadataTypeSaveToCameraRoll) {
        [activitiesSharingMetadata addObject:UIActivityTypeSaveToCameraRoll];
    } else {
        [activitiesNotSharingMetadata addObject:UIActivityTypeSaveToCameraRoll];
    }
    if ([Model sharedInstance].shareMetadataTypeOther) {
        [activitiesSharingMetadata addObject:kPiwigoActivityTypeOther];
    } else {
        [activitiesNotSharingMetadata addObject:kPiwigoActivityTypeOther];
    }

    self.activitiesSharingMetadata = [[NSArray alloc] initWithArray:[[self sortActivities:activitiesSharingMetadata] copy]];
    self.activitiesNotSharingMetadata = [[NSArray alloc] initWithArray:[[self sortActivities:activitiesNotSharingMetadata] copy]];

    // Release memory
    activitiesSharingMetadata = nil;
    activitiesNotSharingMetadata = nil;
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                
        // Reload table view
        [self.privacyTableView reloadData];
    } completion:nil];
}


#pragma mark - Editing mode

-(void)stopEditingOptions
{
    // Replace "Done" button with "Edit" button
    [self.navigationItem setRightBarButtonItem:self.editBarButton animated:YES];
    
    // Refresh table to remove [+] and [-] buttons
    [self.privacyTableView reloadData];

    // Show back button
    [self.navigationItem setHidesBackButton:NO animated:YES];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    CGFloat heightForHeader = 0.0;
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;

    switch (section) {
        case 0:
        {
            // Title
            NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"shareImageMetadata_Title", @"Share Metadata")];
            NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
            CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:titleAttributes
                                                         context:context];
            
            // Text
            NSString *textString = NSLocalizedString(@"shareImageMetadata_subTitle1", @"Actions sharing images with private metadata");
            NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
            CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:textAttributes
                                                       context:context];

            heightForHeader = fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
            break;
        }
        case 1:
        {
            // Text
            NSString *textString = NSLocalizedString(@"shareImageMetadata_subTitle2", @"Actions sharing images without private metadata");
            NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
            CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:textAttributes
                                                       context:context];
            heightForHeader = fmax(44.0, ceil(textRect.size.height));
            break;
        }
        default:
            break;
    }
    return heightForHeader;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];

    switch (section) {
        case 0:
        {
            // Title
            NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"shareImageMetadata_Title", @"Share Metadata")];
            NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
            [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                          range:NSMakeRange(0, [titleString length])];
            [headerAttributedString appendAttributedString:titleAttributedString];

            // Text
            NSString *textString = NSLocalizedString(@"shareImageMetadata_subTitle1", @"Actions sharing images with private metadata");
            NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
            [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                         range:NSMakeRange(0, [textString length])];
            [headerAttributedString appendAttributedString:textAttributedString];
            break;
        }
        case 1:
        {
            // Text
            NSString *textString = NSLocalizedString(@"shareImageMetadata_subTitle2", @"Actions sharing images without private metadata");
            NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
            [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                         range:NSMakeRange(0, [textString length])];
            [headerAttributedString appendAttributedString:textAttributedString];
            break;
        }
            
        default:
            break;
    }

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

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger nberOfRows = 0;
    switch (section) {
        case 0:
            nberOfRows = [self.activitiesSharingMetadata count];
            break;
            
        case 1:
            nberOfRows = [self.activitiesNotSharingMetadata count];
            break;
            
        default:
            break;
    }
    return nberOfRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LabelImageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LabelImageTableViewCell" forIndexPath:indexPath];
    if(!cell) {
        cell = [LabelImageTableViewCell new];
    }

    CGFloat width = self.view.bounds.size.width;
    switch (indexPath.section) {
        case 0:
        {
            NSString *activity = [self.activitiesSharingMetadata objectAtIndex:indexPath.row];
            NSString *name = [[Model sharedInstance] getNameForShareActivity:activity forWidth:width];
            [cell setupWithActivityName:name andEditOption:kPiwigoActionCellEditRemove];
            break;
        }
        case 1:
        {
            NSString *activity = [self.activitiesNotSharingMetadata objectAtIndex:indexPath.row];
            NSString *name = [[Model sharedInstance] getNameForShareActivity:activity forWidth:width];
            [cell setupWithActivityName:name andEditOption:kPiwigoActionCellEditAdd];
            break;
        }
        default:
            break;
    }
    
    [cell setAccessibilityIdentifier:@"shareMetadata"];
    cell.isAccessibilityElement = YES;
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSMutableArray *activitiesSharingMetadata = [[NSMutableArray alloc] initWithArray:self.activitiesSharingMetadata];
    NSMutableArray *activitiesNotSharingMetadata = [[NSMutableArray alloc] initWithArray:self.activitiesNotSharingMetadata];

    NSString *activity = nil;
    NSIndexPath *newIndexPath = [NSIndexPath new];
    switch (indexPath.section) {
        case 0:
            activity = [self.activitiesSharingMetadata objectAtIndex:indexPath.row];
            [self switchActivity:activity toState:NO];
            [activitiesSharingMetadata removeObjectIdenticalTo:activity];
            [activitiesNotSharingMetadata addObject:activity];
            break;
            
        case 1:
            activity = [self.activitiesNotSharingMetadata objectAtIndex:indexPath.row];
            [self switchActivity:activity toState:YES];
            [activitiesSharingMetadata addObject:activity];
            [activitiesNotSharingMetadata removeObjectIdenticalTo:activity];
            break;
            
        default:
            break;
    }
    
    // Sort lists of activities
    self.activitiesSharingMetadata = [[self sortActivities:activitiesSharingMetadata] copy];
    self.activitiesNotSharingMetadata = [[self sortActivities:activitiesNotSharingMetadata] copy];
    
    // Release memory
    activitiesSharingMetadata = nil;
    activitiesNotSharingMetadata = nil;

    // Get new indexPath of tapped activity
    switch (indexPath.section) {
        case 0:
            {
                NSUInteger index = [self.activitiesNotSharingMetadata indexOfObjectPassingTest:^BOOL(NSString *someActivity, NSUInteger idx, BOOL *stop) {
                    return ([someActivity isEqualToString:activity]);
                }];
                newIndexPath = [NSIndexPath indexPathForRow:index inSection:1];
                break;
            }
        case 1:
            {
                NSUInteger index = [self.activitiesSharingMetadata indexOfObjectPassingTest:^BOOL(NSString *someActivity, NSUInteger idx, BOOL *stop) {
                    return ([someActivity isEqualToString:activity]);
                }];
                newIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
                break;
            }

        default:
            break;
    }

    // Move cell of tapped activity
    [tableView moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];

    // Update cell icon
    LabelImageTableViewCell *cell = [tableView cellForRowAtIndexPath:newIndexPath];
    CGFloat width = self.view.bounds.size.width;
    NSString *name = [[Model sharedInstance] getNameForShareActivity:activity forWidth:width];
    switch (newIndexPath.section) {
        case 0:
            [cell setupWithActivityName:name andEditOption:kPiwigoActionCellEditRemove];
            break;
            
        case 1:
            [cell setupWithActivityName:name andEditOption:kPiwigoActionCellEditAdd];
            break;
            
        default:
            break;
    }
}

#pragma mark - Utilities

-(NSArray *)sortActivities:(NSArray *)listOfActivities
{
    // Sort lists of activities
    NSArray *sortedActivities = [listOfActivities
                        sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSString *obj1 = [[Model sharedInstance] getNameForShareActivity:a forWidth:INFINITY];
        NSString *obj2 = [[Model sharedInstance] getNameForShareActivity:b forWidth:INFINITY];
        return [obj1 compare:obj2] != NSOrderedAscending;
    }];
    
    return sortedActivities;
}

-(void)switchActivity:(NSString *)activity toState:(BOOL)newState
{
    if ([activity isEqualToString:UIActivityTypeAirDrop]) {
        [Model sharedInstance].shareMetadataTypeAirDrop = newState;
    }
    if ([activity isEqualToString:UIActivityTypeAssignToContact]) {
        [Model sharedInstance].shareMetadataTypeAssignToContact = newState;
    }
    if ([activity isEqualToString:UIActivityTypeCopyToPasteboard]) {
        [Model sharedInstance].shareMetadataTypeCopyToPasteboard = newState;
    }
    if ([activity isEqualToString:UIActivityTypeMail]) {
        [Model sharedInstance].shareMetadataTypeMail = newState;
    }
    if ([activity isEqualToString:UIActivityTypeMessage]) {
        [Model sharedInstance].shareMetadataTypeMessage = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToFacebook]) {
        [Model sharedInstance].shareMetadataTypePostToFacebook = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypeMessenger]) {
        [Model sharedInstance].shareMetadataTypeMessenger = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToFlickr]) {
        [Model sharedInstance].shareMetadataTypePostToFlickr = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypePostInstagram]) {
        [Model sharedInstance].shareMetadataTypePostInstagram = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypePostToSignal]) {
        [Model sharedInstance].shareMetadataTypePostToSignal = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypePostToSnapchat]) {
        [Model sharedInstance].shareMetadataTypePostToSnapchat = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToTencentWeibo]) {
        [Model sharedInstance].shareMetadataTypePostToTencentWeibo = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToTwitter]) {
        [Model sharedInstance].shareMetadataTypePostToTwitter = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToVimeo]) {
        [Model sharedInstance].shareMetadataTypePostToVimeo = newState;
    }
    if ([activity isEqualToString:UIActivityTypePostToWeibo]) {
        [Model sharedInstance].shareMetadataTypePostToWeibo = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypePostToWhatsApp]) {
        [Model sharedInstance].shareMetadataTypePostToWhatsApp = newState;
    }
    if ([activity isEqualToString:UIActivityTypeSaveToCameraRoll]) {
        [Model sharedInstance].shareMetadataTypeSaveToCameraRoll = newState;
    }
    if ([activity isEqualToString:kPiwigoActivityTypeOther]) {
        [Model sharedInstance].shareMetadataTypeOther = newState;
    }

    // Save modified settings
    [[Model sharedInstance] saveToDisk];
}

@end
