//
//  SearchImagesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AlbumData.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "ImageCollectionViewCell.h"
#import "ImagesCollection.h"
#import "SearchImagesViewController.h"

@interface SearchImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, ImageDetailDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL displayImageTitles;

@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;

@property (nonatomic, assign) kPiwigoSortObjc currentSort;
@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation SearchImagesViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
        
        self.albumData = [[AlbumData alloc] initWithCategoryId:kPiwigoSearchCategoryId andQuery:@""];
        self.currentSort = (kPiwigoSortObjc)AlbumVars.defaultSort;
        self.displayImageTitles = AlbumVars.displayImageTitles;
        
        // Collection of images
        self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
        self.imagesCollection.dataSource = self;
        self.imagesCollection.delegate = self;
        
        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        
        [self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Navigation bar appearance
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    navigationBar.barStyle = AppVars.isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    navigationBar.tintColor = [UIColor piwigoColorOrange];

    // Toolbar appearance
    UIToolbar *toolbar = self.navigationController.toolbar;
    toolbar.barStyle = AppVars.isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    toolbar.tintColor = [UIColor piwigoColorOrange];

    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    navigationBar.titleTextAttributes = attributes;

    if (@available(iOS 11.0, *)) {
        navigationBar.prefersLargeTitles = NO;

        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *barAppearance = [[UINavigationBarAppearance alloc] init];
            [barAppearance configureWithTransparentBackground];
            barAppearance.backgroundColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.9];
            barAppearance.titleTextAttributes = attributes;
            barAppearance.shadowColor = AppVars.isDarkPaletteActive ? [UIColor colorWithWhite:1.0 alpha:0.15] : [UIColor colorWithWhite:0.0 alpha:0.3];
            self.navigationItem.standardAppearance = barAppearance;
            self.navigationItem.compactAppearance = barAppearance;   // For iPhone small navigation bar in landscape.
            self.navigationItem.scrollEdgeAppearance = barAppearance;
    
            UIToolbarAppearance *toolbarAppearance = [[UIToolbarAppearance alloc] initWithBarAppearance:barAppearance];
            toolbar.standardAppearance = toolbarAppearance;
            if (@available(iOS 15.0, *)) {
                /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
                /// which by default produces a transparent background, to all navigation bars.
                toolbar.scrollEdgeAppearance = toolbarAppearance;
            }
        }
    }
    else {
        navigationBar.barTintColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.3];
        toolbar.barTintColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.9];
    }

    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoColorBackground];
    self.imagesCollection.indicatorStyle = AppVars.isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Hide toolbar
    [self.navigationController setToolbarHidden:YES animated:YES];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Should we highlight the image of interest?
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        // Highlight the cell of interest
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is visible
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
                }];
            } else {
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
            }
        }
    }

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:[PwgNotificationsObjc paletteChanged] object:nil];

    // Register category data updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeImageFromCategory:) name:kPiwigoNotificationRemovedImage object:nil];
}

-(void)scrollToHighlightedCell
{
    // Should we highlight the image of interest?
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        // Highlight the cell of interest
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is already visible and is highlighted
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
                }];
            } else {
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
            }
        }
    }
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Should we update user interface based on the appearance?
    if (@available(iOS 13.0, *)) {
        BOOL hasUserInterfaceStyleChanged = (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle);
        if (hasUserInterfaceStyleChanged) {
            AppVars.isSystemDarkModeActive = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate screenBrightnessChanged];
        }
    } else {
        // Fallback on earlier versions
    }
}

-(void)dealloc
{
    // Unregister category data updates
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationRemovedImage object:nil];

    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[PwgNotificationsObjc paletteChanged] object:nil];
}


#pragma mark - Update data

-(void)searchAndLoadImages
{
    // Load, sort images and reload collection
    self.albumData.searchQuery = self.searchQuery;
    [self.albumData updateImageSort:self.currentSort onCompletion:^{
        [self.imagesCollection reloadData];
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        [self.navigationController dismissPiwigoErrorWithTitle:NSLocalizedString(@"albumPhotoError_title", @"Get Album Photos Error") message:NSLocalizedString(@"albumPhotoError_message", @"Failed to get album photos (corrupt image in your album?)") errorMessage:error.localizedDescription completion:^{}];
    }];
}

-(void)removeImageFromCategory:(NSNotification *)notification
{
    if (notification == nil) { return; }
    NSDictionary *userInfo = notification.userInfo;

    // Right category Id?
    NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
    if (catId != kPiwigoSearchCategoryId) return;
    
    // Get ID of removed image
    NSInteger imageId = [[userInfo objectForKey:@"imageId"] integerValue];
    NSLog(@"=> removeImage %ld from Category %ld", (long)imageId, (long)catId);

    // Get index of deleted image
    NSInteger indexOfExistingItem = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger oldIdx, BOOL * _Nonnull stop) {
     return obj.imageId == imageId;
    }];
    if (indexOfExistingItem != NSNotFound) {
        // Delete image from data source and corresponding cell
        NSMutableArray<PiwigoImageData *> *imageList = [self.albumData.images mutableCopy];
        [imageList removeObjectAtIndex:indexOfExistingItem];
        self.albumData.images = imageList;
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfExistingItem inSection:0];
        if ([self.imagesCollection.indexPathsForVisibleItems containsObject:indexPath]) {
            [self.imagesCollection deleteItemsAtIndexPaths:@[indexPath]];
        }
    }

    // Update footer if visible
    if ([self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter].count > 0) {
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
    }
}


#pragma mark - UICollectionView Headers & Footers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if(kind == UICollectionElementKindSectionFooter)
    {
        // Display number of images
        NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].numberOfImages;
        NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
        footer.noImagesLabel.textColor = [UIColor piwigoColorHeader];
        footer.noImagesLabel.text = [AlbumUtilities footerLegendFor:totalImageCount];
        return footer;
    }
    
    UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
    return view;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (([elementKind isEqualToString:UICollectionElementKindSectionHeader]) ||
        ([elementKind isEqualToString:UICollectionElementKindSectionFooter])) {
        view.layer.zPosition = 0;       // Below scroll indicator
        view.backgroundColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.75];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    // Display number of images
    NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].numberOfImages;
    NSString *footer = [AlbumUtilities footerLegendFor:totalImageCount];
    if (([footer length] > 0) && (collectionView.frame.size.width - 30.0 > 0)) {
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontLight]};
        NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
        context.minimumScaleFactor = 1.0;
        CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:attributes
                                                 context:context];
        return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(footerRect.size.height + 10.0));
    }
    
    return CGSizeZero;
}


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images
    return self.albumData.images.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if (self.albumData.images.count == 0) {
        return UIEdgeInsetsMake(0, kImageMarginsSpacing, 0, kImageMarginsSpacing);
    } else {
        return UIEdgeInsetsMake(4, kImageMarginsSpacing, 4, kImageMarginsSpacing);
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)[ImagesCollection imageCellVerticalSpacingForCollectionType:kImageCollectionFull];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)[ImagesCollection imageCellHorizontalSpacingForCollectionType:kImageCollectionFull];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
    
    if (self.albumData.images.count > indexPath.row) {
        // Create cell from Piwigo data
        PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
        [cell setupWithImageData:imageData inCategoryId:kPiwigoSearchCategoryId];
    
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
            cell.isFavorite = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:@[[NSNumber numberWithInteger:imageData.imageId]]];
        }
    }
    
    // Load more image data if possible (page after page…)
    PiwigoAlbumData *cachedAlbum = [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId];
    if (cachedAlbum.imageList.count < cachedAlbum.numberOfImages) {
        [self needToLoadMoreImages];
    }
    
    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Avoid rare crashes…
    if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) {
        // forget this call!
        return;
    }

    // Remember that user did tap this image
    self.imageOfInterest = indexPath;
    
    // Display full screen image
    if (@available(iOS 11.0, *)) {
        UIStoryboard *imageDetailSB = [UIStoryboard storyboardWithName:@"ImageDetailViewController" bundle:nil];
        self.imageDetailView = [imageDetailSB instantiateViewControllerWithIdentifier:@"ImageDetailViewController"];
        self.imageDetailView.imageIndex = indexPath.row;
        self.imageDetailView.categoryId = kPiwigoSearchCategoryId;
        self.imageDetailView.images = [self.albumData.images copy];
        self.imageDetailView.hidesBottomBarWhenPushed = YES;
        self.imageDetailView.imgDetailDelegate = self;
        [self.presentingViewController.navigationController pushViewController:self.imageDetailView animated:YES];
    }
}


#pragma mark - ImageDetailDelegate Methods

-(void)didSelectImageWithId:(NSInteger)imageId
{
    // Determine index of image
    NSInteger indexOfImage = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *image, NSUInteger index, BOOL * _Nonnull stop) {
     return image.imageId == imageId;
    }];
    if (indexOfImage == NSNotFound) { return; }

    // Scroll view to center image
    if ([self.imagesCollection numberOfItemsInSection:0] > indexOfImage) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfImage inSection:0];
        self.imageOfInterest = indexPath;
        [self.imagesCollection scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
    }
}

-(void)didUpdateImageWithData:(PiwigoImageData *)imageData
{
    // Check updated image
    if (imageData == nil) { return; }
    
    // Update data source
    NSInteger indexOfImage = [self.albumData updateImage:imageData];
    if (indexOfImage == NSNotFound) { return; }

    // Refresh image banner
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfImage inSection:0];
    if ([self.imagesCollection.indexPathsForVisibleItems containsObject:indexPath]) {
        [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
    }
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:0];
}

-(void)needToLoadMoreImages
{
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesToDownloadPerPage];
    NSInteger downloadedImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoSearchCategoryId].imageList.count;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.albumData loadMoreImagesOnCompletion:^(BOOL hasNewImages) {
            if (!hasNewImages) { return; }
            NSMutableArray *indexPaths = [NSMutableArray new];
            for (NSInteger i = downloadedImageCount; i < downloadedImageCount+imagesPerPage; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:1]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.imageDetailView != nil) {
                    self.imageDetailView.images = [self.albumData.images mutableCopy];
                }
                [self.imagesCollection reloadItemsAtIndexPaths:indexPaths];
            });
        } onFailure:nil];
    });
}

@end
