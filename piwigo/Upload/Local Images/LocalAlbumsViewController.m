//
//  LocalAlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "LocalAlbumsViewController.h"
#import "CategoryTableViewCell.h"
#import "Model.h"
#import "PhotosFetch.h"
#import "UploadViewController.h"

@interface LocalAlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *localAlbumsTableView;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *localGroups;
@property (nonatomic, strong) NSArray *iCloudGroups;

@end

@implementation LocalAlbumsViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
    self = [super init];
    if(self)
    {
        self.categoryId = categoryId;
        
        self.title = NSLocalizedString(@"localAlbums", @"Local Albums");
        
        self.localGroups = [NSArray new];
        self.iCloudGroups = [NSArray new];
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
        
        self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.localAlbumsTableView.backgroundColor = [UIColor clearColor];
        self.localAlbumsTableView.delegate = self;
        self.localAlbumsTableView.dataSource = self;
        [self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
        [self.view addSubview:self.localAlbumsTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
        
    }
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

    // Table view
    self.localAlbumsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.localAlbumsTableView reloadData];
}


#pragma mark UITableView Methods

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1 + (self.iCloudGroups.count != 0);
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header;
    switch (section) {
        case 0:
            header = NSLocalizedString(@"categoryUpload_chooseLocalAlbum", @"Select an album to get images from");
            break;
        case 1:
            header = NSLocalizedString(@"categoryUpload_chooseiCloudAlbum", @"Select an iCloud album to get images from");
            break;

        default:
            break;
    }
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
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    switch (section) {
        case 0:
            headerLabel.text = NSLocalizedString(@"categoryUpload_chooseLocalAlbum", @"Select an album to get images from");
            break;
        case 1:
            headerLabel.text = NSLocalizedString(@"categoryUpload_chooseiCloudAlbum", @"Select an iCloud album to get images from");
            break;
            
        default:
            break;
    }

    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];
    
    // Header view
    UIView *header = [[UIView alloc] initWithFrame:headerRect];
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
    CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
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
    [cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@ %@)", name, @(nberAssets), (nberAssets > 1) ?NSLocalizedString(@"severalImages", @"Images") : NSLocalizedString(@"singleImage", @"Image")]];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UploadViewController *uploadVC;
    switch (indexPath.section) {
        case 0:
            uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId andGroupAsset:[self.localGroups objectAtIndex:indexPath.row]];
            break;
        case 1:
            uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId andGroupAsset:[self.iCloudGroups objectAtIndex:indexPath.row]];
            break;
    }
    [self.navigationController pushViewController:uploadVC animated:YES];
    
}

@end

