//
//  LocalAlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "AppDelegate.h"
#import "CategoryTableViewCell.h"
#import "CameraRollUploadViewController.h"
#import "LocalAlbumsViewController.h"
#import "Model.h"
#import "PhotosFetch.h"
#import "AlbumUploadViewController.h"

@interface LocalAlbumsViewController () <UITableViewDelegate, UITableViewDataSource, PHPhotoLibraryChangeObserver>

@property (nonatomic, strong) UITableView *localAlbumsTableView;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *localGroups;
@property (nonatomic, strong) NSArray *iCloudGroups;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation LocalAlbumsViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
    self = [super init];
    if(self)
    {
        self.categoryId = categoryId;
        
        // Get groups of Photos library albums
        self.localGroups = [NSArray new];
        self.iCloudGroups = [NSArray new];
        [self getLocalAlbums];
        
        // Table view
        self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.localAlbumsTableView.backgroundColor = [UIColor clearColor];
        self.localAlbumsTableView.delegate = self;
        self.localAlbumsTableView.dataSource = self;
        [self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"CategoryTableViewCell"];
        [self.view addSubview:self.localAlbumsTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
        
        // Button for returning to albums/images
        self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(quitUpload)];
        [self.doneBarButton setAccessibilityIdentifier:@"Cancel"];
        
        // Register Photo Library changes
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPaletteSettings) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}

-(void)getLocalAlbums
{
    [[PhotosFetch sharedInstance] getLocalGroupsOnCompletion:^(id responseObject1, id responseObject2) {
        if([responseObject1 isKindOfClass:[NSNumber class]])
        {    // make view disappear
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
        else if(responseObject1 == nil)
        {
            UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNiltitle", @"Problem Reading Photos")
                message:NSLocalizedString(@"localAlbums_photosNnil_msg", @"There is a problem reading your local photo library.")
                preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* dismissAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {
                    // make view disappear
                    [self.navigationController popViewControllerAnimated:YES];
                }];
            
            [alert addAction:dismissAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
        else
        {
            self.localGroups = responseObject1;
            self.iCloudGroups = responseObject2;
            [self.localAlbumsTableView reloadData];
        }
    }];
}


#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Navigation bar
    [self.navigationController.navigationBar setAccessibilityIdentifier:@"LocalAlbumsNav"];
}

-(void)applyPaletteSettings
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }

    // Navigation bar
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }

    // Table view
    self.localAlbumsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.localAlbumsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Title
    self.title = NSLocalizedString(@"localAlbums", @"Photos library");

    // Set colors, fonts, etc.
    [self applyPaletteSettings];
    
    // Navigation bar button
    [self.navigationItem setRightBarButtonItems:@[self.doneBarButton] animated:YES];
}


-(void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    // User may have switched to Light or Dark Mode
    if (@available(iOS 13.0, *)) {
        BOOL isDarkMode = (newCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate setColorSettingsWithiOSInDarkMode:isDarkMode];
    } else {
        // Fallback on earlier versions
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show title in backButtonItem of child view to provide enough space for title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }
}

-(void)quitUpload
{
    // Leave Upload action and return to Albums and Images
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header strings
    NSString *titleString = @"", *textString = @"";
    switch (section) {
        case 0:
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categoryUpload_LocalAlbums", @"Local Albums")];
            textString = NSLocalizedString(@"categoryUpload_chooseLocalAlbum", @"Select an album to get images from");
            break;
        case 1:
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categoryUpload_iCloudAlbums", @"iCloud Albums")];
            textString = NSLocalizedString(@"categoryUpload_chooseiCloudAlbum", @"Select an iCloud album to get images from");
            break;

        default:
            break;
    }
    
    // Header height
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];

    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header strings
    NSString *titleString = @"", *textString = @"";
    switch (section) {
        case 0:
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categoryUpload_LocalAlbums", @"Local Albums")];
            textString = NSLocalizedString(@"categoryUpload_chooseLocalAlbum", @"Select an album to get images from");
            break;
        case 1:
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categoryUpload_iCloudAlbums", @"iCloud Albums")];
            textString = NSLocalizedString(@"categoryUpload_chooseiCloudAlbum", @"Select an iCloud album to get images from");
            break;
            
        default:
            break;
    }
    
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
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

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    view.layer.zPosition = 0;
}


#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1 + (self.iCloudGroups.count != 0);
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger nberRows = 0;
    switch (section) {
        case 0:
            nberRows = self.localGroups.count;
            break;
        case 1:
            nberRows = self.iCloudGroups.count;
            break;
    }
    return nberRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryTableViewCell" forIndexPath:indexPath];
    
    PHAssetCollection *groupAsset;
    switch (indexPath.section) {
        case 0:
            groupAsset = [self.localGroups objectAtIndex:indexPath.row];
            break;
        case 1:
            groupAsset = [self.iCloudGroups objectAtIndex:indexPath.row];
            break;
    }
    NSString *name = [groupAsset localizedTitle];
    NSUInteger nberAssets = [[PHAsset fetchAssetsInAssetCollection:groupAsset options:nil] count];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@ %@)", name, @(nberAssets), (nberAssets > 1) ? NSLocalizedString(@"severalImages", @"Images") : NSLocalizedString(@"singleImage", @"Image")];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.tintColor = [UIColor piwigoOrange];
    cell.translatesAutoresizingMaskIntoConstraints = NO;
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.minimumScaleFactor = 0.5;
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    if (([groupAsset assetCollectionType] == PHAssetCollectionTypeSmartAlbum) &&
        ([groupAsset assetCollectionSubtype] == PHAssetCollectionSubtypeSmartAlbumUserLibrary)) {
        [cell setAccessibilityIdentifier:@"CameraRoll"];
    }

    cell.isAccessibilityElement = YES;
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case 0:
        {
            PHAssetCollection *groupAsset = [self.localGroups objectAtIndex:indexPath.row];
            if ((groupAsset.assetCollectionType == PHAssetCollectionTypeSmartAlbum) &&
                (groupAsset.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary))
            {
                CameraRollUploadViewController *uploadVC = [[CameraRollUploadViewController alloc] initWithCategoryId:self.categoryId];
                [self.navigationController pushViewController:uploadVC animated:YES];
           }
            else {
                AlbumUploadViewController *uploadVC = [[AlbumUploadViewController alloc] initWithCategoryId:self.categoryId andCollection:[self.localGroups objectAtIndex:indexPath.row]];
                [self.navigationController pushViewController:uploadVC animated:YES];
            }
            break;
        }
        case 1:
        {
            AlbumUploadViewController *uploadVC = [[AlbumUploadViewController alloc] initWithCategoryId:self.categoryId andCollection:[self.iCloudGroups objectAtIndex:indexPath.row]];
            [self.navigationController pushViewController:uploadVC animated:YES];
            break;
        }
    }
}


#pragma mark - Changes occured in the Photo library

- (void)photoLibraryDidChange:(PHChange *)changeInfo {
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Collect new list of albums
        [self getLocalAlbums];
        
        // Refresh list
        [self.localAlbumsTableView reloadData];
    });
}

@end

