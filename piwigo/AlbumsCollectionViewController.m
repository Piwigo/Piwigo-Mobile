//
//  AlbumsCollectionViewController.m
//  piwigo
//
//  Created by Olaf Greck on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumsCollectionViewController.h"

#import "PiwigoImageData.h"
#import "AlbumCollectionViewCell.h"
#import "AlbumService.h"
#import "AlbumImagesViewController.h"
#import "CategoriesData.h"
#import "Model.h"

@interface AlbumsCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *albumsView;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation AlbumsCollectionViewController

#warning TODO: add upload and settings button
-(id)initWithCollectionViewLayout:(UICollectionViewFlowLayout *)layout {
    if (self = [super initWithCollectionViewLayout:layout]) {
        [self.collectionView registerClass:[AlbumCollectionViewCell class] forCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier]];
        self.view.backgroundColor           = [UIColor piwigoGray];
        self.collectionView.indicatorStyle  = UIScrollViewIndicatorStyleWhite;
        self.collectionView.backgroundColor = [UIColor piwigoGray];
        self.navigationItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");

        self.categories = [NSArray new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
        
        [AlbumService getAlbumListForCategory:0
                                 OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
                                     
                                 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     
                                     MyLog(@"Album list err: %@", error);
                                 }];

    }
    return self;
}

-(instancetype)initOFFxxxx
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoGray];
        self.categories = [NSArray new];
        
        self.albumsView = [UICollectionView new];
        self.albumsView.translatesAutoresizingMaskIntoConstraints = NO;
        self.albumsView.backgroundColor = [UIColor clearColor];
        self.albumsView.delegate = self;
        self.albumsView.dataSource = self;
        self.albumsView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        [self.albumsView registerClass:[AlbumCollectionViewCell class]
            forCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier]];
        [self.view addSubview:self.albumsView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.albumsView]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
        
        [AlbumService getAlbumListForCategory:0
                                 OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
                                     
                                 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     
                                     MyLog(@"Album list err: %@", error);
                                 }];
    }
    return self;
}

-(void)categoryDataUpdated
{
    self.categories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:0];
    [self.collectionView reloadData];
}

-(void)viewDidLoad {
    [super viewDidLoad];
    if([Model sharedInstance].hasAdminRights)
    {
        UIBarButtonItem *addCategory = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCategory)];
        self.navigationItem.rightBarButtonItem = addCategory;
    }
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

#pragma mark - UICollectionView Datasource
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    if(self.categories.count <= 0) {
        return 0;
    } else {
        //        PiwigoAlbumData *albumData = [self.categories objectAtIndex:section];
        return 1; //albumData.numberOfSubAlbumImages;
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
        
        self.albumsView.backgroundView = self.emptyLabel;
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
