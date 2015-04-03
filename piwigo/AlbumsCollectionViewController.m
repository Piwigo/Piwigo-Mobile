//
//  AlbumsCollectionViewController.m
//  piwigo
//
//  Created by Olaf Greck on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumsCollectionViewController.h"

#import "AlbumCollectionViewCell.h"
#import "AlbumImagesViewController.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "CategoryPickViewController.h"
#import "Model.h"
#import "PiwigoImageData.h"
#import "SettingsViewController.h"


@interface AlbumsCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UIBarButtonItem *uploadButton;
@property (nonatomic, strong) UIBarButtonItem *addButton;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation AlbumsCollectionViewController

+(NSString *)nibName {
    return @"AlbumsCollectionView";
}

-(instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
    if (self = [super initWithCollectionViewLayout:layout]) {
        _categories = [NSArray new];
    }
    return self;
}


-(void)categoryDataUpdated {
    if([Model sharedInstance].hasAdminRights)
    {
        if (nil == self.addButton) {
            _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCategory)];
        }
        self.navigationItem.rightBarButtonItems = @[self.addButton, self.uploadButton];
    } else {
        self.navigationItem.rightBarButtonItem = self.uploadButton;
    }
    self.categories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:0];
    [self.collectionView reloadData];
}

-(void)viewDidLoad {
    [super viewDidLoad];
//self.navigationItem.title = @"hello";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
    
    [AlbumService getAlbumListForCategory:0
                             OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
                                 
                             } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                 
                                 MyLog(@"Album list err: %@", error);
                             }];

    self.view.backgroundColor           = [UIColor piwigoGray];
    
    self.collectionView.indicatorStyle  = UIScrollViewIndicatorStyleWhite;
    self.collectionView.backgroundColor = [UIColor piwigoGray];
    [self.collectionView registerClass:[AlbumCollectionViewCell class] forCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier]];

    self.navigationItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoOrange];
    self.navigationController.navigationBar.alpha           = 0.7f;
    self.navigationController.navigationBar.translucent     = YES;
    self.navigationController.navigationBar.tintColor       = [UIColor piwigoWhiteCream];

    UIBarButtonItem *prefsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"preferences"]
                                                                    style:UIBarButtonItemStylePlain target:self
                                                                   action:@selector(prefsSelected)];
    _uploadButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(uploadSelected)];
    self.navigationItem.leftBarButtonItem = prefsButton;
    self.navigationItem.rightBarButtonItem = self.uploadButton;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.backgroundColor = [UIColor piwigoOrange];
    refreshControl.tintColor = [UIColor piwigoGray];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:refreshControl];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    [AlbumService getAlbumListForCategory:0
                             OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
                                 [refreshControl endRefreshing];
                             } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                 [refreshControl endRefreshing];
                             }];
}

#pragma mark - Buttons -
-(void)addCategory
{
    [UIAlertView showWithTitle:NSLocalizedString(@"createNewAlbum_title", @"Create New Album")
                       message:NSLocalizedString(@"createNewAlbum_message", @"Album name")
                         style:UIAlertViewStylePlainTextInput
             cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
             otherButtonTitles:@[NSLocalizedString(@"alertAddButton", @"Add")]
                      tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                          if(buttonIndex == 1)
                          {
                              [AlbumService createCategoryWithName:[alertView textFieldAtIndex:0].text
                                                      OnCompletion:^(AFHTTPRequestOperation *operation, BOOL createdSuccessfully) {
                                                          if(createdSuccessfully)
                                                          {
                                                              [AlbumService getAlbumListForCategory:0
                                                                                       OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
                                                                                           [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:self.categories.count - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:YES];
                                                                                       } onFailure:nil];
                                                          }
                                                          else
                                                          {
                                                              [self showCreateCategoryError];
                                                          }
                                                      } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                          
                                                          [self showCreateCategoryError];
                                                      }];
                          }
                      }];
}

-(void)showCreateCategoryError
{
    [UIAlertView showWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error")
                       message:NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album")
             cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
             otherButtonTitles:nil
                      tapBlock:nil];
}

-(void)uploadSelected {
    CategoryPickViewController *uploadVC = [CategoryPickViewController new];
    [self.navigationController pushViewController:uploadVC animated:YES];
}

-(void)prefsSelected {
    SettingsViewController *settingsVC = [SettingsViewController new];
    [self.navigationController pushViewController:settingsVC animated:YES];
}

#pragma mark - UICollectionView Datasource -
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    if(self.categories.count <= 0) {
        self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        
        self.emptyLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"There appears to be no albums in your Piwigo. You may pull down to refresh");
        self.emptyLabel.textColor = [UIColor piwigoWhiteCream];
        self.emptyLabel.numberOfLines = 0;
        self.emptyLabel.textAlignment = NSTextAlignmentCenter;
        self.emptyLabel.font = [UIFont piwigoFontNormal];
        [self.emptyLabel sizeToFit];
        
        self.collectionView.backgroundView = self.emptyLabel;
        return 0;
    } else {
        self.emptyLabel.hidden = YES;
        return 1;
    }
}
-(NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {

    if(self.categories.count <= 0)
    {
        self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
        
        self.emptyLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"There appears to be no albums in your Piwigo. You may pull down to refresh");
        self.emptyLabel.textColor = [UIColor piwigoWhiteCream];
        self.emptyLabel.numberOfLines = 0;
        self.emptyLabel.textAlignment = NSTextAlignmentCenter;
        self.emptyLabel.font = [UIFont piwigoFontNormal];
        [self.emptyLabel sizeToFit];
        
        self.collectionView.backgroundView = self.emptyLabel;
    }
    else if(self.emptyLabel)
    {
        self.emptyLabel.hidden = YES;
    }
    return self.categories.count;}

-(UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AlbumCollectionViewCell *cell = [cv dequeueReusableCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];
#warning    cell.cellDelegate = self;
    
    PiwigoAlbumData *albumData = [self.categories objectAtIndex:indexPath.row];
    [cell setupWithAlbumData:albumData];

    cell.backgroundColor = [UIColor whiteColor];
    return cell;
}

#pragma mark - UICollectionViewDelegate
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PiwigoAlbumData *albumData = [self.categories objectAtIndex:indexPath.row];
    
    AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumId:albumData.albumId];
    [self.navigationController pushViewController:album animated:YES];
}

-(void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    // TODO: Deselect item
}

-(UICollectionViewController *)nextViewControllerAtPoint:(CGPoint)p
{
    return nil; // subclass must override this method
}


#pragma mark – UICollectionViewDelegateFlowLayout

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize returnSize   = CGSizeMake(260, 180);
    returnSize.height   += 35;
    returnSize.width    += 35;
#warning TODO consider border for retina iPad
    return returnSize;
}

-(UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(10, 10, 40, 10);
}


@end
