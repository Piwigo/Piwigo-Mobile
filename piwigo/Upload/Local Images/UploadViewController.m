//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "UploadViewController.h"
#import "ImageUploadManager.h"
#import "PhotosFetch.h"
#import "LocalImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "CategoriesData.h"
#import "ImageUpload.h"
#import "ImageUploadProgressView.h"
#import "ImageUploadViewController.h"
#import "SortHeaderCollectionReusableView.h"
#import "SortSelectViewController.h"
#import "NoImagesHeaderCollectionReusableView.h"
#import "LoadingView.h"
#import "UICountingLabel.h"
#import "ImagesCollection.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ImageUploadProgressDelegate, SortSelectViewControllerDelegate, PHPhotoLibraryChangeObserver>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) PHAssetCollection *groupAsset;

@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, strong) UIBarButtonItem *doneBarButton;
//@property (nonatomic, strong) UIBarButtonItem *selectAllBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, strong) NSMutableArray *selectedImages;

@property (nonatomic, assign) kPiwigoSortBy sortType;
@property (nonatomic, strong) LoadingView *loadingView;

@end

@implementation UploadViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andGroupAsset:(PHAssetCollection*)groupAsset
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
        self.categoryId = categoryId;
        self.groupAsset = groupAsset;
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
        self.sortType = kPiwigoSortByNewest;
        
        // Collection of images
        self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.localImagesCollection.backgroundColor = [UIColor clearColor];
        self.localImagesCollection.alwaysBounceVertical = YES;
        self.localImagesCollection.showsVerticalScrollIndicator = YES;
        self.localImagesCollection.dataSource = self;
        self.localImagesCollection.delegate = self;

        [self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
        [self.localImagesCollection registerClass:[SortHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"sortHeader"];
        [self.localImagesCollection registerClass:[NoImagesHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"noImagesHeader"];

        [self.view addSubview:self.localImagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];

        // Selected images
        self.selectedImages = [NSMutableArray new];
        
        // Bar buttons
//        self.selectAllBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"selectAll", @"All") style:UIBarButtonItemStylePlain target:self action:@selector(selectAll)];
        self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitUpload)];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"] style:UIBarButtonItemStylePlain target:self action:@selector(uploadSelected)];
        
        // Register Photo Library changes
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
    return self;
}

#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
    {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    self.localImagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;

    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    [self loadNavButtons];
    
    // Progress bar
    [ImageUploadProgressView sharedInstance].delegate = self;
    [[ImageUploadProgressView sharedInstance] changePaletteMode];
    
    if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
    {
        [[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.localImagesCollection reloadData];
        [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
    } completion:nil];
}

-(void)quitUpload
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)loadNavButtons
{
    switch (self.selectedImages.count) {
        case 0:
            self.navigationItem.leftBarButtonItems = @[];
            self.navigationItem.rightBarButtonItems = @[self.doneBarButton];
            self.title = NSLocalizedString(@"selectImages", @"Select Images");
            break;
            
        case 1:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            self.title = NSLocalizedString(@"selectImageSelected", @"1 Image Selected");
            break;
            
        default:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Images Selected"), @(self.selectedImages.count)];
            break;
    }
}


#pragma mark - Select Images

//-(void)selectAll
//{
//    self.selectedImages = [self.images mutableCopy];
//    [self loadNavButtons];
//    [self.localImagesCollection reloadData];
//}

-(void)cancelSelect
{
    // Deselect the cells
    for(PHAsset *selectedImageAsset in self.selectedImages)
    {
        NSInteger row = [self.images indexOfObject:selectedImageAsset];
        if(row != NSNotFound)
        {
            LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
            cell.cellSelected = NO;
        }
    }
    
    // Clear the list of selected images
    self.selectedImages = [NSMutableArray new];
    
    // Update the navigation bar
    [self loadNavButtons];
}

-(void)uploadSelected
{
    [self showImageUpload];
}

-(void)showImageUpload
{
    ImageUploadViewController *vc = [ImageUploadViewController new];
    vc.selectedCategory = self.categoryId;
    vc.imagesSelected = self.selectedImages;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.navigationController presentViewController:nav animated:YES completion:nil];
    self.selectedImages = [NSMutableArray new];
}


#pragma mark - UICollectionView - Header for changing sort option

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (self.images.count != 0) {
        // Display "Sort By…" header
        SortHeaderCollectionReusableView *header = nil;
        
        if(kind == UICollectionElementKindSectionHeader)
        {
            header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"sortHeader" forIndexPath:indexPath];
            header.backgroundColor = [UIColor piwigoCellBackgroundColor];
            header.sortLabel.textColor = [UIColor piwigoLeftLabelColor];
            header.currentSortLabel.text = [SortSelectViewController getNameForSortType:self.sortType];
            header.currentSortLabel.textColor = [UIColor piwigoRightLabelColor];
            [header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSelectCollectionViewHeader)]];
            
            return header;
        }
    } else {
        // Display "No Images"
        NoImagesHeaderCollectionReusableView *header = nil;
        
        if(kind == UICollectionElementKindSectionHeader)
        {
            header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"noImagesHeader" forIndexPath:indexPath];
            header.backgroundColor = [UIColor piwigoBackgroundColor];
            header.noImagesLabel.textColor = [UIColor piwigoHeaderColor];
            
            return header;
        }
    }
    
    UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
    return view;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(collectionView.frame.size.width, 44.0);
}

-(void)didSelectCollectionViewHeader
{
    SortSelectViewController *sortSelectVC = [SortSelectViewController new];
    sortSelectVC.delegate = self;
    sortSelectVC.currentSortType = self.sortType;
    [self.navigationController pushViewController:sortSelectVC animated:YES];
}

-(void)setSortType:(kPiwigoSortBy)sortType
{
    if(sortType != kPiwigoSortByNotUploaded && _sortType == kPiwigoSortByNotUploaded)
    {
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
    }
    
    _sortType = sortType;
    
    PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
    
    if(sortType == kPiwigoSortByNotUploaded)
    {
        if(!self.loadingView.superview)
        {
            self.loadingView = [LoadingView new];
            self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
            NSString *progressLabelFormat = [NSString stringWithFormat:@"%@ / %@", @"%d", @(downloadingCategory.numberOfImages)];
            self.loadingView.progressLabel.format = progressLabelFormat;
            self.loadingView.progressLabel.method = UILabelCountingMethodLinear;
            [self.loadingView showLoadingWithLabel:NSLocalizedString(@"downloadingImageInfo", @"Downloading Image Info") andProgressLabel:[NSString stringWithFormat:progressLabelFormat, 0]];
            [self.view addSubview:self.loadingView];
            [self.view addConstraints:[NSLayoutConstraint constraintCenterView:self.loadingView]];
            self.loadingView.hidden = YES;
            
            if(downloadingCategory.numberOfImages != downloadingCategory.imageList.count)
            {
                self.loadingView.hidden = NO;
                if(downloadingCategory.numberOfImages >= 100)
                {
                    [self.loadingView.progressLabel countFrom:0 to:100 withDuration:1];
                }
                else
                {
                    [self.loadingView.progressLabel countFrom:0 to:downloadingCategory.numberOfImages withDuration:1];
                }
            }
        }
    }
    
    __block NSDate *lastTime = [NSDate date];
    
    [SortSelectViewController getSortedImageArrayFromSortType:sortType
                forImages:self.images
              forCategory:self.categoryId
              forProgress:^(NSInteger onPage, NSInteger outOf) {
                  
                  // Calculate the number of thumbnails displayed per page
                  NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:nil andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
                  
                  NSInteger lastImageCount = (onPage + 1) * imagesPerPage;
                  NSInteger currentDownloaded = (onPage + 2) * imagesPerPage;
                  
                  NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:lastTime];
                  
                  if(currentDownloaded > downloadingCategory.numberOfImages)
                  {
                      currentDownloaded = downloadingCategory.numberOfImages;
                  }
                  
                  [self.loadingView.progressLabel countFrom:lastImageCount to:currentDownloaded withDuration:duration];
                  
                  lastTime = [NSDate date];
              } onCompletion:^(NSArray *images) {
                  
                  if(sortType == kPiwigoSortByNotUploaded && !self.loadingView.hidden)
                  {
                      [self.loadingView hideLoadingWithLabel:NSLocalizedString(@"Complete", nil) showCheckMark:YES withDelay:0.5];
                  }
                  self.images = images;
                  [self.localImagesCollection reloadData];
              }];
}



#pragma mark - UICollectionView - Rows

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.images.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if ([collectionView numberOfItemsInSection:section] == 0)
        return UIEdgeInsetsMake(0, kMarginsSpacing, 0, kMarginsSpacing);
    
    return UIEdgeInsetsMake(10, kMarginsSpacing, 10, kMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];

    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    
    PHAsset *imageAsset = [self.images objectAtIndex:indexPath.row];
    [cell setupWithImageAsset:imageAsset andThumbnailSize:(CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait]];

    // For some unknown reason, the asset resource may be empty
    NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
    NSString *originalFilename;
    if ([resources count] > 0) {
        originalFilename = ((PHAssetResource*)resources[0]).originalFilename;
    } else {
        // No filename => Build filename from 32 characters of local identifier
        NSRange range = [imageAsset.localIdentifier rangeOfString:@"/"];
        originalFilename = [[imageAsset.localIdentifier substringToIndex:range.location] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        // Filename extension required by Piwigo so that it knows how to deal with it
        if (imageAsset.mediaType == PHAssetMediaTypeImage) {
            // Adopt JPEG photo format by default, will be rechecked
            originalFilename = [originalFilename stringByAppendingPathExtension:@"jpg"];
        } else if (imageAsset.mediaType == PHAssetMediaTypeVideo) {
            // Videos are exported in MP4 format
            originalFilename = [originalFilename stringByAppendingPathExtension:@"mp4"];
        } else if (imageAsset.mediaType == PHAssetMediaTypeAudio) {
            // Arbitrary extension, not managed yet
            originalFilename = [originalFilename stringByAppendingPathExtension:@"m4a"];
        }
    }
    if([self.selectedImages containsObject:imageAsset])
    {
        cell.cellSelected = YES;
    }
    else if ([[ImageUploadManager sharedInstance].imageNamesUploadQueue containsObject:[originalFilename stringByDeletingPathExtension]])
    {
        cell.cellUploading = YES;
    }
    
    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
    
    PHAsset *imageAsset = [self.images objectAtIndex:indexPath.row];
    
    if(selectedCell.cellSelected)
    {    // Deselect the cell
        [self.selectedImages removeObject:imageAsset];
        selectedCell.cellSelected = NO;
    }
    else
    {    // Select the cell
        [self.selectedImages addObject:imageAsset];
        selectedCell.cellSelected = YES;
    }
    
    [self loadNavButtons];
}


#pragma mark - ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    NSInteger row = [self.images indexOfObject:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    
    CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
    CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
    CGFloat pieceProgress = (CGFloat)current / total;
    CGFloat uploadProgress = onChunkPercent + (chunkPercent * pieceProgress);
    if(uploadProgress > 1)
    {
        uploadProgress = 1;
    }
    
    cell.cellUploading = YES;
    if (iCloudProgress < 0) {
        cell.progress = uploadProgress;
//        NSLog(@"UploadViewController[ImageProgress]: %.2f", uploadProgress);
    } else {
        cell.progress = (iCloudProgress + uploadProgress) / 2.0;
//        NSLog(@"UploadViewController[ImageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
    }
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
//    NSLog(@"UploadViewController[imageUploaded]");
    NSInteger row = [self.images indexOfObject:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    
    // Image upload ended, deselect cell
    cell.cellUploading = NO;
    cell.cellSelected = NO;
    
    // Update list of "Not Uploaded" images
    if(self.sortType == kPiwigoSortByNotUploaded)
    {
        NSMutableArray *newList = [self.images mutableCopy];
        [newList removeObject:image.imageAsset];
        self.images = newList;
        
        // Update image collection
        [self.localImagesCollection reloadData];
    }
}


#pragma mark - SortSelectViewControllerDelegate Methods

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType
{
    self.sortType = sortType;
}


#pragma mark - Changes occured in the Photo library

- (void)photoLibraryDidChange:(PHChange *)changeInfo {
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        // Collect new list of images
        self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];

        // Sort images according to current choice
        [self setSortType:self.sortType];
        
        // Refresh collection view
        [self.localImagesCollection reloadData];
    });
}

@end

