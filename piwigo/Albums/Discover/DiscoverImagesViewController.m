//
//  DiscoverImagesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AlbumData.h"
#import "AlbumService.h"
#import "AppDelegate.h"
#import "AsyncImageActivityItemProvider.h"
#import "AsyncVideoActivityItemProvider.h"
#import "CategoriesData.h"
#import "DiscoverImagesViewController.h"
#import "EditImageParamsViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "MoveImageViewController.h"

@interface DiscoverImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, ImageDetailDelegate, EditImageParamsDelegate, AsyncImageActivityItemProviderDelegate, MoveImagesDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem *moveBarButton;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) NSMutableArray *touchedImageIds;

@property (nonatomic, strong) NSMutableArray *selectedImageIdsToEdit;
@property (nonatomic, strong) NSMutableArray *selectedImagesToEdit;
@property (nonatomic, strong) NSMutableArray *selectedImageIdsToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImageIdsToShare;
@property (nonatomic, strong) NSMutableArray *selectedImagesToShare;
@property (nonatomic, strong) PiwigoImageData *selectedImage;

@property (nonatomic, assign) kPiwigoSort currentSortCategory;
@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

//#ifndef DEBUG_LIFECYCLE
//#define DEBUG_LIFECYCLE
//#endif

@implementation DiscoverImagesViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
    self = [super init];
    if(self)
    {
        self.categoryId = categoryId;
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
        
        self.albumData = [[AlbumData alloc] initWithCategoryId:categoryId andQuery:@""];
        self.currentSortCategory = [Model sharedInstance].defaultSort;
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
        
        // Initialise selection mode
        self.isSelect = NO;
        self.touchedImageIds = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];

        // Collection of images
        self.imagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagesCollection.backgroundColor = [UIColor clearColor];
        self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
        self.imagesCollection.delegate = self;
        self.imagesCollection.dataSource = self;
        
        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        
        [self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Bar buttons
        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(didTapSelect)];
        [self.selectBarButton setAccessibilityIdentifier:@"Select"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editSelection)];
        [self.editBarButton setAccessibilityIdentifier:@"edit"];
        self.deleteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageTrash"] landscapeImagePhone:[UIImage imageNamed:@"imageTrashCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelection)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        self.shareBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageShare"] landscapeImagePhone:[UIImage imageNamed:@"imageShareCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(shareSelection)];
        self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
        self.moveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageMove"] landscapeImagePhone:[UIImage imageNamed:@"imageMoveCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImagesToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
        self.navigationController.toolbarHidden = YES;

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoColorOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoColorBackground];

    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoColorBackground];
    self.imagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.imagesCollection reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
        
    // Set navigation bar buttons
    [self updateBarButtons];

    // Initialise discover cache
    PiwigoAlbumData *discoverAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:self.categoryId];
    [[CategoriesData sharedInstance] updateCategories:@[discoverAlbum]];

    // Load, sort images and reload collection
    [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

        // Set navigation bar buttons
        [self updateBarButtons];

        [self.imagesCollection reloadData];
    }];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Should we scroll to image of interest?
//    NSLog(@"••• Discover|Starting with %ld images", (long)[self.imagesCollection numberOfItemsInSection:0]);
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        
        // Thumbnail of interest is not the first one
        // => Scroll and highlight cell of interest
//        NSLog(@"=> Discover|Try to scroll to item=%ld", (long)self.imageOfInterest.item);
        
        // Thumbnail of interest already visible?
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is already visible and highlighted
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
                }];
            } else {
               self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
            }
        }
        else {
            // First visible thumbnail
            NSIndexPath *indexPathOfFirstVisibleThumbnail = [indexPathsForVisibleItems firstObject];
            
            // Thumbnail of interest above visible items?
            if (self.imageOfInterest.item < indexPathOfFirstVisibleThumbnail.item) {
                // Scroll up collection and highlight cell
//                NSLog(@"=> Discover|Scroll up to item #%ld", (long)self.imageOfInterest.item);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
            }
            
            // Thumbnail is below visible items
            // Get number of already loaded items
            NSInteger nberOfItems = [self.imagesCollection numberOfItemsInSection:0];
            if (self.imageOfInterest.item < nberOfItems) {
                // Already loaded => scroll to it
//                NSLog(@"=> Discover|Scroll down to item #%ld", (long)self.imageOfInterest.item);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
                
                // Calculate the number of thumbnails displayed per page
                NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.imagesCollection imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
                
                // Load more images if seems to be a good idea
                if ((self.imageOfInterest.item > (nberOfItems - roundf(imagesPerPage / 3.0))) &&
                    (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])) {
//                    NSLog(@"=> Discover|Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                    }];
                }
            } else {
                // No yet loaded => load more images
                // Should not happen as needToLoadMoreImages() should be called when previewing images
                if (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]) {
//                    NSLog(@"=> Discover|Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                    }];
                }
            }
        }
    }
    
    // Register category data updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addImageToCategory:) name:kPiwigoNotificationUploadedImage object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeImageFromCategory:) name:kPiwigoNotificationDeletedImage object:nil];
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    
    // When returning from imageDetailView, highlight image (which should now be visible)
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        // Visible cells
//        NSLog(@"=> Discover|Did end scrolling with %ld images", (long)[self.imagesCollection numberOfItemsInSection:0]);
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Get cell
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                // Highlight cell
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
                }];
            } else {
               self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
            }
        }
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }
    
    // Unregister category data updates
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCategoryDataUpdated object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationUploadedImage object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationDeletedImage object:nil];
}

-(void)updateBarButtons
{
    // Selection mode active ?
    if(!self.isSelect) {    // Image selection mode inactive
        
        // Title is name of the category
        self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];
        
        // Left side of navigation bar
        [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
        [self.navigationItem setHidesBackButton:NO];
        
        // Right side of navigation bar
        if (self.albumData.images.count > 0) {
            // Button for activating the selection mode
            [self.navigationItem setRightBarButtonItems:@[self.selectBarButton] animated:YES];
        } else {
            // No button
            [self.navigationItem setRightBarButtonItems:@[] animated:YES];
        }
    }
    else {         // Image selection mode active
        
        // Update title
        switch (self.selectedImageIds.count) {
            case 0:
                self.title = NSLocalizedString(@"selectImages", @"Select Photos");
                break;
                
            case 1:
                self.title = NSLocalizedString(@"selectImageSelected", @"1 Photo Selected");
                break;
                
            default:
                self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Photos Selected"), @(self.selectedImageIds.count)];
                break;
        }
        
        // Hide back button
        [self.navigationItem setHidesBackButton:YES];

        // User can delete images/videos if he/she has:
        // — admin rights
        if ([Model sharedInstance].hasAdminRights)
        {
            // Interface depends on device and orientation
            if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
                (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
                 ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
        
                // Redefine bar buttons (definition lost after rotation of device)
                self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
                self.deleteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageTrash"] landscapeImagePhone:[UIImage imageNamed:@"imageTrashCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteSelection)];
                self.deleteBarButton.tintColor = [UIColor redColor];
                self.shareBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageShare"] landscapeImagePhone:[UIImage imageNamed:@"imageShareCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(shareSelection)];
                self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
                self.moveBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageMove"] landscapeImagePhone:[UIImage imageNamed:@"imageMoveCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addImagesToCategory)];
                self.moveBarButton.tintColor = [UIColor piwigoColorOrange];

                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
                self.cancelBarButton.enabled = YES;

                // Right side of navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.editBarButton] animated:YES];
                self.editBarButton.enabled = (self.selectedImageIds.count > 0);

                // Toolbar
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.deleteBarButton];
                self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
                self.deleteBarButton.enabled = (self.selectedImageIds.count > 0);
            }
            else    // iPhone in landscape mode, iPad in any orientation
            {
                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];

                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton, self.deleteBarButton] animated:YES];
                self.cancelBarButton.enabled = YES;
                self.deleteBarButton.enabled = (self.selectedImageIds.count > 0);

                // Right side of navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.editBarButton, self.moveBarButton, self.shareBarButton] animated:YES];
                self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
                self.editBarButton.enabled = (self.selectedImageIds.count > 0);
          }
        }
        else    // No rights => No toolbar, only download button
        {
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];

            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];
            self.cancelBarButton.enabled = YES;

            // Right side of navigation bar
            [self.navigationItem setRightBarButtonItems:@[self.shareBarButton] animated:YES];
            self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
        }
    }
}

-(void)disableBarButtons
{
    self.cancelBarButton.enabled = NO;
    self.editBarButton.enabled = NO;
    self.deleteBarButton.enabled = NO;
    self.moveBarButton.enabled = NO;
    self.shareBarButton.enabled = NO;
}


#pragma mark - Category Data

-(void)categoryUpdated
{
    // Load, sort images and reload collection
    [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

        // Set navigation bar buttons
        [self updateBarButtons];

        [self.imagesCollection reloadData];
    }];
}

-(void)addImageToCategory:(NSNotification *)notification
{
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.categoryId) return;
        
        // Image Id?
        NSInteger imageId = [[userInfo objectForKey:@"imageId"] integerValue];
        NSLog(@"=> addImage %ld to Category %ld", (long)imageId, (long)catId);
        
        // Store current image list
        NSArray *oldImageList = self.albumData.images;
        NSLog(@"=> category %ld contained %ld images", (long)self.categoryId, (long)oldImageList.count);

        // Load new image (appended to cache) and sort images before updating UI
        [self.albumData loadMoreImagesOnCompletion:^{
            // Sort images
            [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

                // Refresh collection view if needed
                NSLog(@"=> category %ld now contains %ld images", (long)self.categoryId, (long)self.albumData.images.count);
                if (oldImageList.count == self.albumData.images.count) {
                    return;
                }

                // Insert cells of added images
                NSMutableArray<NSIndexPath *> *itemsToInsert = [NSMutableArray new];
                for (NSInteger index = 0; index < self.albumData.images.count; index++) {
                    PiwigoImageData *image = [self.albumData.images objectAtIndex:index];
                    NSInteger indexOfExistingItem = [oldImageList indexOfObjectPassingTest:^BOOL(PiwigoImageData *oldObj, NSUInteger oldIdx, BOOL * _Nonnull stop) {
                     return oldObj.imageId == image.imageId;
                    }];
                    if (indexOfExistingItem == NSNotFound) {
                     [itemsToInsert addObject:[NSIndexPath indexPathForItem:index inSection:0]];
                    }
                }
                if (itemsToInsert.count > 0) {
                    [self.imagesCollection insertItemsAtIndexPaths:itemsToInsert];
                }

                // Update footer
                UICollectionReusableView *visibleFooter = [[self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter] firstObject];
                NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
                if ([visibleFooter isKindOfClass:[NberImagesFooterCollectionReusableView class]]) {
                    NberImagesFooterCollectionReusableView *footer = (NberImagesFooterCollectionReusableView *)visibleFooter;
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setPositiveFormat:@"#,##0"];
                    footer.noImagesLabel.text = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]], totalImageCount > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
                }

                // Set navigation bar buttons
                [self updateBarButtons];
            }];
        }];
    }
}

-(void)removeImageFromCategory:(NSNotification *)notification
{
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.categoryId) return;
        
        // Image Id?
//        NSInteger imageId = [[userInfo objectForKey:@"imageId"] integerValue];
//        NSLog(@"=> removeImage %ld to Category %ld", (long)imageId, (long)catId);
        
        // Store current image list
        NSArray *oldImageList = self.albumData.images;
//        NSLog(@"=> category %ld contained %ld images", (long)self.categoryId, (long)oldImageList.count);

        // Load new image (appended to cache) and sort images before updating UI
        [self.albumData loadMoreImagesOnCompletion:^{
            // Sort images
            [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

                // Refresh collection view if needed
                NSLog(@"=> category %ld now contains %ld images", (long)self.categoryId, (long)self.albumData.images.count);
                if (oldImageList.count == self.albumData.images.count) {
                    return;
                }

                // Delete cells of deleted images, and remove them from selection
                NSMutableArray<NSIndexPath *> *itemsToDelete = [NSMutableArray new];
                for (NSInteger index = 0; index < oldImageList.count; index++) {
                    PiwigoImageData *imageData = [oldImageList objectAtIndex:index];
                    NSInteger indexOfExistingItem = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger oldIdx, BOOL * _Nonnull stop) {
                     return obj.imageId == imageData.imageId;
                    }];
                    if (indexOfExistingItem == NSNotFound) {
                        [itemsToDelete addObject:[NSIndexPath indexPathForItem:index inSection:0]];
                        NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)imageData.imageId];
                        if ([self.selectedImageIds containsObject:imageIdObject]) {
                            [self.selectedImageIds removeObject:imageIdObject];
                        }
                    }
                }
                if (itemsToDelete.count > 0) {
                    [self.imagesCollection deleteItemsAtIndexPaths:itemsToDelete];
                }

                // Update footer
                UICollectionReusableView *visibleFooter = [[self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter] firstObject];
                NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                if ([visibleFooter isKindOfClass:[NberImagesFooterCollectionReusableView class]]) {
                    NberImagesFooterCollectionReusableView *footer = (NberImagesFooterCollectionReusableView *)visibleFooter;
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setPositiveFormat:@"#,##0"];
                    footer.noImagesLabel.text = [NSString stringWithFormat:@"%@ %@", [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]], totalImageCount > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
                }

                // Set navigation bar buttons
                [self updateBarButtons];
            }];
        }];
    }
}


#pragma mark - Select Images

-(void)didTapSelect
{
    // Activate Images Selection mode
    self.isSelect = YES;
    
    // Update navigation bar
    [self updateBarButtons];
}

-(void)cancelSelect
{
    // Disable Images Selection mode
    self.isSelect = NO;
    
    // Update navigation bar
    [self updateBarButtons];
    
    // Deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Deselect image cell and disable interaction
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            if(imageCell.isSelected) imageCell.isSelected = NO;
        }
    }

    // Clear array of selected images and allow iOS device to sleep
    self.touchedImageIds = [NSMutableArray new];
    self.selectedImageIds = [NSMutableArray new];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    // Will examine touchs only in select mode
    if (self.isSelect) {
       return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // Will interpret touches only in horizontal direction
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *gPR = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [gPR translationInView:self.imagesCollection];
        if (fabs(translation.x) > fabs(translation.y))
            return YES;
    }
    return NO;
}

-(void)touchedImages:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Just in case…
    if (gestureRecognizer.view == nil) return;
    
    // Select/deselect cells
    if ((gestureRecognizer.state == UIGestureRecognizerStateBegan) ||
        (gestureRecognizer.state == UIGestureRecognizerStateChanged)) {
        
        // Point and direction
        CGPoint point = [gestureRecognizer locationInView:self.imagesCollection];
        
        // Get cell at touch position
        NSIndexPath *indexPath = [self.imagesCollection indexPathForItemAtPoint:point];
        if (indexPath.row == NSNotFound) return;
        UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:indexPath];
        if (cell == nil) return;
        
        // Only consider image cells
        if ([cell isKindOfClass:[ImageCollectionViewCell class]])
        {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            
            // Update the selection if not already done
            NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)imageCell.imageData.imageId];
            if (![self.touchedImageIds containsObject:imageIdObject]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImageIds addObject:imageIdObject];
                
                // Update the selection state
                if(![self.selectedImageIds containsObject:imageIdObject]) {
                    [self.selectedImageIds addObject:imageIdObject];
                    imageCell.isSelected = YES;
                } else {
                    imageCell.isSelected = NO;
                    [self.selectedImageIds removeObject:imageIdObject];
                }
                
                // Reload the cell and update the navigation bar
                [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
                [self updateBarButtons];
            }
        }
    }
    
    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImageIds = [NSMutableArray new];
    }
}


#pragma mark - UICollectionView Headers & Footers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if(kind == UICollectionElementKindSectionFooter)
    {
        // Display number of images
        NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
        NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
        footer.noImagesLabel.textColor = [UIColor piwigoColorHeader];
        
        if (totalImageCount == 0) {
            // Display "No images"
            footer.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
            }
        else {
            // Display number of images…
            footer.noImagesLabel.text = [NSString stringWithFormat:@"%ld %@", (long)totalImageCount, (totalImageCount > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
        }

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
    NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].numberOfImages;
    NSString *footer = @"";

    if (totalImageCount == 0) {
        // Display "No images"
        footer = NSLocalizedString(@"noImages", @"No Images");
    }
    else {
        // Display number of images…
        footer = [NSString stringWithFormat:@"%ld %@", (long)totalImageCount, (totalImageCount > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
    }

    if ([footer length] > 0) {
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
    return [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
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
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
    
    if (self.albumData.images.count > indexPath.row) {
        // Create cell from Piwigo data
        PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
        [cell setupWithImageData:imageData forCategoryId:self.categoryId];
        cell.isSelected = [self.selectedImageIds containsObject:[NSString stringWithFormat:@"%ld", (long)imageData.imageId]];
        
        // Add pan gesture recognition
        UIPanGestureRecognizer *imageSeriesRocognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touchedImages:)];
        imageSeriesRocognizer.minimumNumberOfTouches = 1;
        imageSeriesRocognizer.maximumNumberOfTouches = 1;
        imageSeriesRocognizer.cancelsTouchesInView = NO;
        imageSeriesRocognizer.delegate = self;
        [cell addGestureRecognizer:imageSeriesRocognizer];
        cell.userInteractionEnabled = YES;
    }
    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:collectionView imagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Load image data in advance if possible (page after page…)
    if ((indexPath.row > fmaxf(roundf(2 * imagesPerPage / 3.0), [collectionView numberOfItemsInSection:0] - roundf(imagesPerPage / 3.0))) &&
        (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
    {
        [self.albumData loadMoreImagesOnCompletion:^{
            [self.imagesCollection reloadData];
        }];
    }
    
    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];

    // Avoid rare crashes…
    if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) {
        // forget this call!
        return;
    }

    // Action depends on mode
    if(!self.isSelect)
    {
        // Selection mode not active => display full screen image
        self.imageDetailView = [[ImageDetailViewController alloc] initWithCategoryId:self.categoryId atImageIndex:indexPath.row withArray:[self.albumData.images copy]];
        self.imageDetailView.hidesBottomBarWhenPushed = YES;
        self.imageDetailView.imgDetailDelegate = self;
        [self.navigationController pushViewController:self.imageDetailView animated:YES];
    }
    else
    {
        // Selection mode active => add/remove image from selection
        NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)selectedCell.imageData.imageId];
        if(![self.selectedImageIds containsObject:imageIdObject]) {
            [self.selectedImageIds addObject:imageIdObject];
            selectedCell.isSelected = YES;
        } else {
            selectedCell.isSelected = NO;
            [self.selectedImageIds removeObject:imageIdObject];
        }
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];

        // and display nav buttons
        [self updateBarButtons];
    }
}


#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title inMode:(MBProgressHUDMode)mode withDetailLabel:(BOOL)isDownloading
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];
        
        // Change the background view shape, style and color.
        hud.square = NO;
        hud.animationType = MBProgressHUDAnimationFade;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        hud.contentColor = [UIColor piwigoColorText];
        hud.bezelView.color = [UIColor piwigoColorText];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.backgroundColor = [UIColor piwigoColorCellBackground];

        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);
    }
    
    // Set title
    hud.label.text = title;
    hud.label.font = [UIFont piwigoFontNormal];
    
    // Image download or other action?
    switch (mode) {
        case MBProgressHUDModeAnnularDeterminate:
            // Downloading or deleting images
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            if (isDownloading) {
                hud.detailsLabel.text = [NSString stringWithFormat:@"%ld / %ld", (long)(self.totalNumberOfImages - self.selectedImageIds.count + 1), (long)self.totalNumberOfImages];
            } else {
                hud.detailsLabel.text = @"";
            }
            break;
            
        default:
            // Other actions
            hud.mode = MBProgressHUDModeIndeterminate;
            hud.detailsLabel.text = @"";
            break;
    }
}

-(void)hideHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:1.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}

-(void)hideHUD
{
    // Hide and remove the HUD
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}


#pragma mark - Edit images

-(void)editSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToEdit = [NSMutableArray new];
    self.selectedImageIdsToEdit = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeEdit];
}

-(void)retrieveImageDataBeforeEdit
{
    if (self.selectedImageIdsToEdit.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self editImages];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToEdit lastObject] integerValue]
                      OnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      
                      if (imageData != nil) {
                          // Store image data
                          [self.selectedImagesToEdit insertObject:imageData atIndex:0];
                          
                          // Next image
                          [self.selectedImageIdsToEdit removeLastObject];
                          [self retrieveImageDataBeforeEdit];
                      }
                      else {
                          // Could not retrieve image data
                          [self couldNotRetrieveImageDataOnRetry:^{
                              [self retrieveImageDataBeforeEdit];
                          }];
                      }
                  }
                         onFailure:^(NSURLSessionTask *task, NSError *error) {
                             // Failed — Ask user if he/she wishes to retry
                             [self couldNotRetrieveImageDataOnRetry:^{
                                 [self retrieveImageDataBeforeEdit];
                             }];
                         }];
}

-(void)couldNotRetrieveImageDataOnRetry:(void (^)(void))completion
{
    // Failed — Ask user if he/she wishes to retry
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
        message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?")
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateBarButtons];
                [self hideHUD];
            });
        }];
    
    UIAlertAction* retryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            if (completion) completion();
        }];
    
    [alert addAction:dismissAction];
    [alert addAction:retryAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)editImages
{
    switch (self.selectedImagesToEdit.count) {
        case 0:     // No image => End (should never happened)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideHUDwithSuccess:YES completion:^{
                    [self cancelSelect];
                }];
            });
            break;
        }
            
        default:    // Several images
        {
            // Present EditImageParams view
            UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageParams" bundle:nil];
            EditImageParamsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageParams"];
            editImageVC.images = [self.selectedImagesToEdit copy];
            editImageVC.delegate = self;
            [self pushView:editImageVC];
            break;
        }
    }
}


#pragma mark - Delete images

-(void)deleteSelection
{
    if(self.selectedImageIds.count <= 0) return;
    
    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:NO];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
        });
    }


    // Retrieve image data
    self.selectedImagesToDelete = [NSMutableArray new];
    self.selectedImageIdsToDelete = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeDelete];
}

-(void)retrieveImageDataBeforeDelete
{
    if (self.selectedImageIdsToDelete.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self askDeleteConfirmation];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved with pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToDelete lastObject] integerValue]
                      OnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {

              if (imageData != nil) {
                  // Collect orphaned and non-orphaned images
                  [self.selectedImagesToDelete insertObject:imageData atIndex:0];
              
                  // Image info retrieved
                  [self.selectedImageIdsToDelete removeLastObject];

                  // Update HUD
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0 - (double)(self.selectedImageIdsToDelete.count) / self.totalNumberOfImages;
                  });

                  // Next image
                  [self retrieveImageDataBeforeDelete];
              }
              else {
                  // Could not retrieve image data
                  [self couldNotRetrieveImageDataOnRetry:^{
                      [self retrieveImageDataBeforeDelete];
                  }];
              }
          }
                 onFailure:^(NSURLSessionTask *task, NSError *error) {
                     // Failed — Ask user if he/she wishes to retry
                     [self couldNotRetrieveImageDataOnRetry:^{
                         [self retrieveImageDataBeforeDelete];
                     }];
                 }];
}

-(void)askDeleteConfirmation
{
    NSString *messageString;
    // Alert message
    if (self.selectedImagesToDelete.count > 1) {
        messageString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_message", @"Are you sure you want to delete the selected %@ images?"), @(self.selectedImagesToDelete.count)];
    } else {
        messageString = NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image?");
    }

    // Do we really want to delete these images?
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:nil
        message:messageString
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            [self updateBarButtons];
        }];
    
    UIAlertAction* deleteImagesAction = [UIAlertAction
        actionWithTitle:self.selectedImagesToDelete.count > 1 ? [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_title", @"Delete %@ Images"), @(self.selectedImagesToDelete.count)] : NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            
            // Display HUD during server update
            if (self.selectedImagesToDelete.count > 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
                });
            }

            // Start deleting images
            [self deleteImages];
       }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteImagesAction];

    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)deleteImages
{
    if (self.selectedImagesToDelete.count <= 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:YES completion:^{
                [self cancelSelect];
            }];
        });
        return;
    }
    
    // Let's delete all images at once
    [ImageService deleteImages:self.selectedImagesToDelete
              ListOnCompletion:^(NSURLSessionTask *task) {
                  
                  // Hide HUD
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [self hideHUDwithSuccess:YES completion:^{
                          [self cancelSelect];
                      }];
                  });
              }
                    onFailure:^(NSURLSessionTask *task, NSError *error) {
                        // Error — Try again ?
                        UIAlertController* alert = [UIAlertController
                            alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                            message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
                            preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction* dismissAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                            style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction * action) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self hideHUDwithSuccess:NO completion:^{
                                        [self updateBarButtons];
                                    }];
                                });
                            }];
                        
                        UIAlertAction* retryAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                            style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction * action) {
                              [self deleteImages];
                            }];
                        
                        // Add actions
                        [alert addAction:dismissAction];
                        [alert addAction:retryAction];
                        
                        // Present list of actions
                        alert.view.tintColor = UIColor.piwigoColorOrange;
                        if (@available(iOS 13.0, *)) {
                            alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
                        } else {
                            // Fallback on earlier versions
                        }
                        [self presentViewController:alert animated:YES completion:^{
                            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                            alert.view.tintColor = UIColor.piwigoColorOrange;
                        }];
                    }];
}


#pragma mark - Share images

-(void)shareSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self disableBarButtons];
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToShare = [NSMutableArray new];
    self.selectedImageIdsToShare = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeShare];
}

-(void)retrieveImageDataBeforeShare
{
    if (self.selectedImageIdsToShare.count <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideHUDwithSuccess:NO completion:^{
                [self checkPhotoLibraryAccessBeforeShare];
            }];
        });
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageService getImageInfoById:[[self.selectedImageIdsToShare lastObject] integerValue]
                      OnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      
                      if (imageData != nil) {
                          // Store image data
                          [self.selectedImagesToShare insertObject:imageData atIndex:0];
                          
                          // Next image
                          [self.selectedImageIdsToShare removeLastObject];
                          [self retrieveImageDataBeforeShare];
                      }
                      else {
                          // Could not retrieve image data
                          [self couldNotRetrieveImageDataOnRetry:^{
                              [self retrieveImageDataBeforeShare];
                          }];
                      }
                  }
                         onFailure:^(NSURLSessionTask *task, NSError *error) {
                             // Failed — Ask user if he/she wishes to retry
                             [self couldNotRetrieveImageDataOnRetry:^{
                                 [self retrieveImageDataBeforeShare];
                             }];
                         }];
}

-(void)checkPhotoLibraryAccessBeforeShare
{
    // Check autorisation to access Photo Library (camera roll)
    if (@available(iOS 14, *)) {
        [[PhotosFetch sharedInstance] checkPhotoLibraryAuthorizationStatusFor:PHAccessLevelAddOnly for:self
            onAccess:^{
            // User allowed to save image in camera roll
            [self presentShareImageViewControllerWithCameraRollAccess:YES];
        } onDeniedAccess:^{
            // User not allowed to save image in camera roll
            if ([NSThread isMainThread]) {
                [self presentShareImageViewControllerWithCameraRollAccess:NO];
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentShareImageViewControllerWithCameraRollAccess:NO];
                });
            }
        }];
    } else {
        // Fallback on earlier versions
        [[PhotosFetch sharedInstance] checkPhotoLibraryAccessForViewController:nil
                onAuthorizedAccess:^{
                    // User allowed to save image in camera roll
                    [self presentShareImageViewControllerWithCameraRollAccess:YES];
                }
                    onDeniedAccess:^{
                        // User not allowed to save image in camera roll
                        if ([NSThread isMainThread]) {
                            [self presentShareImageViewControllerWithCameraRollAccess:NO];
                        }
                        else{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self presentShareImageViewControllerWithCameraRollAccess:NO];
                            });
                        }
                }];
    }
}

-(void)presentShareImageViewControllerWithCameraRollAccess:(BOOL)hasCameraRollAccess
{
    // Create new activity provider items to pass to the activity view controller
    self.totalNumberOfImages = self.selectedImagesToShare.count;
    NSMutableArray *itemsToShare = [NSMutableArray new];
    for (PiwigoImageData *imageData in self.selectedImagesToShare) {
        if (imageData.isVideo) {
            // Case of a video
            AsyncVideoActivityItemProvider *videoItemProvider = [[AsyncVideoActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:videoItemProvider];
        }
        else {
            // Case of an image
            AsyncImageActivityItemProvider *imageItemProvider = [[AsyncImageActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            imageItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:imageItemProvider];
        }
    }

    // Create an activity view controller with the activity provider item.
    // AsyncImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    
    // Set HUD view controller for displaying progress
    self.hudViewController = activityViewController;
    
    // Exclude camera roll activity if needed
    if (!hasCameraRollAccess) {
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }

    // Delete image/video files and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
//        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
//            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            [self hideHUDwithSuccess:YES completion:nil];
            [self cancelSelect];
            for (PiwigoImageData *imageData in self.selectedImagesToShare) {
                if (imageData.isVideo) {
                    // Delete shared video file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                }
                else {
                    // Delete shared image file & remove observers
                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                }
            }
        } else {
            if (activityType == NULL) {
//                NSLog(@"User dismissed the view controller without making a selection.");
                [self updateBarButtons];
            }
            else {
//                NSLog(@"Activity was not performed.");
                [self cancelSelect];
                for (PiwigoImageData *imageData in self.selectedImagesToShare) {
                    if (imageData.isVideo)
                    {
                        // Cancel download task
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadVideo object:nil];
                        
                        // Delete shared video file & remove observers
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareVideo object:nil];
                    }
                    else {
                        // Cancel download task
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownloadImage object:nil];
                        
                        // Delete shared image file & remove observers
                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShareImage object:nil];
                    }
                }
            }
        }
    }];
    
    // Present share image activity view controller
    activityViewController.popoverPresentationController.barButtonItem = self.shareBarButton;
    [self presentViewController:activityViewController animated:YES completion:nil];
}


#pragma mark - Move/Copy images to Category

-(void)addImagesToCategory
{
    // Disable buttons
    [self disableBarButtons];
    
    // Determine index of first selected cell
    NSInteger indexOfFirstSelectedImage = LONG_MAX;
    PiwigoImageData *firstImageData;
    for (NSNumber *imageId in self.selectedImageIds) {
        NSInteger obj1 = [imageId integerValue];
        NSInteger index = 0;
        for (PiwigoImageData *image in self.albumData.images) {
            NSInteger obj2 = image.imageId;
            if (obj1 == obj2) break;
            index++;
        }
        indexOfFirstSelectedImage = MIN(index, indexOfFirstSelectedImage);
        firstImageData = [self.albumData.images objectAtIndex:indexOfFirstSelectedImage];
    }

    // Present album list for copying images into
    MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:self.selectedImageIds orSingleImageData:firstImageData inCategoryId:self.categoryId atIndex:indexOfFirstSelectedImage andCopyOption:YES];
    moveImageVC.moveImagesDelegate = self;
    [self pushView:moveImageVC];
}


#pragma mark - ImageDetailDelegate Methods

-(void)didFinishPreviewOfImageWithId:(NSInteger)imageId
{
    NSInteger index = 0;
    for (PiwigoImageData *image in self.albumData.images) {
        if (image.imageId == imageId) break;
        index++;
    }
    if (index < [self.albumData.images count])
        self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:0];
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:0];
}

-(void)needToLoadMoreImages
{
    [self.albumData loadMoreImagesOnCompletion:^{
        if(self.imageDetailView != nil)
        {
            self.imageDetailView.images = [self.albumData.images mutableCopy];
        }
        [self.imagesCollection reloadData];
    }];
}


#pragma mark - EditImageParamsDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Deselect image
    [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)imageId]];
    [self.imagesCollection reloadData];
}

-(void)didRenameFileOfImage:(PiwigoImageData *)imageData
{
    // Update image data
    [self.albumData updateImage:imageData];
}

-(void)didFinishEditingParams:(PiwigoImageData *)params
{
    // Update image data
    [self.albumData updateImage:params];

    // Deselect images and leave select mode
    [self cancelSelect];
}


#pragma mark - MoveImagesDelegate methods

-(void)cancelMoveImages
{
    // Re-enable buttons
    [self updateBarButtons];
}

-(void)didRemoveImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    // NOP — Should never happen
}

-(void)deselectImages
{
    // Deselect images and leave select mode
    [self cancelSelect];
}


#pragma mark - AsyncImageActivityItemProviderDelegate

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider withTitle:(NSString *)title
{
    // Show HUD to let the user know the image is being downloaded in the background.
    dispatch_async(dispatch_get_main_queue(),
           ^(void){
               [self showHUDwithTitle:title inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:YES];
           });
}

-(void)imageActivityItemProvider:(UIActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress
{
    // Update HUD
    dispatch_async(dispatch_get_main_queue(),
           ^(void){
               [MBProgressHUD HUDForView:self.hudViewController.view].progress = progress;
           });
}

-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider withImageId:(NSInteger)imageId
{
    // Close HUD
    NSString *imageIdObject = [NSString stringWithFormat:@"%ld", (long)imageId];
    dispatch_async(dispatch_get_main_queue(),
           ^(void){
               if ([imageActivityItemProvider isCancelled]) {
                   [self hideHUDwithSuccess:NO completion:^{
                       self.hudViewController = nil;
                   }];
               } else {
                   if ([self.selectedImageIds containsObject:imageIdObject]) {
                       // Remove image from selection
                       [self.selectedImageIds removeObject:imageIdObject];
                       // Close HUD if last image
                       if ([self.selectedImageIds count] == 0) {
                           [self hideHUDwithSuccess:NO completion:^{
                               self.hudViewController = nil;
                           }];
                       }
                   }
               }
           });
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message
{
    // Display error alert after trying to share image
    dispatch_async(dispatch_get_main_queue(),
           ^(void){
               // Determine present view controller
               UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
               while (topViewController.presentedViewController) {
                   topViewController = topViewController.presentedViewController;
               }
               
               // Present alert
               UIAlertController* alert = [UIAlertController
                       alertControllerWithTitle:title
                       message:message
                       preferredStyle:UIAlertControllerStyleAlert];
               
               UIAlertAction* dismissAction = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                       style:UIAlertActionStyleCancel
                       handler:^(UIAlertAction * action) { }];
               
               [alert addAction:dismissAction];
               alert.view.tintColor = UIColor.piwigoColorOrange;
               if (@available(iOS 13.0, *)) {
                   alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
               } else {
                   // Fallback on earlier versions
               }
               [topViewController presentViewController:alert animated:YES completion:^{
                   // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                   alert.view.tintColor = UIColor.piwigoColorOrange;
               }];
           });
}


#pragma mark - Utilities

-(void)pushView:(UIViewController *)viewController
{
    // Push album list or image properties editor
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        viewController.modalPresentationStyle = UIModalPresentationPopover;
        viewController.popoverPresentationController.sourceView = self.imagesCollection;
        if ([viewController isKindOfClass:[MoveImageViewController class]]) {
            viewController.popoverPresentationController.barButtonItem = self.moveBarButton;
            viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
            [self.navigationController presentViewController:viewController animated:YES completion:nil];
        }
        else if ([viewController isKindOfClass:[EditImageParamsViewController class]]) {
            // Push Edit view embedded in navigation controller
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
            navController.popoverPresentationController.barButtonItem = self.editBarButton;
            navController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
            [self.navigationController presentViewController:navController animated:YES completion:nil];
        }
    }
    else {
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.modalPresentationStyle = UIModalPresentationPopover;
        navController.popoverPresentationController.sourceView = self.view;
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self.navigationController presentViewController:navController animated:YES completion:nil];
    }
}


@end
