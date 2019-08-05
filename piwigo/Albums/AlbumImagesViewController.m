//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
//#import <StoreKit/StoreKit.h>

#import "AlbumData.h"
#import "AlbumImagesViewController.h"
#import "AlbumService.h"
#import "AsyncImageActivityItemProvider.h"
#import "AsyncVideoActivityItemProvider.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "CategoryCollectionViewCell.h"
#import "CategoryHeaderReusableView.h"
//#import "CategoryImageSort.h"
#import "CategoryPickViewController.h"
#import "DiscoverImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "LocalAlbumsViewController.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "MoveCategoryViewController.h"
#import "MoveImageViewController.h"
#import "NetworkHandler.h"
#import "NoImagesHeaderCollectionReusableView.h"
#import "PhotosFetch.h"
#import "SAMKeychain.h"
#import "SearchImagesViewController.h"
#import "SettingsViewController.h"
#import "TagSelectViewController.h"

CGFloat const kRadius = 25.0;
NSString * const kPiwigoNotificationBackToDefaultAlbum = @"kPiwigoNotificationBackToDefaultAlbum";

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIToolbarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate, ImageDetailDelegate, MoveImagesDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate, AsyncImageActivityItemProviderDelegate, TagSelectViewDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL isCachedAtInit;
@property (nonatomic, strong) NSString *currentSort;
@property (nonatomic, assign) BOOL loadingImages;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *settingsBarButton;
@property (nonatomic, strong) UIBarButtonItem *discoverBarButton;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem *moveBarButton;
@property (nonatomic, strong) UIButton *uploadButton;
@property (nonatomic, strong) UIButton *homeAlbumButton;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) NSMutableArray *touchedImageIds;

@property (nonatomic, strong) NSMutableArray *selectedImageIdsToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToRemove;
@property (nonatomic, strong) NSMutableArray *selectedImageIdsToShare;
@property (nonatomic, strong) NSMutableArray *selectedImagesToShare;
@property (nonatomic, strong) PiwigoImageData *selectedImage;

@property (nonatomic, strong) UISearchController *searchController;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached
{
    self = [super init];
	if(self)
	{
		self.categoryId = albumId;
        self.loadingImages = NO;
        self.isCachedAtInit = isCached;
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
        
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];
		self.currentSortCategory = [Model sharedInstance].defaultSort;
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
		
        // Initialise selection mode
        self.isSelect = NO;
        self.touchedImageIds = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];

        // Collection of images
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
		self.imagesCollection.dataSource = self;
		self.imagesCollection.delegate = self;

        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
		[self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"CategoryCollectionViewCell"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader"];
        [self.imagesCollection registerClass:[NoImagesHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"NoImagesHeaderCollection"];

		[self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Bar buttons
        self.settingsBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"preferences"] landscapeImagePhone:[UIImage imageNamed:@"preferencesCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(displayPreferences)];
        [self.settingsBarButton setAccessibilityIdentifier:@"preferences"];
        self.discoverBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list"] landscapeImagePhone:[UIImage imageNamed:@"listCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(discoverImages)];
        [self.discoverBarButton setAccessibilityIdentifier:@"discover"];

        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
        [self.selectBarButton setAccessibilityIdentifier:@"Select"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelected)];
        self.deleteBarButton.tintColor = [UIColor redColor];
        self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelected)];
        self.shareBarButton.tintColor = [UIColor piwigoOrange];
        self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImagesToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoOrange];
        self.navigationController.toolbar.barStyle = UIBarStyleDefault;
        self.navigationController.toolbarHidden = YES;

        // Upload button above collection view
        self.uploadButton = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
        CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
        self.uploadButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
        self.uploadButton.layer.cornerRadius = kRadius;
        self.uploadButton.layer.masksToBounds = NO;
        [self.uploadButton.layer setOpacity:0.9];
        [self.uploadButton.layer setShadowColor:[UIColor piwigoGray].CGColor];
        [self.uploadButton.layer setShadowOpacity:1.0];
        [self.uploadButton.layer setShadowRadius:5.0];
        [self.uploadButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.uploadButton.backgroundColor = [UIColor piwigoOrange];
        self.uploadButton.tintColor = [UIColor whiteColor];
        self.uploadButton.showsTouchWhenHighlighted = YES;
        [self.uploadButton setImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
        [self.uploadButton addTarget:self action:@selector(displayUpload)
               forControlEvents:UIControlEventTouchUpInside];
        self.uploadButton.hidden = YES;
        [self.view addSubview:self.uploadButton];

        // Home album button above collection view
        self.homeAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.homeAlbumButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
        self.homeAlbumButton.layer.cornerRadius = kRadius;
        self.homeAlbumButton.layer.masksToBounds = NO;
        [self.homeAlbumButton.layer setOpacity:0.9];
        [self.homeAlbumButton.layer setShadowColor:[UIColor piwigoGray].CGColor];
        [self.homeAlbumButton.layer setShadowOpacity:1.0];
        [self.homeAlbumButton.layer setShadowRadius:5.0];
        [self.homeAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 2.0)];
        self.homeAlbumButton.showsTouchWhenHighlighted = YES;
        [self.homeAlbumButton setImage:[UIImage imageNamed:@"rootAlbum"] forState:UIControlStateNormal];
        [self.homeAlbumButton addTarget:self action:@selector(returnToDefaultCategory)
                    forControlEvents:UIControlEventTouchUpInside];
        self.homeAlbumButton.hidden = YES;
        [self.view addSubview:self.homeAlbumButton];

        // Register category data updates
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCategoryData:) name:kPiwigoNotificationGetCategoryData object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];

        // Register root album changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(returnToDefaultCategory) name:kPiwigoNotificationBackToDefaultAlbum object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // For iOS 11 and later: place search bar in navigation bar or root album
    if (@available(iOS 11.0, *)) {
        // Initialise search controller when displaying root album
        if (self.categoryId == 0) {
            SearchImagesViewController *resultsCollectionController = [[SearchImagesViewController alloc] init];
            self.searchController = [[UISearchController alloc] initWithSearchResultsController:resultsCollectionController];
            self.searchController.delegate = self;
            self.searchController.hidesNavigationBarDuringPresentation = YES;
            self.searchController.searchResultsUpdater = self;
            
            [self.searchController.searchBar setTintColor:[UIColor piwigoOrange]];
            self.searchController.searchBar.showsCancelButton = NO;
            self.searchController.searchBar.showsSearchResultsButton = NO;
            self.searchController.searchBar.delegate = self;        // Monitor when the search button is tapped.
            self.definesPresentationContext = YES;
            
            // Place the search bar in the navigation bar.
            self.navigationItem.searchController = self.searchController;

//        for (UIView *subView in self.searchController.searchBar.subviews)
//        {
//            if ([subView isKindOfClass: [UITextField class]])
//            {
//                [(UITextField *)subView setKeyboardAppearance:[Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault];
//            }
//        }
        }
    }
}

//-(void)setKeyboardAppearence: (UIKeyboardAppearance) appearence {
//    [(id<UITextInputTraits>) [self firstSubviewConformingToProtocol: @protocol(UITextInputTraits)] setKeyboardAppearance: appearence];
//}
//
//- (UIView *)firstSubviewConformingToProtocol: (Protocol *) pro {
//    for (UIView *sub in self.searchController.searchBar.subviews)
//        if ([sub conformsToProtocol: pro])
//            return sub;
//
//    for (UIView *sub in self.searchController.searchBar.subviews) {
//        UIView *ret = [sub firstSubviewConformingToProtocol: pro];
//        if (ret)
//            return ret;
//    }
//
//    return nil;
//}

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    self.imagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    
    // Buttons
    self.homeAlbumButton.backgroundColor = [UIColor piwigoRightLabelColor];
    self.homeAlbumButton.tintColor = [UIColor piwigoBackgroundColor];

    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        if (self.categoryId == [Model sharedInstance].defaultCategory) {
            NSDictionary *attributesLarge = @{
                                              NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                              NSFontAttributeName: [UIFont piwigoFontLargeTitle],
                                              };
            self.navigationController.navigationBar.largeTitleTextAttributes = attributesLarge;
            self.navigationController.navigationBar.prefersLargeTitles = YES;
        }
        else {
            self.navigationController.navigationBar.prefersLargeTitles = NO;
        }
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    [self.navigationController.navigationBar setAccessibilityIdentifier:@"AlbumImagesNav"];
    
    // Toolbar
    [self.navigationController.toolbar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.toolbar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoBackgroundColor];
    [self refreshShowingCells];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Called before displaying SearchImagesViewController?
    UIViewController *presentedViewController = [self presentedViewController];
    if ([presentedViewController isKindOfClass:[UISearchController class]]) {
        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];
        return;
    }
    
    // Set colors, fonts, etc.
    [self paletteChanged];
    
    // Reload category data and refresh showing cells
    [self getCategoryData:nil];
    [self refreshShowingCells];

    // Inform Upload view controllers that user selected this category
    NSDictionary *userInfo = @{@"currentCategoryId" : @(self.categoryId)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedCurrentCategory object:nil userInfo:userInfo];
    
    // Load, sort images and reload collection
    if (self.categoryId != 0) {
        self.loadingImages = YES;
        [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

            // Set navigation bar buttons
            [self updateNavBar];

            self.loadingImages = NO;
            [self.imagesCollection reloadData];
        }];
    }
    else {
        if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
            [self.imagesCollection reloadData];
        }
    }
    
    // Refresh image collection if displayImageTitles option changed
    if (self.displayImageTitles != [Model sharedInstance].displayImageTitles) {
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
        if (self.categoryId != 0) {
            [self.albumData reloadAlbumOnCompletion:^{
                self.loadingImages = NO;
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            }];
        }
    }

    // Always open this view with a navigation bar and the search bar
    // (might have been hidden during Image Previewing)
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = false;
    }

    // Set navigation bar buttons
    [self updateNavBar];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    // Called after displaying SearchImagesViewController?
    UIViewController *presentedViewController = [self presentedViewController];
    if ([presentedViewController isKindOfClass:[UISearchController class]]) {
        // Scroll to image of interest if needed
        if ([self.searchController.searchResultsController isKindOfClass:[SearchImagesViewController class]]) {
            SearchImagesViewController *resultsController = (SearchImagesViewController *)self.searchController.searchResultsController;
            [resultsController scrollToHighlightedCell];
        }
        return;
    }
    
    // Refresh controller
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	refreshControl.backgroundColor = [UIColor piwigoBackgroundColor];
	refreshControl.tintColor = [UIColor piwigoOrange];
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoOrange],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Reload Images") attributes:attributes];
	[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.imagesCollection addSubview:refreshControl];
    self.imagesCollection.alwaysBounceVertical = YES;
    
    // Allows hiding search bar when scrolling
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = true;
    }

    // Should we scroll to image of interest?
//        NSLog(@"••• Starting with %ld images", (long)[self.imagesCollection numberOfItemsInSection:1]);
    if ((self.categoryId != 0) && ([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        
        // Not the root album, album contains images and thumbnail of interest is not the first one
        // => Scroll and highlight cell of interest
//        NSLog(@"=> Try to scroll to item=%ld in section=%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);

        // Thumbnail of interest already visible?
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is already visible and is highlighted
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
                }];
            } else {
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
            }
        }
        else {
            // Search for the first visible thumbnail
            NSIndexPath *indexPathOfFirstVisibleThumbnail = nil;
            for (NSInteger index = 0; index < [indexPathsForVisibleItems count]; index++) {
                if ([indexPathsForVisibleItems objectAtIndex:index].section == 1) {
                    indexPathOfFirstVisibleThumbnail = [indexPathsForVisibleItems objectAtIndex:index];
                    break;
                }
            }
            
            // Thumbnail of interest above visible items?
            if (self.imageOfInterest.item < indexPathOfFirstVisibleThumbnail.item) {
                // Scroll up collection and highlight cell
//                NSLog(@"=> Scroll to item #%ld in section #%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
            }
            
            // Thumbnail is below visible items
            // Get number of already loaded items
            NSInteger nberOfItems = [self.imagesCollection numberOfItemsInSection:1];
            if (self.imageOfInterest.item < nberOfItems) {
                // Already loaded => scroll to it
//                NSLog(@"=> Scroll to item #%ld in section #%ld", (long)self.imageOfInterest.item, (long)self.imageOfInterest.section);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
                
                // Calculate the number of thumbnails displayed per page
                NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.imagesCollection andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];

                // Load more images if seems to be a good idea
                if ((self.imageOfInterest.item > (nberOfItems - roundf(imagesPerPage / 3.0))) &&
                    (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])) {
//                    NSLog(@"=> Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
                    }];
                }
            } else {
                // No yet loaded => load more images
                // Should not happen as needToLoadMoreImages() should be called when previewing images
                if (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]) {
//                    NSLog(@"=> Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
                    }];
                }
            }
        }
    }

    // Replace iRate as from v2.1.5 (75) — See https://github.com/nicklockwood/iRate
    // Tells StoreKit to ask the user to rate or review the app, if appropriate.
//#if !defined(DEBUG)
//    if (NSClassFromString(@"SKStoreReviewController")) {
//        [SKStoreReviewController requestReview];
//    }
//#endif
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {

    // Highlight image which is now visible
    if ((self.categoryId != 0) && ([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
//        NSLog(@"=> Did end scrolling with %ld images", (long)[self.imagesCollection numberOfItemsInSection:1]);
        UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            [imageCell highlightOnCompletion:^{
                // Apply effect when returning from image preview mode
                self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
            }];
        } else {
           self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
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

    // Hide upload button during transition
    [self.uploadButton setHidden:YES];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 1)]];
    } completion:nil];
}

-(void)updateNavBar
{
    // For positioning the buttons
    CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
    CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;

    // Selection mode active ?
    if(!self.isSelect) {    // Image selection mode inactive
        
        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];

        // Title is name of the category
        if (self.categoryId == 0) {
            self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
        } else {
            self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
        }

        // User can upload images/videos if he/she has:
        // — admin rights
        // — upload access to the current category
        if ([Model sharedInstance].hasAdminRights ||
                [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // Show Upload button
            self.uploadButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
            [self.uploadButton setHidden:NO];
            
            // Show Home button if not in root or default album
            if ((self.categoryId == 0) ||
                (self.categoryId == [Model sharedInstance].defaultCategory))
            {
                // Hide Home button
                [self.homeAlbumButton setHidden:YES];
            }
            else {
                // Display Home button
                self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
                [self.homeAlbumButton setHidden:NO];
            }
        }
        else    // No upload rights => No Upload button
        {
            // Hide Upload button
            [self.uploadButton setHidden:YES];
            
            // Show navigation button if not in root or default album
            if ((self.categoryId == 0) ||
                (self.categoryId == [Model sharedInstance].defaultCategory)) {
                // Hide Home button
                [self.homeAlbumButton setHidden:YES];
            }
            else {
                // Display Home button
                self.homeAlbumButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
                [self.homeAlbumButton setHidden:NO];
            }
        }
        
        // Left side of navigation bar
        if ((self.categoryId == 0) ||
            (self.categoryId == [Model sharedInstance].defaultCategory)){
            // Button for accessing settings
            [self.navigationItem setLeftBarButtonItems:@[self.settingsBarButton] animated:YES];
            [self.navigationItem setHidesBackButton:YES];
        }
        else {
            // Back button to parent album
            [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
            [self.navigationItem setHidesBackButton:NO];
        }
        
        // Right side of navigation bar
        if (self.categoryId == 0) {
            // Root album => Discover menu button
            [self.navigationItem setRightBarButtonItems:@[self.discoverBarButton] animated:YES];
        }
        else if (self.albumData.images.count > 0) {
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
                self.title = NSLocalizedString(@"selectImages", @"Select Images");
                break;
                
            case 1:
                self.title = NSLocalizedString(@"selectImageSelected", @"1 Image Selected");
                break;
                
            default:
                self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Images Selected"), @(self.selectedImageIds.count)];
                break;
        }
        
        // Hide back, Settings, Upload and Home buttons
        [self.navigationItem setHidesBackButton:YES];
        [self.uploadButton setHidden:YES];
        [self.homeAlbumButton setHidden:YES];

        // User can delete images/videos if he/she has:
        // — admin rights
        if ([Model sharedInstance].hasAdminRights)
        {
            // Interface depends on device and orientation
            if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
                (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
                 ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
        
                // Hide navigation bar left buttons and use a toolbar
                [self.navigationItem setLeftBarButtonItems:@[] animated:YES];

                // Redefine bar buttons (definition lost after rotation of device)
                self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
                self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelected)];
                self.deleteBarButton.tintColor = [UIColor redColor];
                self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelected)];
                self.shareBarButton.tintColor = [UIColor piwigoOrange];
                self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImagesToCategory)];
                self.moveBarButton.tintColor = [UIColor piwigoOrange];

                // Present toolbar
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

                // Present buttons in the navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.shareBarButton, self.moveBarButton, self.deleteBarButton] animated:YES];
                self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
                self.deleteBarButton.enabled = (self.selectedImageIds.count > 0);
          }
        }
        else if ([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights])
        {
            // Interface depends on device and orientation
            if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) &&
                (([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeLeft) &&
                 ([[UIDevice currentDevice] orientation] != UIDeviceOrientationLandscapeRight))) {
                    
                    // Hide navigation bar left buttons and use a toolbar
                    [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
                    
                    // Redefine bar buttons (definition lost after rotation of device)
                    self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
                    self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelected)];
                    self.shareBarButton.tintColor = [UIColor piwigoOrange];
                    self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImagesToCategory)];
                    self.moveBarButton.tintColor = [UIColor piwigoOrange];
                    
                    // Present toolbar
                    [self.navigationController setToolbarHidden:NO animated:YES];
                    self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton];
                    self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                    self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
                }
            else    // iPhone in landscape mode, iPad in any orientation
            {
                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
                
                // Present buttons in the navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.shareBarButton, self.moveBarButton] animated:YES];
                self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
                self.moveBarButton.enabled = (self.selectedImageIds.count > 0);
            }
        }
        else    // No rights => No toolbar, only download button
        {
            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];

            // Present buttons in the navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.shareBarButton] animated:YES];
            self.shareBarButton.enabled = (self.selectedImageIds.count > 0);
        }
        
        // Right side of navigation bar
        [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
    }
}


#pragma mark - Category Data

-(void)getCategoryData:(NSNotification *)notification
{
    // Reload category data
//    NSLog(@"getCategoryData => getAlbumListForCategory(%ld,%d,%d)", (long)self.categoryId,([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit),[Model sharedInstance].loadAllCategoryInfo);

    // Display HUD if requested
    BOOL noHUD = NO;
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;
        noHUD = [[userInfo objectForKey:@"NoHUD"] boolValue];
    }
    if (!([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit) && !noHUD) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    }
    
    // Disable cache if requested
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;
        self.isCachedAtInit = [[userInfo objectForKey:@"fromCache"] boolValue];
    }

    // Load category data
    [AlbumService getAlbumListForCategory:self.categoryId
                               usingCache:([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit)
                          inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 self.isCachedAtInit = YES;
                                 [self.imagesCollection reloadData];

                                 // Hide loading HUD
                                 [self hideHUD];
                            }
                                onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                    NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                    // Hide loading HUD
                                    [self hideHUD];
                                }
     ];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
//    NSLog(@"refreshControl => getAlbumListForCategory(%ld,NO,NO)", [Model sharedInstance].loadAllCategoryInfo ? (long)0 : (long)self.categoryId);

    // Show loading HD
    [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];

    [AlbumService getAlbumListForCategory:[Model sharedInstance].loadAllCategoryInfo ? 0 : self.categoryId
                               usingCache:NO
                          inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [self.imagesCollection reloadData];

                                 if (refreshControl) [refreshControl endRefreshing];

                                 // Hide loading HUD
                                 [self hideHUD];
                             
                             }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                                 if (refreshControl) [refreshControl endRefreshing];

                                 // Hide loading HUD
                                 [self hideHUD];
                             }
     ];
}

-(void)refreshShowingCells
{
//    NSLog(@"refreshShowingCells…");
    NSArray *categories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId];

    for(UICollectionViewCell *cell in self.imagesCollection.visibleCells)
    {
        // Get indexPath for visible cell in collection
        NSIndexPath *indexPath = [self.imagesCollection indexPathForCell:cell];
        
        // Case of a category
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            if ([categories count] > indexPath.row) {
                PiwigoAlbumData *albumData = [categories objectAtIndex:indexPath.row];
                CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
                [categoryCell setupWithAlbumData:albumData];
            }
        }

        // Case of an image
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            if ([self.albumData.images count] > indexPath.row) {
                PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell setupWithImageData:imageData forCategoryId:self.categoryId];

                if([self.selectedImageIds containsObject:[NSString stringWithFormat:@"%ld", (long)imageData.imageId]])
                {
                    imageCell.isSelected = YES;
                }
            }
        }
    }
    
    // Refresh headers on palette color change
    if (self.imagesCollection.visibleCells.count > 0) {
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,2)]];
    }
}

-(void)categoriesUpdated
{
//    NSLog(@"=> categoriesUpdated… %ld", self.categoryId);

    // Images ?
    if (self.categoryId != 0) {
        self.loadingImages = YES;
        [self.albumData loadAllImagesOnCompletion:^{

             // Sort images
             [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{
//                 NSLog(@"categoriesUpdated:Sorting images…");

                 // The album title is not shown in backButtonItem to provide enough space
                 // for image title on devices of screen width <= 414 ==> Restore album title
                 self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
                
                 // Set navigation bar buttons
                 [self updateNavBar];

                 // Reload collection view
                 self.loadingImages = NO;
                 [self.imagesCollection reloadData];
//                 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            }];
        }];
    }
     else {
         // The album title is not shown in backButtonItem to provide enough space
         // for image title on devices of screen width <= 414 ==> Restore album title
         self.title = NSLocalizedString(@"tabBar_albums", @"Albums");

         // Set navigation bar buttons
         [self updateNavBar];

         // Reload collection view
         [self.imagesCollection reloadData];
     }
}

#pragma mark - Default Category Management

-(void)returnToDefaultCategory
{
    // Does the default album view controller already exists?
    NSInteger cur = 0, index = 0;
    AlbumImagesViewController *rootAlbumViewController = nil;
    for (UIViewController *viewController in self.navigationController.viewControllers) {
        
        // Look for AlbumImagesViewControllers
        if ([viewController isKindOfClass:[AlbumImagesViewController class]]) {
            AlbumImagesViewController *thisViewController = (AlbumImagesViewController *) viewController;
            
            // Is this the view controller of the default album?
            if (thisViewController.categoryId == [Model sharedInstance].defaultCategory) {
                // The view controller of the parent category already exist
                rootAlbumViewController = thisViewController;
            }
            
            // Is this the current view controller?
            if (thisViewController.categoryId == self.categoryId) {
                // This current view controller will become the child view controller
                index = cur;
            }
        }
        cur++;
    }
    
    // The view controller of the default album does not exist yet
    if (!rootAlbumViewController) {
        rootAlbumViewController = [[AlbumImagesViewController alloc] initWithAlbumId:[Model sharedInstance].defaultCategory inCache:NO];
        NSMutableArray *arrayOfVC = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
        [arrayOfVC insertObject:rootAlbumViewController atIndex:index];
        self.navigationController.viewControllers = arrayOfVC;
    }
    
    // Present the root album
    [self.navigationController popToViewController:rootAlbumViewController animated:YES];
}


#pragma mark - Display Preferences / Upload views

-(void)displayPreferences
{
    SettingsViewController *settingsViewController = [SettingsViewController new];
    settingsViewController.title = NSLocalizedString(@"tabBar_preferences", @"Preferences");

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navController animated:YES completion:nil];
}

-(void)displayUpload
{
    CategoryPickViewController *addViewController = [[CategoryPickViewController alloc] initWithCategoryId:self.categoryId];
    addViewController.title = NSLocalizedString(@"alertAddButton", @"Add");

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:addViewController];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navController animated:YES completion:nil];
}


#pragma mark - Select Images

-(void)select
{
    if (!self.isSelect) {
        
        // Activate Images Selection mode
        self.isSelect = YES;
        
        // Disable interaction with category cells and scroll to first image cell if needed
        NSInteger numberOfImageCells = 0;
        for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {

            // Disable user interaction with category cell
            if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
                CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
                [categoryCell setAlpha:0.5];
                [categoryCell setUserInteractionEnabled:NO];
            }

            // Will scroll to position if no visible image cell
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                numberOfImageCells++;
            }
        }

        // Scroll to position of images if needed
        if (!numberOfImageCells)
            [self.imagesCollection scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
        
        // Refresh collection view
        [self.imagesCollection reloadData];
    }
    
    // Update navigation bar
    [self updateNavBar];
}

-(void)cancelSelect
{
	// Disable Images Selection mode
    self.isSelect = NO;
    
    // Update navigation bar
	[self updateNavBar];
    
    // Enable interaction with category cells and deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Enable user interaction with category cell
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
            [categoryCell setAlpha:1.0];
            [categoryCell setUserInteractionEnabled:YES];
        }
        
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
    
    // Refresh collection view
    [self.imagesCollection reloadData];
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
        if ((indexPath.section != 1) || (indexPath.row == NSNotFound)) return;
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
                [self.imagesCollection reloadData];
                [self updateNavBar];
            }
        }
    }
    
    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImageIds = [NSMutableArray new];
    }
}


#pragma mark - Upload images

-(void)uploadToThisCategory
{
	LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:self.categoryId];
	[self.navigationController pushViewController:localAlbums animated:YES];
}


#pragma mark - Delete images

-(void)deleteSelected
{
    if(self.selectedImageIds.count <= 0) return;
    
    // Display HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
    });
    
    // Retrieve image data
    self.selectedImagesToDelete = [NSMutableArray new];
    self.selectedImagesToRemove = [NSMutableArray new];
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
          ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {

              if (imageData != nil) {
                  // Split orphaned and non-orphaned images
                  if (imageData.categoryIds.count > 1) {
                      [self.selectedImagesToRemove addObject:imageData];
                  }
                  else {
                      [self.selectedImagesToDelete addObject:imageData];
                  }
              
                  // Next image
                  [self.selectedImageIdsToDelete removeLastObject];
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
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)askDeleteConfirmation
{
    NSString *messageString;
    NSInteger totalNberToDelete = self.selectedImagesToDelete.count + self.selectedImagesToRemove.count;
    // Alert message
    if (totalNberToDelete > 1) {
        messageString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_message", @"Are you sure you want to delete the selected %@ images?"), @(totalNberToDelete)];
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
        handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* removeImagesAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"deleteCategory_orphanedImages", @"Delete Orphans")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {

            // Display HUD during server update
            self.totalNumberOfImages = self.selectedImagesToRemove.count
                                     + (self.selectedImagesToDelete.count > 0);
            if (self.totalNumberOfImages > 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…") inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:NO];
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") inMode:MBProgressHUDModeIndeterminate withDetailLabel:NO];
                });
            }

            // Start removing images
            [self removeImages];
        }];

    UIAlertAction* deleteImagesAction = [UIAlertAction
        actionWithTitle:totalNberToDelete > 1 ? [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_title", @"Delete %@ Images"), @(totalNberToDelete)] : NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            
            [self.selectedImagesToDelete addObjectsFromArray:self.selectedImagesToRemove];

            // Display HUD during server update
            self.totalNumberOfImages = self.selectedImagesToDelete.count;
            if (self.selectedImagesToDelete.count > 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showHUDwithTitle:NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…") inMode:MBProgressHUDModeAnnularDeterminate withDetailLabel:NO];
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
    if (self.selectedImagesToRemove.count > 0) { [alert addAction:removeImagesAction]; }
    [alert addAction:deleteImagesAction];

    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)removeImages
{
    if (self.selectedImagesToRemove.count <= 0)
    {
        if (self.selectedImagesToDelete.count <= 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideHUDwithSuccess:YES completion:^{
                    [self cancelSelect];
                }];
            });
        }
        else {
            [self deleteImages];
        }
        return;
    }
    
    // Update image category list
    self.selectedImage = [self.selectedImagesToRemove lastObject];
    NSMutableArray *categoryIds = [self.selectedImage.categoryIds mutableCopy];
    [categoryIds removeObject:@(self.categoryId)];
    
    // Let's remove the image from current category
    [ImageService setCategoriesForImage:self.selectedImage
         withCategories:categoryIds
             onProgress:nil
           OnCompletion:^(NSURLSessionTask *task, BOOL updatedSuccessfully) {
               if (updatedSuccessfully)
               {
                   // Remove image from current category
                   [self.albumData removeImageWithId:self.selectedImage.imageId];
                   [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)self.selectedImage.imageId]];
                   [self.imagesCollection reloadData];

                   // Update cache
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] removeImages:@[self.selectedImage]];
                   [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] deincrementImageSizeByOne];

                   // Next image
                   [self.selectedImagesToRemove removeLastObject];
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [MBProgressHUD HUDForView:self.hudViewController.view].progress = 1.0 - (double)(self.selectedImagesToRemove.count + self.selectedImagesToDelete.count) / self.totalNumberOfImages;
                   });
                   [self removeImages];
               }
                else {
                    // Update album view if image moved
                    // Error — Try again ?
                    UIAlertController* alert = [UIAlertController
                        alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                        message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")]
                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction* dismissAction = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                        style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction * action) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self hideHUDwithSuccess:NO completion:nil];
                            });
                        }];
                    
                    UIAlertAction* retryAction = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                       style:UIAlertActionStyleDestructive
                       handler:^(UIAlertAction * action) {
                           [self removeImages];
                       }];
                    
                    // Add actions
                    [alert addAction:dismissAction];
                    [alert addAction:retryAction];
                    
                    // Present list of actions
                    [self presentViewController:alert animated:YES completion:nil];
                }
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
                              [self hideHUDwithSuccess:NO completion:nil];
                          });
                      }];
                  
                  UIAlertAction* retryAction = [UIAlertAction
                     actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                     style:UIAlertActionStyleDestructive
                     handler:^(UIAlertAction * action) {
                         [self removeImages];
                     }];
                  
                  // Add actions
                  [alert addAction:dismissAction];
                  [alert addAction:retryAction];
                  
                  // Present list of actions
                  [self presentViewController:alert animated:YES completion:nil];
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
                  
                  // Images deleted
                  for (PiwigoImageData *selectedImage in self.selectedImagesToDelete) {
                      [self.albumData removeImageWithId:selectedImage.imageId];
                      [self.selectedImageIds removeObject:[NSString stringWithFormat:@"%ld", (long)selectedImage.imageId]];
                  }
                  
                  // Reload collection
                  [self.imagesCollection reloadData];

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
                                    [self hideHUDwithSuccess:NO completion:nil];
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
                        [self presentViewController:alert animated:YES completion:nil];
                    }];
}


#pragma mark - Share images

-(void)shareSelected
{
    if (self.selectedImageIds.count <= 0) return;

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
                  ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      
                      if (imageData != nil) {
                          // Store image data
                          [self.selectedImagesToShare addObject:imageData];
                          
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
            } else {
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
    // Determine index of first selected cell
    NSInteger indexOfFirstSelectedImage = INFINITY;
    for (NSNumber *imageId in self.selectedImageIds) {
        NSInteger obj1 = [imageId integerValue];
        NSInteger index = 0;
        for (PiwigoImageData *image in self.albumData.images) {
            NSInteger obj2 = image.imageId;
            if (obj1 == obj2) break;
            index++;
        }
        indexOfFirstSelectedImage = MIN(index, indexOfFirstSelectedImage);
    }

    // Present alert to user
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:nil message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* copyAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
                                     MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:self.selectedImageIds orSingleImageData:nil inCategoryId:self.categoryId atIndex:indexOfFirstSelectedImage andCopyOption:YES];
                                     moveImageVC.moveImagesDelegate = self;
                                     [self pushView:moveImageVC];
                                 }];
    
    UIAlertAction* moveAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
                                     MoveImageViewController *moveImageVC = [[MoveImageViewController alloc] initWithSelectedImageIds:self.selectedImageIds orSingleImageData:nil inCategoryId:self.categoryId atIndex:indexOfFirstSelectedImage andCopyOption:NO];
                                     moveImageVC.moveImagesDelegate = self;
                                     [self pushView:moveImageVC];
                                 }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [alert addAction:moveAction];
    
    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.moveBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - UICollectionView Headers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:     // Section 0 — Album collection
        {
            CategoryHeaderReusableView *header = nil;
            
            if (kind == UICollectionElementKindSectionHeader) {
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader" forIndexPath:indexPath];
                PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
                if ([albumData.comment length] > 0) {
                    header.commentLabel.text = albumData.comment;
                }
                header.commentLabel.textColor = [UIColor piwigoHeaderColor];
                return header;
            }
            break;
        }
            
        default:    // Section 1 — Image collection
        {
            // Display "No Images" except in root album
            NoImagesHeaderCollectionReusableView *header = nil;
            
            if(kind == UICollectionElementKindSectionHeader)
            {
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"NoImagesHeaderCollection" forIndexPath:indexPath];
                header.noImagesLabel.textColor = [UIColor piwigoHeaderColor];

                if (self.categoryId == 0) {
                    // Only albums in Root Album
                    header.noImagesLabel.text = @"";
                }
                else if (self.albumData.images.count == 0) {
                    // Still loading images…
                    if (self.loadingImages) {
                        // Currently trying to load images…
                        header.noImagesLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
                    }
                    else if (self.categoryId != 0) {
                        // Not loading —> No images
                        header.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
                    }
                }
                return header;
            }
            break;
        }
    }

	UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
	return view;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:     // Section 0 — Album collection
        {
            // Header height?
            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
            if ([albumData.comment length] > 0) {
                NSString *header = albumData.comment;
                NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
                NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
                context.minimumScaleFactor = 1.0;
                CGRect headerRect = [header boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:attributes
                                                         context:context];
                return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(headerRect.size.height));
            }
            break;
        }
        default:    // Section 1 — Image collection
        {
            NSString *header = @"";
            if (self.categoryId == 0) {
                // Only albums in Root Album
                header = @"";
            }
            else if (self.albumData.images.count == 0) {
                // Still loading images…
                if (self.loadingImages) {
                    // Currently trying to load images…
                    header = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
                }
                else if (self.categoryId != 0) {
                    // Not loading —> No images
                    header = NSLocalizedString(@"noImages", @"No Images");
                }
            }
 
            if ([header length] > 0) {
                NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
                NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
                context.minimumScaleFactor = 1.0;
                CGRect headerRect = [header boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:attributes
                                                         context:context];
                return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(headerRect.size.height));
            }
            break;
        }
    }

    return CGSizeZero;
}


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return 2;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images or albums
    NSInteger numberOfItems;
    switch (section) {
        case 0:             // Albums
            numberOfItems = [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
            break;
            
        default:            // Images
            numberOfItems = self.albumData.images.count;
            break;
    }
    return numberOfItems;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    switch (section) {
        case 0:             // Albums
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
            } else {
                return UIEdgeInsetsMake(10, kAlbumMarginsSpacing, 10, kAlbumMarginsSpacing);
            }
            break;
            
        default:            // Images
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kImageMarginsSpacing, 0, kImageMarginsSpacing);
            } else {
                return UIEdgeInsetsMake(10, kImageMarginsSpacing, 10, kImageMarginsSpacing);
            }
            break;
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return 0.0;
            break;
            
        default:            // Images
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                return (CGFloat)kImageCellSpacing4iPhone;
            } else {
                return (CGFloat)kImageCellVertSpacing4iPad;
            }
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return (CGFloat)kAlbumCellSpacing;
            break;
            
        default:            // Images
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                return (CGFloat)kImageCellSpacing4iPhone;
            } else {
                return (CGFloat)kImageCellHorSpacing4iPad;
            }
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums (see XIB file)
        {
            float nberAlbumsPerRow = [ImagesCollection numberOfAlbumsPerRowForViewInPortrait:collectionView withMaxWidth:384];
            CGFloat size = (CGFloat)[ImagesCollection albumSizeForView:collectionView andNberOfAlbumsPerRowInPortrait:nberAlbumsPerRow];
            return CGSizeMake(size, 156.5);
            break;
        }
            
        default:            // Images
        {
            // Calculate the optimum image size
            CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
            return CGSizeMake(size, size);
        }
    }
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums (see XIB file)
        {
            CategoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CategoryCollectionViewCell" forIndexPath:indexPath];
            cell.categoryDelegate = self;
            
            PiwigoAlbumData *albumData = [[[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId] objectAtIndex:indexPath.row];
            [cell setupWithAlbumData:albumData];
            
            // Disable category cells in Image selection mode
            if (self.isSelect) {
                [cell setAlpha:0.5];
                [cell setUserInteractionEnabled:NO];
            } else {
                [cell setAlpha:1.0];
                [cell setUserInteractionEnabled:YES];
            }
            
            return cell;
            break;
        }
            
        default:            // Images
        {
            ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
            
            if (self.albumData.images.count > indexPath.row) {
                // Create cell from Piwigo data
                PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
//                NSLog(@"Index:%ld => image ID:%@ - %@", indexPath.row, imageData.imageId, imageData.name);
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
            NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
            
            // Load image data in advance if possible (page after page…)
            if ((indexPath.row > fmaxf(roundf(2 * imagesPerPage / 3.0), [collectionView numberOfItemsInSection:1] - roundf(imagesPerPage / 3.0))) &&
                (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
            {
                [self.albumData loadMoreImagesOnCompletion:^{
                    [self.imagesCollection reloadData];
                }];
            }
            
            return cell;
        }
    }
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums
            break;
            
        default:            // Images
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
                [collectionView reloadData];
                
                // and display nav buttons
                [self updateNavBar];
            }
        }
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
        hud.contentColor = [UIColor piwigoHudContentColor];
        hud.bezelView.color = [UIColor piwigoHudBezelViewColor];
        
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


#pragma mark - ImageDetailDelegate Methods

-(void)didFinishPreviewOfImageWithId:(NSInteger)imageId
{
    NSInteger index = 0;
    for (PiwigoImageData *image in self.albumData.images) {
        if (image.imageId == imageId) break;
        index++;
    }
    if (index < [self.albumData.images count])
        self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    [self.albumData removeImage:image];
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
    [self.imagesCollection reloadData];
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


#pragma mark - MoveImagesDelegate methods

-(void)didRemoveImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    [self.albumData removeImage:image];
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
    [self.imagesCollection reloadData];
}

-(void)deselectImages
{
    [self cancelSelect];
}


#pragma mark - CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	self.currentSortCategory = sortType;
    [self.albumData updateImageSort:sortType OnCompletion:^{
//        NSLog(@"didSelectCategorySortType:Sorting images…");
        [self.imagesCollection reloadData];
    }];
}


#pragma mark - CategoryCollectionViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
    if (([viewController isKindOfClass:[AlbumImagesViewController class]]) ||
        ([viewController isKindOfClass:[DiscoverImagesViewController class]])) {
        // Push sub-album view
        [self.navigationController pushViewController:viewController animated:YES];
    }
    else if (([viewController isKindOfClass:[MoveCategoryViewController class]]) ||
             ([viewController isKindOfClass:[MoveImageViewController class]]) ||
             ([viewController isKindOfClass:[TagSelectViewController class]])) {
        // Present album list for moving current album or images, for selecting a tag
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
            [navController.popoverPresentationController setPermittedArrowDirections:0];
            [navController.popoverPresentationController setSourceRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0)];
        } else {
            navController.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        [self presentViewController:navController animated:YES completion:nil];
    }
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
                       [topViewController presentViewController:alert animated:YES completion:nil];
                   });
}


#pragma mark - UISearchControllerDelegate

- (void)willPresentSearchController:(UISearchController *)searchController
{
    // Unregister category data updates
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCategoryDataUpdated object:nil];
}

- (void)didDismissSearchController:(UISearchController *)searchController
{
    // Register category data updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
}


#pragma mark - UISearchResultsUpdating

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    
    // Query string
    NSString *searchString = [self.searchController.searchBar text];
    
    // Resfresh image collection for new query only
    if ([searchController.searchResultsController isKindOfClass:[SearchImagesViewController class]]) {
        SearchImagesViewController *resultsController = (SearchImagesViewController *)searchController.searchResultsController;
        
        if (![resultsController.searchQuery isEqualToString:searchString] || !searchString.length) {
            
            // Initialise search cache
            PiwigoAlbumData *searchAlbum = [[PiwigoAlbumData alloc] initSearchAlbumForQuery:searchString];
            [[CategoriesData sharedInstance] updateCategories:@[searchAlbum]];
            
            // Resfresh image collection
            resultsController.searchQuery = searchString;
            [resultsController searchAndLoadImages];
        }
    }
}


#pragma mark - UISearchBarDelegate

// Workaround for bug: -updateSearchResultsForSearchController: is not called when scope buttons change
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self updateSearchResultsForSearchController:self.searchController];
}


#pragma mark - Discover images

// Create Discover images view i.e. Most visited, Best rated, etc.
-(void)discoverImages
{
    // Do we really want to delete these images?
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:nil
        message:NSLocalizedString(@"categoryDiscover_title", @"Discover")
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
       style:UIAlertActionStyleCancel
       handler:^(UIAlertAction * action) {}];

    UIAlertAction* tagSelectorAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"tags", @"Tags")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show tags for selecting images
            [self discoverImagesByTag];
         }];
    
    UIAlertAction* mostVisitedAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverVisits_title", @"Most visited")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show most visited images
            [self discoverImagesInCategoryId:kPiwigoVisitsCategoryId];
         }];
    
    UIAlertAction* bestRatedAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"categoryDiscoverBest_title", @"Best rated")
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction * action) {
              // Show best rated images
              [self discoverImagesInCategoryId:kPiwigoBestCategoryId];
          }];

    UIAlertAction* recentAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverRecent_title", @"Recent photos")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
          // Show best rated images
          [self discoverImagesInCategoryId:kPiwigoRecentCategoryId];
        }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:tagSelectorAction];
    [alert addAction:mostVisitedAction];
    [alert addAction:bestRatedAction];
    [alert addAction:recentAction];
    
    // Present list of Discover views
    alert.popoverPresentationController.barButtonItem = self.discoverBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)discoverImagesInCategoryId:(NSInteger)categoryId
{
    // Create Discover view
    DiscoverImagesViewController *discoverController = [[DiscoverImagesViewController alloc] initWithCategoryId:categoryId];
    [self pushView:discoverController];
}

-(void)discoverImagesByTag
{
    // Push tag select view
    TagSelectViewController *discoverController = [[TagSelectViewController alloc] init];
    discoverController.tagSelectDelegate = self;
    [self pushView:discoverController];
}


#pragma mark - TagSelectViewDelegate Methods

-(void)pushTaggedImagesView:(UIViewController *)viewController
{
    // Push sub-album view
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
