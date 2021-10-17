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
#import "CategoriesData.h"
#import "CategoryCollectionViewCell.h"
#import "DiscoverImagesViewController.h"
#import "FavoritesImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"
#import "NetworkHandler.h"
#import "SearchImagesViewController.h"

//#ifndef DEBUG_LIFECYCLE
//#define DEBUG_LIFECYCLE
//#endif

CGFloat const kRadius = 25.0;
CGFloat const kDeg2Rad = 3.141592654 / 180.0;
NSString * const kPiwigoNotificationBackToDefaultAlbum = @"kPiwigoNotificationBackToDefaultAlbum";
NSString * const kPiwigoNotificationUploadedImage = @"kPiwigoNotificationUploadedImage";
NSString * const kPiwigoNotificationRemovedImage = @"kPiwigoNotificationRemovedImage";
NSString * const kPiwigoNotificationChangedAlbumData = @"kPiwigoNotificationChangedAlbumData";

NSString * const kPiwigoNotificationDidShare = @"kPiwigoNotificationDidShare";
NSString * const kPiwigoNotificationCancelDownload = @"kPiwigoNotificationCancelDownload";

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIToolbarDelegate, UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate, UITextFieldDelegate, UIScrollViewDelegate, ImageDetailDelegate, EditImageParamsDelegate, CategoryCollectionViewCellDelegate, SelectCategoryDelegate, SelectCategoryImageCopiedDelegate, ShareImageActivityItemProviderDelegate, TagSelectorViewDelegate, ChangedSettingsDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL isCachedAtInit;
@property (nonatomic, assign) kPiwigoSortObjc currentSort;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, assign) BOOL userHasUploadRights;

@property (nonatomic, strong) UIBarButtonItem *settingsBarButton;
@property (nonatomic, strong) UIBarButtonItem *discoverBarButton;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *spaceBetweenButtons;
@property (nonatomic, strong) UIBarButtonItem *actionBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *shareBarButton;
@property (nonatomic, strong) UIBarButtonItem *moveBarButton;
@property (nonatomic, strong) UIBarButtonItem *favoriteBarButton;

@property (nonatomic, strong) UIMenu *albumMenu                 API_AVAILABLE(ios(14.0));
@property (nonatomic, strong) UIAction *imagesCopyAction        API_AVAILABLE(ios(14.0));
@property (nonatomic, strong) UIAction *imagesMoveAction        API_AVAILABLE(ios(14.0));
@property (nonatomic, strong) UIMenu *imagesMenu                API_AVAILABLE(ios(14.0));
@property (nonatomic, strong) UIAction *editParamsAction        API_AVAILABLE(ios(14.0));

@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *createAlbumButton;
@property (nonatomic, strong) UIButton *uploadImagesButton;
@property (nonatomic, strong) UIAlertAction *createAlbumAction;
@property (nonatomic, strong) UIButton *homeAlbumButton;
@property (nonatomic, strong) UIButton *uploadQueueButton;
@property (nonatomic, strong) UILabel *nberOfUploadsLabel;
@property (nonatomic, strong) CAShapeLayer* progressLayer;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIds;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *touchedImageIds;

@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToEdit;
@property (nonatomic, strong) NSMutableArray *selectedImagesToEdit;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToDelete;
@property (nonatomic, strong) NSMutableArray *selectedImagesToRemove;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToShare;
@property (nonatomic, strong) NSMutableArray *selectedImagesToShare;
@property (nonatomic, strong) PiwigoImageData *selectedImage;

@property (nonatomic, strong) UIRefreshControl *refreshControl;     // iOS 9.x only

@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached
{
    self = [super init];
	if(self)
	{
		self.categoryId = albumId;
        self.isCachedAtInit = isCached;
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:1];
        
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];
		self.currentSort = (kPiwigoSortObjc)AlbumVars.defaultSort;
        self.displayImageTitles = AlbumVars.displayImageTitles;
		
        // Initialise selection mode
        self.isSelect = NO;
        self.touchedImageIds = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];

        // For iOS 11 and later: place search bar in navigation bar for root album
        if (@available(iOS 11.0, *)) {
            // Initialise search controller when displaying root album
            if (albumId == 0) {
                SearchImagesViewController *resultsCollectionController = [[SearchImagesViewController alloc] init];
                UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:resultsCollectionController];
                searchController.delegate = self;
                searchController.hidesNavigationBarDuringPresentation = YES;
                searchController.searchResultsUpdater = self;
                
                searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
                searchController.searchBar.translucent = NO;
                searchController.searchBar.showsCancelButton = NO;
                searchController.searchBar.showsSearchResultsButton = NO;
                searchController.searchBar.tintColor = [UIColor piwigoColorOrange];
                searchController.searchBar.delegate = self;        // Monitor when the search button is tapped.
                self.definesPresentationContext = YES;
                
                // Place the search bar in the navigation bar.
                self.navigationItem.searchController = searchController;

                // Hide the search bar when scrolling
                self.navigationItem.hidesSearchBarWhenScrolling = true;
            }
        }

        // Navigation bar and toolbar buttons
        self.settingsBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings"] landscapeImagePhone:[UIImage imageNamed:@"settingsCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(didTapPreferencesButton)];
        [self.settingsBarButton setAccessibilityIdentifier:@"settings"];
        self.discoverBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"action"] landscapeImagePhone:[UIImage imageNamed:@"actionCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(discoverImages)];
        [self.discoverBarButton setAccessibilityIdentifier:@"discover"];

        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(didTapSelect)];
        [self.selectBarButton setAccessibilityIdentifier:@"Select"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        
        // Toolbar
        self.navigationController.toolbarHidden = YES;
//        self.spaceBetweenButtons = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
//        self.editBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editSelection)];
//        [self.editBarButton setAccessibilityIdentifier:@"edit"];
//        self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelection)];
//        self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelection)];
//        self.shareBarButton.tintColor = [UIColor piwigoColorOrange];
        self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImagesToCategory)];
        self.moveBarButton.tintColor = [UIColor piwigoColorOrange];
        
        // Albums related Actions & Menus
        if (@available(iOS 14.0, *)) {
            // Copy images to album
            self.imagesCopyAction = [UIAction actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album") image:[UIImage systemImageNamed:@"rectangle.stack.badge.plus"] identifier:@"Copy" handler:^(__kindof UIAction * _Nonnull action) {
                
                // Disable buttons during action
                [self setEnableStateOfButtons:NO];
                
                // Present album selector for copying image
                UIStoryboard *copySB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
                SelectCategoryViewController *copyVC = [copySB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
                NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(self.categoryId), nil];
                [copyVC setInputWithParameter:parameter for:kPiwigoCategorySelectActionCopyImages];
                copyVC.delegate = self;                 // To re-enable toolbar
                copyVC.imageCopiedDelegate = self;      // To update image data after copy
                [self pushView:copyVC];
            }];

            // Move images to album
            self.imagesMoveAction = [UIAction actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album") image:[UIImage systemImageNamed:@"arrowshape.turn.up.right"] identifier:@"Move" handler:^(__kindof UIAction * _Nonnull action) {
                // Disable buttons during action
                [self setEnableStateOfButtons:NO];
                
                // Present album selector for copying image
                UIStoryboard *moveSB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
                SelectCategoryViewController *moveVC = [moveSB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
                NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(self.categoryId), nil];
                [moveVC setInputWithParameter:parameter for:kPiwigoCategorySelectActionMoveImages];
                moveVC.delegate = self;         // To re-enable toolbar
                [self pushView:moveVC];
            }];

            // Menu
            self.albumMenu = [UIMenu menuWithTitle:@"" image:nil identifier:@"org.piwigo.piwigoImage.album" options:UIMenuOptionsDisplayInline children:@[self.imagesCopyAction, self.imagesMoveAction]];
            } else {
        }
        
        // Images related Actions & Menus
        if (@available(iOS 14.0, *)) {
            // Edit image parameters
            self.editParamsAction = [UIAction actionWithTitle:NSLocalizedString(@"imageOptions_properties", @"Modify Information") image:[UIImage systemImageNamed:@"pencil"] identifier:@"Edit Parameters" handler:^(__kindof UIAction * _Nonnull action) {
                // Edit image informations
                [self editSelection];
            }];
            
            // Menu
            self.imagesMenu = [UIMenu menuWithTitle:@"" image:nil identifier:@"org.piwigo.piwigoImage.edit" options:UIMenuOptionsDisplayInline children:@[self.editParamsAction]];
        }
        
        // Collection of images
        self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
        self.imagesCollection.dataSource = self;
        self.imagesCollection.delegate = self;

        // Refresh view
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
        if (@available(iOS 10.0, *)) {
            self.imagesCollection.refreshControl = refreshControl;
        } else {
            // Fallback on earlier versions
            self.refreshControl = refreshControl;
        }

        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
        [self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"CategoryCollectionViewCell"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CategoryHeader"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        [self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // "Add" button above collection view and other buttons
        self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
        CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
        self.addButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
        self.addButton.layer.cornerRadius = kRadius;
        self.addButton.layer.masksToBounds = NO;
        [self.addButton.layer setOpacity:0.0];
        [self.addButton.layer setShadowOpacity:0.8];
        self.addButton.backgroundColor = [UIColor piwigoColorOrange];
        self.addButton.tintColor = [UIColor whiteColor];
        self.addButton.showsTouchWhenHighlighted = YES;
        if (self.categoryId == 0) {
            [self.addButton setImage:[UIImage imageNamed:@"createLarge"] forState:UIControlStateNormal];
        } else {
            [self.addButton setImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
        }
        [self.addButton addTarget:self action:@selector(didTapAddButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.addButton.hidden = YES;
        [self.addButton setAccessibilityIdentifier:@"add"];
        [self.view addSubview:self.addButton];

        // "Upload Queue" button above collection view
        self.uploadQueueButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.uploadQueueButton.frame = self.addButton.frame;
        self.uploadQueueButton.layer.cornerRadius = kRadius;
        self.uploadQueueButton.layer.masksToBounds = NO;
        [self.uploadQueueButton.layer setShadowOpacity:0.8];
        self.uploadQueueButton.showsTouchWhenHighlighted = YES;
        [self.uploadQueueButton addTarget:self action:@selector(didTapUploadQueueButton)
                    forControlEvents:UIControlEventTouchUpInside];
        self.uploadQueueButton.hidden = YES;
        self.uploadQueueButton.backgroundColor = [UIColor clearColor];

        self.progressLayer = [[CAShapeLayer alloc] init];
        self.progressLayer.fillColor = [[UIColor clearColor] CGColor];
        self.progressLayer.frame = CGRectMake(0, 0, 2*kRadius, 2*kRadius);
        self.progressLayer.lineWidth = 3;
        self.progressLayer.strokeStart = 0;
        self.progressLayer.strokeEnd = 0;
        [self.uploadQueueButton.layer addSublayer:self.progressLayer];

        self.nberOfUploadsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.nberOfUploadsLabel.text = @"";
        self.nberOfUploadsLabel.font = [UIFont fontWithName:@"OpenSans-Semibold" size:24.0];
        self.nberOfUploadsLabel.adjustsFontSizeToFitWidth = NO;
        self.nberOfUploadsLabel.textAlignment = NSTextAlignmentCenter;
        self.nberOfUploadsLabel.backgroundColor = [UIColor clearColor];
        [self.uploadQueueButton addSubview:self.nberOfUploadsLabel];
        [self.view insertSubview:self.uploadQueueButton belowSubview:self.addButton];

        // "Home" album button above collection view
        self.homeAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.homeAlbumButton.frame = self.addButton.frame;
        self.homeAlbumButton.layer.cornerRadius = kRadius;
        self.homeAlbumButton.layer.masksToBounds = NO;
        [self.homeAlbumButton.layer setOpacity:0.0];
        [self.homeAlbumButton.layer setShadowOpacity:0.8];
        self.homeAlbumButton.showsTouchWhenHighlighted = YES;
        [self.homeAlbumButton setImage:[UIImage imageNamed:@"rootAlbum"] forState:UIControlStateNormal];
        [self.homeAlbumButton addTarget:self action:@selector(returnToDefaultCategory)
                    forControlEvents:UIControlEventTouchUpInside];
        self.homeAlbumButton.hidden = YES;
        [self.view insertSubview:self.homeAlbumButton belowSubview:self.addButton];

        // "Create Album" button above collection view
        self.createAlbumButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.createAlbumButton.frame = self.addButton.frame;
        self.createAlbumButton.layer.cornerRadius = 0.86*kRadius;
        self.createAlbumButton.layer.masksToBounds = NO;
        [self.createAlbumButton.layer setOpacity:0.0];
        [self.createAlbumButton.layer setShadowOpacity:0.8];
        self.createAlbumButton.backgroundColor = [UIColor piwigoColorOrange];
        self.createAlbumButton.tintColor = [UIColor whiteColor];
        self.createAlbumButton.showsTouchWhenHighlighted = YES;
        [self.createAlbumButton setImage:[UIImage imageNamed:@"create"] forState:UIControlStateNormal];
        [self.createAlbumButton addTarget:self action:@selector(didTapCreateAlbumButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.createAlbumButton.hidden = YES;
        [self.createAlbumButton setAccessibilityIdentifier:@"createAlbum"];
        [self.view insertSubview:self.createAlbumButton belowSubview:self.addButton];

        // "Upload Images" button above collection view
        self.uploadImagesButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.uploadImagesButton.frame = self.addButton.frame;
        self.uploadImagesButton.layer.cornerRadius = 0.86*kRadius;
        self.uploadImagesButton.layer.masksToBounds = NO;
        [self.uploadImagesButton.layer setOpacity:0.0];
        [self.uploadImagesButton.layer setShadowOpacity:0.8];
        self.uploadImagesButton.backgroundColor = [UIColor piwigoColorOrange];
        self.uploadImagesButton.tintColor = [UIColor whiteColor];
        self.uploadImagesButton.showsTouchWhenHighlighted = YES;
        [self.uploadImagesButton setImage:[UIImage imageNamed:@"imageUpload"] forState:UIControlStateNormal];
        [self.uploadImagesButton addTarget:self action:@selector(didTapUploadImagesButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.uploadImagesButton.hidden = YES;
        [self.uploadImagesButton setAccessibilityIdentifier:@"addImages"];
        [self.view insertSubview:self.uploadImagesButton belowSubview:self.addButton];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Reload category data
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"viewDidLoad => ID:%ld", (long)self.categoryId);
#endif
    [self getCategoryData:nil];

    // Navigation bar
    [self.navigationController.navigationBar setAccessibilityIdentifier:@"AlbumImagesNav"];
}

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Refresh controller
    if (@available(iOS 10.0, *)) {
        self.imagesCollection.refreshControl.backgroundColor = [UIColor piwigoColorBackground];
        self.imagesCollection.refreshControl.tintColor = [UIColor piwigoColorHeader];
        NSDictionary *attributesRefresh = @{
            NSForegroundColorAttributeName: [UIColor piwigoColorHeader],
            NSFontAttributeName: [UIFont piwigoFontLight],
        };
        self.imagesCollection.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Reload Photos") attributes:attributesRefresh];
    } else {
        // Fallback on earlier versions
        self.refreshControl.backgroundColor = [UIColor piwigoColorBackground];
        self.refreshControl.tintColor = [UIColor piwigoColorOrange];
        NSDictionary *attributesRefresh = @{
                                     NSForegroundColorAttributeName: [UIColor piwigoColorOrange],
                                     NSFontAttributeName: [UIFont piwigoFontNormal],
                                     };
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Reload Images") attributes:attributesRefresh];
    }
    
    // Buttons
    [self.addButton.layer setShadowColor:[UIColor piwigoColorShadow].CGColor];

    [self.createAlbumButton.layer setShadowColor:[UIColor piwigoColorShadow].CGColor];
    [self.uploadImagesButton.layer setShadowColor:[UIColor piwigoColorShadow].CGColor];

    [self.uploadQueueButton.layer setShadowColor:[UIColor piwigoColorShadow].CGColor];
    self.uploadQueueButton.backgroundColor = [UIColor piwigoColorRightLabel];
    self.nberOfUploadsLabel.textColor = [UIColor piwigoColorBackground];
    self.progressLayer.strokeColor = [[UIColor piwigoColorBackground] CGColor];

    [self.homeAlbumButton.layer setShadowColor:[UIColor piwigoColorShadow].CGColor];
    self.homeAlbumButton.backgroundColor = [UIColor piwigoColorRightLabel];
    self.homeAlbumButton.tintColor = [UIColor piwigoColorBackground];

    if (AppVars.isDarkPaletteActive) {
        [self.addButton.layer setShadowRadius:1.0];
        [self.addButton.layer setShadowOffset:CGSizeMake(0.0, 0.0)];

        [self.createAlbumButton.layer setShadowRadius:1.0];
        [self.createAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 0.0)];
        [self.uploadImagesButton.layer setShadowRadius:1.0];
        [self.uploadImagesButton.layer setShadowOffset:CGSizeMake(0.0, 0.0)];

        [self.uploadQueueButton.layer setShadowRadius:1.0];
        [self.uploadQueueButton.layer setShadowOffset:CGSizeMake(0.0, 0.0)];

        [self.homeAlbumButton.layer setShadowRadius:1.0];
        [self.homeAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 0.0)];
    } else {
        [self.addButton.layer setShadowRadius:3.0];
        [self.addButton.layer setShadowOffset:CGSizeMake(0.0, 0.5)];

        [self.createAlbumButton.layer setShadowRadius:3.0];
        [self.createAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 0.5)];
        [self.uploadImagesButton.layer setShadowRadius:3.0];
        [self.uploadImagesButton.layer setShadowOffset:CGSizeMake(0.0, 0.5)];

        [self.uploadQueueButton.layer setShadowRadius:3.0];
        [self.uploadQueueButton.layer setShadowOffset:CGSizeMake(0.0, 0.5)];

        [self.homeAlbumButton.layer setShadowRadius:3.0];
        [self.homeAlbumButton.layer setShadowOffset:CGSizeMake(0.0, 0.5)];
    }
    
    // Navigation bar appearance
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    self.navigationController.view.backgroundColor = [UIColor piwigoColorBackground];
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
    NSDictionary *attributesLarge = @{
                                      NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                      NSFontAttributeName: [UIFont piwigoFontLargeTitle],
                                      };
    if (@available(iOS 11.0, *)) {
        if (self.categoryId == AlbumVars.defaultCategory) {
            // Title
            navigationBar.largeTitleTextAttributes = attributesLarge;
            navigationBar.prefersLargeTitles = YES;

            // Search bar
            UISearchBar *searchBar = self.navigationItem.searchController.searchBar;
            searchBar.barStyle = AppVars.isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
            if (@available(iOS 13.0, *)) {
                searchBar.searchTextField.textColor = [UIColor piwigoColorLeftLabel];
                searchBar.searchTextField.keyboardAppearance = AppVars.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
            }
        }
        else {
            navigationBar.titleTextAttributes = attributes;
            navigationBar.prefersLargeTitles = NO;
        }

        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *barAppearance = [[UINavigationBarAppearance alloc] init];
            [barAppearance configureWithTransparentBackground];
            barAppearance.backgroundColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.9];
            barAppearance.titleTextAttributes = attributes;
            barAppearance.largeTitleTextAttributes = attributesLarge;
            if (self.categoryId != AlbumVars.defaultCategory) {
                barAppearance.shadowColor = AppVars.isDarkPaletteActive ? [UIColor colorWithWhite:1.0 alpha:0.15] : [UIColor colorWithWhite:0.0 alpha:0.3];
            }
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
    } else {
        navigationBar.titleTextAttributes = attributes;
        navigationBar.barTintColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.3];
        toolbar.barTintColor = [[UIColor piwigoColorBackground] colorWithAlphaComponent:0.9];
    }

    // Collection view
    self.imagesCollection.backgroundColor = [UIColor clearColor];
    self.imagesCollection.indicatorStyle = AppVars.isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.imagesCollection reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"viewWillAppear  => ID:%ld", (long)self.categoryId);
#endif
    
    // Set colors, fonts, etc.
    [self applyColorPalette];

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:[PwgNotificationsObjc paletteChanged] object:nil];

    // Register root album changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(returnToDefaultCategory) name:kPiwigoNotificationBackToDefaultAlbum object:nil];
    
    // Register upload manager changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNberOfUploads:)
                                                 name:[PwgNotificationsObjc leftUploads] object:nil];

    // Register upload progress
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUploadQueueButtonWithProgress:) name:[PwgNotificationsObjc uploadProgress] object:nil];

    // Called before displaying SearchImagesViewController?
    UIViewController *presentedViewController = [self presentedViewController];
    if ([presentedViewController isKindOfClass:[UISearchController class]]) {
        // Hide toolbar
        [self.navigationController setToolbarHidden:YES animated:YES];
        return;
    }
    
    // Inform Upload view controllers that user selected this category
    NSDictionary *userInfo = @{@"currentCategoryId" : @(self.categoryId)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedCurrentCategory object:nil userInfo:userInfo];
    
    // Load, sort images and reload collection
    if (self.categoryId != 0) {
#if defined(DEBUG_LIFECYCLE)
        NSLog(@"viewWillAppear  => load images");
#endif
        [self.albumData updateImageSort:self.currentSort OnCompletion:^{
            // Reset navigation bar buttons after image load
            [self updateButtonsInPreviewMode];
            [self.imagesCollection reloadData];
        }];
    }
    else {
#if defined(DEBUG_LIFECYCLE)
        NSLog(@"viewWillAppear  => reload albums table");
#endif
        if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
            [self.imagesCollection reloadData];
        }
    }
    
    // Refresh image collection if displayImageTitles option changed in Settings
    if (self.displayImageTitles != AlbumVars.displayImageTitles) {
        self.displayImageTitles = AlbumVars.displayImageTitles;
        if (self.categoryId != 0) {
            [self.albumData reloadAlbumOnCompletion:^{
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            }];
        }
    }

    // Always open this view with a navigation bar
    // (might have been hidden during Image Previewing)
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    // Set navigation bar buttons
    [self updateButtonsInPreviewMode];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
    // Display HUD while downloading albums data recursively
    if ((self.categoryId == 0) && !self.isCachedAtInit) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }
    
    // Called after displaying SearchImagesViewController?
    if (@available(iOS 11.0, *)) {
        UIViewController *presentedViewController = [self presentedViewController];
        if ([presentedViewController isKindOfClass:[UISearchController class]]) {
            // Scroll to image of interest if needed
            if ([self.navigationItem.searchController.searchResultsController isKindOfClass:[SearchImagesViewController class]]) {
                SearchImagesViewController *resultsController = (SearchImagesViewController *)self.navigationItem.searchController.searchResultsController;
                [resultsController scrollToHighlightedCell];
            }
            return;
        }
    }
    
    if (@available(iOS 10.0, *)) {
    } else {
        // Fallback on earlier versions
        [self.imagesCollection addSubview:self.refreshControl];
        self.imagesCollection.alwaysBounceVertical = YES;
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
                // Calculate the number of thumbnails displayed per page
                NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.imagesCollection imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];

                // Already loaded => scroll to image if necessary
//                NSLog(@"=> Discover|Scroll down to item #%ld", (long)self.imageOfInterest.item);
                if (self.imageOfInterest.item > roundf(imagesPerPage *2.0 / 3.0)) {
                    [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
                }

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

    // Determine which help pages should be presented
    NSMutableArray *displayHelpPagesWithIndex = [[NSMutableArray alloc] initWithCapacity:2];
    if ((self.categoryId != 0) && ([self.albumData.images count] > 5) &&
        ((AppVars.didWatchHelpViews & 0b0000000000000001) == 0)) {
        [displayHelpPagesWithIndex addObject:@0];   // i.e. multiple selection of images
    }
    NSInteger numberOfAlbums = [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
    if ((self.categoryId != 0) && (numberOfAlbums > 2) && NetworkVarsObjc.hasAdminRights &&
        ((AppVars.didWatchHelpViews & 0b0000000000000100) == 0)) {
        [displayHelpPagesWithIndex addObject:@2];   // i.e. management of albums
    }
    if (displayHelpPagesWithIndex.count > 0) {
        // Present unseen help views
        UIStoryboard *helpSB = [UIStoryboard storyboardWithName:@"HelpViewController" bundle:nil];
        HelpViewController *helpVC = [helpSB instantiateViewControllerWithIdentifier:@"HelpViewController"];
        helpVC.displayHelpPagesWithIndex = displayHelpPagesWithIndex;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            helpVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
            [self presentViewController:helpVC animated:YES completion:nil];
        } else {
            helpVC.modalPresentationStyle = UIModalPresentationFormSheet;
            helpVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [self presentViewController:helpVC animated:YES completion:nil];
        }
    }
    
    // Replace iRate as from v2.1.5 (75) — See https://github.com/nicklockwood/iRate
    // Tells StoreKit to ask the user to rate or review the app, if appropriate.
//#if !defined(DEBUG)
//    if (NSClassFromString(@"SKStoreReviewController")) {
//        [SKStoreReviewController requestReview];
//    }
//#endif

    // Inform user why the app crashed at start
    if (CacheVarsObjc.couldNotMigrateCoreDataStore) {
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"CoreDataStore_WarningTitle", @"Warning")
                message:NSLocalizedString(@"CoreDataStore_WarningMessage", @"A serious application error occurred…")
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* dismissAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {
            // Reset flag
            CacheVarsObjc.couldNotMigrateCoreDataStore = NO;
        }];
        
        // Add actions
        [alert addAction:dismissAction];

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange;
        if (@available(iOS 13.0, *)) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
        [self presentViewController:alert animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange;
        }];
    }
    
    // Register category data updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCategoryData:) name:kPiwigoNotificationGetCategoryData object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addImageToCategory:) name:kPiwigoNotificationUploadedImage object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeImageFromCategory:) name:kPiwigoNotificationRemovedImage object:nil];
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

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Update the navigation bar on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.imagesCollection reloadData];
        if (self.isSelect) {
            [self initButtonsInSelectionMode];
        } else {
            // Update position of buttons (recalculated after device rotation)
            CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
            CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
            self.addButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
            if (self.addButton.isHidden) {
                self.homeAlbumButton.frame = self.addButton.frame;
            } else {
                self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
            }
            if (self.uploadQueueButton.isHidden) {
                self.uploadQueueButton.frame = self.addButton.frame;
            } else {
                // Elongate the button if needed
                CGRect frame = self.uploadQueueButton.frame;
                frame.origin.x = xPos - 3*kRadius - (frame.size.width - 2*kRadius);
                frame.origin.y = yPos;
                self.uploadQueueButton.frame = frame;
            }
            if (self.createAlbumButton.isHidden) {
                self.createAlbumButton.frame = self.addButton.frame;
                self.uploadImagesButton.frame = self.addButton.frame;
            } else {
                self.createAlbumButton.frame = CGRectMake(xPos - 3*kRadius*cos(15*kDeg2Rad), yPos - 3*kRadius*sin(15*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
                self.uploadImagesButton.frame = CGRectMake(xPos - 3*kRadius*cos(75*kDeg2Rad), yPos - 3*kRadius*sin(75*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
            }
        }
    } completion:nil];
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

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }

    // Hide upload button during transition
    [self.addButton setHidden:YES];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Make sure buttons are back to initial state
    [self didCancelTapAddButton];
}

-(void)dealloc
{
    // Unregister category data updates
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationGetCategoryData object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCategoryDataUpdated object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationUploadedImage object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationRemovedImage object:nil];

    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[PwgNotificationsObjc paletteChanged] object:nil];

    // Unregister root album changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationBackToDefaultAlbum object:nil];
    
    // Unregister upload manager changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[PwgNotificationsObjc leftUploads] object:nil];

    // Unregister upload progress
    [[NSNotificationCenter defaultCenter] removeObserver:self name:[PwgNotificationsObjc uploadProgress] object:nil];
}


#pragma mark - Buttons in Preview mode

-(void)updateButtonsInPreviewMode
{
    // Hide toolbar unless it is displaying the image detail view
    UIViewController *displayedVC = self.navigationController.viewControllers.lastObject;
    if (![displayedVC isKindOfClass:[ImageDetailViewController class]]) {
        [self.navigationController setToolbarHidden:YES animated:YES];
    }

    // Title is name of category
    if (self.categoryId == 0) {
        self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
    } else {
        self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
    }

    // User can upload images/videos if he/she has:
    // — admin rights
    // — normal rights and upload access to the current category
    if (NetworkVarsObjc.hasAdminRights ||
        (NetworkVarsObjc.hasNormalRights && [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights]))
    {
        // Show Upload button if needed
        if (self.addButton.isHidden)
        {
            // Unhide transparent Add button
            self.addButton.tintColor = [UIColor whiteColor];
            [self.addButton setHidden:NO];

            // Animate appearance of Add button
            [UIView animateWithDuration:0.3 animations:^{
                [self.addButton.layer setOpacity:0.9];
                self.addButton.tintColor = [UIColor whiteColor];
            } completion:^(BOOL finished) {
                // Show button on the left of the Add button if needed
                if ((self.categoryId != 0) && (self.categoryId != AlbumVars.defaultCategory)) {
                    // Show Home button if not in root or default album
                    [self showHomeAlbumButtonIfNeeded];
                } else {
                    // Show UploadQueue button if needed
                    NSInteger nberOfUploads = [[UIApplication sharedApplication] applicationIconBadgeNumber];
                    NSDictionary *userInfo = @{@"nberOfUploadsToComplete" : @(nberOfUploads)};
                    [[NSNotificationCenter defaultCenter] postNotificationName:[PwgNotificationsObjc leftUploads]
                                                                        object:nil userInfo:userInfo];
                }
            }];
        } else {
            // Present Home button if needed and if not in root or default album
            if ((self.categoryId != 0) && (self.categoryId != AlbumVars.defaultCategory)) {
                [self showHomeAlbumButtonIfNeeded];
            }
        }
    }
    else    // No upload rights => No Upload button
    {
        // Show Home button if not in root or default album
        [self.addButton setHidden:YES];
        if ((self.categoryId != 0) && (self.categoryId != AlbumVars.defaultCategory)) {
            [self showHomeAlbumButtonIfNeeded];
        }
    }
    
    // Left side of navigation bar
    if ((self.categoryId == 0) ||
        (self.categoryId == AlbumVars.defaultCategory)){
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
        
        // Following 2 lines fixes situation where the Edit button remains visible
        [self.navigationController.navigationBar setNeedsLayout];
        [self.navigationController.navigationBar layoutIfNeeded];
    }
}

-(void)didTapPreferencesButton
{
    UIStoryboard *settingsSB = [UIStoryboard storyboardWithName:@"SettingsViewController" bundle:nil];
    SettingsViewController *settingsVC = [settingsSB instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    settingsVC.settingsDelegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
    navController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(mainScreenBounds),
                                                                        CGRectGetMidY(mainScreenBounds), 0, 0);
    navController.preferredContentSize = CGSizeMake(kPiwigoPadSettingsWidth,
                                                    ceil(mainScreenBounds.size.height * 2 / 3));
    [self presentViewController:navController animated:YES completion:nil];
}

-(void)didTapAddButton
{
    // Create album if root album shown
    if (self.categoryId == 0) {
        // User in root album => Create album
        self.addButton.backgroundColor = [UIColor grayColor];
        self.addButton.tintColor = [UIColor whiteColor];
        [self showCreateCategoryDialog];
        return;
    }
    
    // Hide Home button behind Add button if needed
    if (self.homeAlbumButton.isHidden)
    {
        // Show CreateAlbum and UploadImages albums
        [self showOptionalButtonsCompletion:^{

            // Change appearance and action of Add button
            [self.addButton removeTarget:self action:@selector(didTapAddButton)
                        forControlEvents:UIControlEventTouchUpInside];
            [self.addButton addTarget:self action:@selector(didCancelTapAddButton)
                   forControlEvents:UIControlEventTouchUpInside];
            [UIView animateWithDuration:0.2 animations:^{
                self.addButton.backgroundColor = [UIColor grayColor];
                self.addButton.tintColor = [UIColor whiteColor];
            }];
        }];
    } else {
        // Hide Home Album button
        [self hideHomeAlbumButtonCompletion:^{
            
            // Show CreateAlbum and UploadImages albums
            [self showOptionalButtonsCompletion:^{
                
                // Change appearance and action of Add button
                [self.addButton removeTarget:self action:@selector(didTapAddButton)
                            forControlEvents:UIControlEventTouchUpInside];
                [self.addButton addTarget:self action:@selector(didCancelTapAddButton)
                       forControlEvents:UIControlEventTouchUpInside];
                [UIView animateWithDuration:0.2 animations:^{
                    self.addButton.backgroundColor = [UIColor grayColor];
                    self.addButton.tintColor = [UIColor whiteColor];
                }];
            }];
        }];
    }
}

-(void)didCancelTapAddButton
{
    // User changed mind or finished job
    // First hide optional buttons
    [self hideOptionalButtonsCompletion:^{
        // Reset appearance and action of Add button
        [self.addButton removeTarget:self action:@selector(didCancelTapAddButton)
                    forControlEvents:UIControlEventTouchUpInside];
        [self.addButton addTarget:self action:@selector(didTapAddButton)
               forControlEvents:UIControlEventTouchUpInside];
        self.addButton.backgroundColor = [UIColor piwigoColorOrange];
        self.addButton.tintColor = [UIColor whiteColor];
            
        // Show button on the left of the Add button if needed
        if ((self.categoryId != 0) && (self.categoryId != AlbumVars.defaultCategory)) {
            // Show Home button if not in root or default album
            [self showHomeAlbumButtonIfNeeded];
        }
    }];
}

-(void)showHomeAlbumButtonIfNeeded
{
    // Present Home Album button if needed
    if ((self.homeAlbumButton.isHidden ||
         CGRectContainsPoint(self.homeAlbumButton.frame, self.addButton.frame.origin)) &&
        (self.uploadImagesButton.isHidden ||
         CGRectContainsPoint(self.uploadImagesButton.frame, self.addButton.frame.origin)) &&
        (self.createAlbumButton.isHidden ||
         CGRectContainsPoint(self.createAlbumButton.frame, self.addButton.frame.origin)))
    {
        // Unhide transparent Home Album button
        [self.homeAlbumButton setHidden:NO];
                
        // Animate appearance of Home Album button
        [UIView animateWithDuration:0.3 animations:^{
            // Progressive appearance
            [self.homeAlbumButton.layer setOpacity:0.8];
            
            // Position of Home Album button depends on user's rights
            // — admin rights
            // — normal rights and upload access to the current category
            if (NetworkVarsObjc.hasAdminRights ||
                (NetworkVarsObjc.hasNormalRights && [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights]))
            {
                CGFloat xPos = self.addButton.frame.origin.x;
                CGFloat yPos = self.addButton.frame.origin.y;
                self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
            }
            else {
                self.homeAlbumButton.frame = self.addButton.frame;
            }
        }];
    }
}

-(void)updateNberOfUploads:(NSNotification *)notification
{
    if (notification == nil) { return; }
    NSDictionary *userInfo = notification.userInfo;
    
    // Update number of upload requests?
    if ([userInfo objectForKey:@"nberOfUploadsToComplete"] != nil) {
        NSInteger nberOfUploads = [[userInfo objectForKey:@"nberOfUploadsToComplete"] integerValue];

        // Only presented in the root or default album
        if ((nberOfUploads > 0) &&
            ((self.categoryId == 0) || (self.categoryId == AlbumVars.defaultCategory))) {
            // Set number of uploads
            NSString *nber = [NSString stringWithFormat:@"%lu", (unsigned long)nberOfUploads];
            if ([nber compare:self.nberOfUploadsLabel.text] == NSOrderedSame && !self.uploadQueueButton.hidden) {
                // Number unchanged -> NOP
                return;
            }
            self.nberOfUploadsLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)nberOfUploads];
            
            // Resize label to fit number
            [self.nberOfUploadsLabel sizeToFit];
            
            // Adapt button width if needed
            CGFloat width = self.nberOfUploadsLabel.bounds.size.width + 20;
            CGFloat height = self.nberOfUploadsLabel.bounds.size.height;
            CGFloat extraWidth = fmax(0, (width - 2*kRadius));
            self.nberOfUploadsLabel.frame = CGRectMake(kRadius + (extraWidth / 2.0) - width / 2.0, kRadius - height / 2.0, width, height);

            self.progressLayer.frame = CGRectMake(0, 0, 2*kRadius + extraWidth, 2*kRadius);
            UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kRadius + extraWidth, kRadius) radius:(kRadius-1.5f) startAngle:(-M_PI_2) endAngle:M_PI_2 clockwise:YES];
            [path addLineToPoint:CGPointMake(kRadius, 2*kRadius-1.5f)];
            [path addArcWithCenter:CGPointMake(kRadius, kRadius) radius:(kRadius-1.5f) startAngle:M_PI_2 endAngle:M_PI+M_PI_2 clockwise:YES];
            [path addLineToPoint:CGPointMake(kRadius + extraWidth, 1.5f)];
            [path setLineCapStyle:kCGLineCapRound];
            self.progressLayer.path = [path CGPath];

            // Show button if needed
            if (self.uploadQueueButton.hidden) {
                // Unhide transparent Upload Queue button
                [self.uploadQueueButton setHidden:NO];
            }
                        
            // Animate appearance / width change of Upload Queue button
			[UIView animateWithDuration:0.3 animations:^{
				// Progressive appearance
				[self.uploadQueueButton.layer setOpacity:0.8];
				CGFloat xPos = self.addButton.frame.origin.x - extraWidth;
				CGFloat yPos = self.addButton.frame.origin.y;
                if (self.addButton.isHidden) {
                    self.uploadQueueButton.frame = CGRectMake(xPos, yPos, 2*kRadius + extraWidth, 2*kRadius);
                } else {
                    self.uploadQueueButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius + extraWidth, 2*kRadius);
                }
				[self.uploadQueueButton setNeedsLayout];
			}];
        } else {
            // Hide button if not already hidden
            if (!self.uploadQueueButton.hidden) {
                // Hide Upload Queue button behind Add button
                [UIView animateWithDuration:0.3 animations:^{
                    // Progressive disappearance
                    [self.uploadQueueButton.layer setOpacity:0.0];

                    // Animate displacement towards the Add button if needed
                    self.uploadQueueButton.frame = self.addButton.frame;
                
                } completion:^(BOOL finished) {
                    // Hide Home Album button
                    [self.uploadQueueButton setHidden:YES];
                }];
            }
        }
    }
}

-(void)updateUploadQueueButtonWithProgress:(NSNotification *)notification
{
    if (notification == nil) { return; }
    NSDictionary *userInfo = notification.userInfo;

    // Upload progress path?
    if ([userInfo objectForKey:@"progressFraction"] != nil) {
        CGFloat progress = [[userInfo objectForKey:@"progressFraction"] floatValue];

        // Animate progress layer of Upload Queue button
        if (progress > 0.0) {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            [animation setFromValue:@(self.progressLayer.strokeEnd)];
            [animation setToValue:@(progress)];
            self.progressLayer.strokeEnd = progress;
            animation.duration = 0.2f;
            [self.progressLayer addAnimation:animation forKey:nil];
        } else {
            // No animation
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            self.progressLayer.strokeEnd = 0.0;
            [CATransaction commit];
            // Animations are disabled until here...
        }
    }
}

-(void)hideHomeAlbumButtonCompletion:(void (^ __nullable)(void))completion
{
    // Hide Home Album button behind Add button
    [UIView animateWithDuration:0.2 animations:^{
        // Progressive disappearance
        [self.homeAlbumButton.layer setOpacity:0.0];

        // Animate displacement towards the Add button if needed
        self.homeAlbumButton.frame = self.addButton.frame;
    
    } completion:^(BOOL finished) {
        // Hide Home Album button
        [self.homeAlbumButton setHidden:YES];

        // Execute block
        if (completion) {
            completion();
        }
    }];
}

-(void)showOptionalButtonsCompletion:(void (^ __nullable)(void))completion
{
    // For positioning the buttons
    CGFloat xPos = self.addButton.frame.origin.x;
    CGFloat yPos = self.addButton.frame.origin.y;

    // Unhide transparent CreateAlbum and UploadImages buttons
    self.createAlbumButton.tintColor = [UIColor whiteColor];
    [self.createAlbumButton setHidden:NO];
    self.uploadImagesButton.tintColor = [UIColor whiteColor];
    [self.uploadImagesButton setHidden:NO];
    
    // Show CreateAlbum and UploadImages buttons
    [UIView animateWithDuration:0.3 animations:^{
        // Progressive appearance
        [self.createAlbumButton.layer setOpacity:0.9];
        [self.uploadImagesButton.layer setOpacity:0.9];
        
        // Move buttons together
        self.createAlbumButton.frame = CGRectMake(xPos - 3*kRadius*cos(15*kDeg2Rad), yPos - 3*kRadius*sin(15*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
        self.uploadImagesButton.frame = CGRectMake(xPos - 3*kRadius*cos(75*kDeg2Rad), yPos - 3*kRadius*sin(75*kDeg2Rad), 1.72*kRadius, 1.72*kRadius);
    
    } completion:^(BOOL finished) {
        // Execute block
        if (completion) {
            completion();
        }
    }];
}

-(void)hideOptionalButtonsCompletion:(void (^ __nullable)(void))completion
{
    // For positioning the buttons
    CGFloat xPos = self.addButton.frame.origin.x;
    CGFloat yPos = self.addButton.frame.origin.y;

    // Hide CreateAlbum and UploadImages buttons
    [UIView animateWithDuration:0.3 animations:^{
        // Progressive disappearance
        [self.createAlbumButton.layer setOpacity:0.0];
        [self.uploadImagesButton.layer setOpacity:0.0];
        
        // Move buttons towards Add button
        self.createAlbumButton.frame = CGRectMake(xPos, yPos, 1.72*kRadius, 1.72*kRadius);
        self.uploadImagesButton.frame = CGRectMake(xPos, yPos, 1.72*kRadius, 1.72*kRadius);

    } completion:^(BOOL finished) {
        // Hide transparent CreateAlbum and UploadImages buttons
        [self.createAlbumButton setHidden:YES];
        [self.uploadImagesButton setHidden:YES];
        
        // Reset background colours
        [self.createAlbumButton setBackgroundColor:[UIColor piwigoColorOrange]];
        [self.uploadImagesButton setBackgroundColor:[UIColor piwigoColorOrange]];
        
        // Execute block
        if (completion) {
            completion();
        }
    }];
}


#pragma mark - Buttons in Selection mode

-(void)initButtonsInSelectionMode {
    // Hide back, Settings, Upload and Home buttons
    [self.navigationItem setHidesBackButton:YES];
    [self.addButton setHidden:YES];
    [self.homeAlbumButton setHidden:YES];

    // Button displayed in all circumstances
    self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelection)];
    self.shareBarButton.tintColor = [UIColor piwigoColorOrange];

    if (@available(iOS 14, *)) {
        // Interface depends on device and orientation
        UIInterfaceOrientation orientation = UIApplication.sharedApplication.windows.firstObject.windowScene.interfaceOrientation;

        // User with admin or upload rights can do everything
        if ((NetworkVarsObjc.hasAdminRights) ||
            (NetworkVarsObjc.hasNormalRights && self.userHasUploadRights)) {
            // The action button proposes:
            /// - to copy or move images to other albums
            /// - to set the image as album thumbnail
            /// - to edit image parameters
            UIMenu *menu = [UIMenu menuWithTitle:@"" children:@[self.albumMenu, self.imagesMenu]];
            self.actionBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:menu];
            self.actionBarButton.accessibilityIdentifier = @"actions";

            self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelection)];

            if (UIInterfaceOrientationIsPortrait(orientation) &&
                (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)) {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // Right side of navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.actionBarButton] animated:YES];

                // Remaining buttons in navigation toolbar
                /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                /// They also disappear when coming back to portrait orientation.
                self.spaceBetweenButtons = [UIBarButtonItem spaceBetweenButtons];
                NSMutableArray<UIBarButtonItem *> *toolBarItems = [[NSMutableArray alloc] initWithObjects:self.shareBarButton, self.spaceBetweenButtons, self.deleteBarButton, nil];
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [toolBarItems insertObjects:@[self.favoriteBarButton, self.spaceBetweenButtons] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 2)]];
                }
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = toolBarItems;
            }
            else {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton, self.deleteBarButton] animated:YES];

                // Right side of navigation bar
                NSMutableArray<UIBarButtonItem *> *rightBarButtonItems = [[NSMutableArray alloc] initWithObjects:self.actionBarButton, self.shareBarButton, nil];
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [rightBarButtonItems insertObjects:@[self.favoriteBarButton] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 1)]];
                }
                [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:YES];

                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        }
        else if (!NetworkVarsObjc.hasGuestRights &&
                 ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
            self.favoriteBarButton = [self getFavoriteBarButton];

            if (UIInterfaceOrientationIsPortrait(orientation) &&
                (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)) {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // No button on the right
                [self.navigationItem setRightBarButtonItems:@[] animated:YES];

                // Remaining buttons in navigation toolbar
                self.spaceBetweenButtons = [UIBarButtonItem spaceBetweenButtons];
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.favoriteBarButton];
            }
            else {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // All other buttons in navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.favoriteBarButton, self.shareBarButton] animated:YES];

                // Hide navigation toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        } else {
            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

            // Guest can only share images
            [self.navigationItem setRightBarButtonItems:@[self.shareBarButton] animated:YES];

            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];
        }
    } else {
        // Fallback on earlier versions
        // Interface depends on device and orientation
        UIInterfaceOrientation orientation = UIApplication.sharedApplication.statusBarOrientation;
        
        // User with admin or upload rights can do everything
        // WRONG =====> 'normal' user with upload access to the current category can edit images
        // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
        if ((NetworkVarsObjc.hasAdminRights) ||
            (NetworkVarsObjc.hasNormalRights && self.userHasUploadRights)) {
            // The action button only proposes to edit image parameters
            self.actionBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editSelection)];
            [self.actionBarButton setAccessibilityIdentifier:@"actions"];

            self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteSelection)];
            self.moveBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(addImagesToCategory)];

            if (UIInterfaceOrientationIsPortrait(orientation) &&
                (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)) {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // Right side of navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.actionBarButton] animated:YES];

                // Remaining buttons in navigation toolbar
                /// We reset the bar button items which are not positioned correctly by iOS 15 after device rotation.
                /// They also disappear when coming back to portrait orientation.
                self.spaceBetweenButtons = [UIBarButtonItem spaceBetweenButtons];
                NSMutableArray<UIBarButtonItem *> *toolBarItems = [[NSMutableArray alloc] initWithObjects:self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.deleteBarButton, nil];
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [toolBarItems insertObjects:@[self.favoriteBarButton, self.spaceBetweenButtons] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(4, 2)]];
                }
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = toolBarItems;
            }
            else {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton, self.deleteBarButton, self.moveBarButton] animated:YES];

                // Right side of navigation bar
                NSMutableArray<UIBarButtonItem *> *rightBarButtonItems = [[NSMutableArray alloc] initWithObjects:self.actionBarButton, self.shareBarButton, nil];
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [rightBarButtonItems insertObjects:@[self.favoriteBarButton] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 1)]];
                }
                [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:YES];

                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        }
        else if (!NetworkVarsObjc.hasGuestRights &&
                 ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
            self.favoriteBarButton = [self getFavoriteBarButton];

            if (UIInterfaceOrientationIsPortrait(orientation) &&
                (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)) {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // No button on the right
                [self.navigationItem setRightBarButtonItems:@[] animated:YES];

                // Remaining buttons in navigation toolbar
                self.spaceBetweenButtons = [UIBarButtonItem spaceBetweenButtons];
                [self.navigationController setToolbarHidden:NO animated:YES];
                self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.favoriteBarButton];
            }
            else {
                // Left side of navigation bar
                [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

                // All other buttons in navigation bar
                [self.navigationItem setRightBarButtonItems:@[self.favoriteBarButton, self.shareBarButton] animated:YES];

                // Hide navigation toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        } else {
            // Left side of navigation bar
            [self.navigationItem setLeftBarButtonItems:@[self.cancelBarButton] animated:YES];

            // Guest can only share images
            [self.navigationItem setRightBarButtonItems:@[self.shareBarButton] animated:YES];

            // Hide toolbar
            [self.navigationController setToolbarHidden:YES animated:YES];
        }
    }
    
    // Set initial status
    [self updateButtonsInSelectionMode];
}

-(void)updateButtonsInSelectionMode
{
    BOOL hasImagesSelected = (self.selectedImageIds.count > 0);
    
    // User with admin or upload rights can do everything
    // WRONG =====> 'normal' user with upload access to the current category can edit images
    // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by'
    if ((NetworkVarsObjc.hasAdminRights) ||
        (NetworkVarsObjc.hasNormalRights && self.userHasUploadRights))
    {
        self.cancelBarButton.enabled = YES;
        self.actionBarButton.enabled = hasImagesSelected;
        self.shareBarButton.enabled = hasImagesSelected;
        self.deleteBarButton.enabled = hasImagesSelected;
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
            self.favoriteBarButton.enabled = hasImagesSelected;
            BOOL areFavorites = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:self.selectedImageIds];
            [self.favoriteBarButton setFavoriteImageFor:areFavorites];
            self.favoriteBarButton.action = areFavorites ? @selector(removeFromFavorites) : @selector(addToFavorites);
        }
        
        if (@available(iOS 14, *)) {
        } else {
            self.moveBarButton.enabled = hasImagesSelected;
        }
    }
    else      // No rights => No toolbar, only download button
    {
        // Left side of navigation bar
        self.cancelBarButton.enabled = YES;

        // Right side of navigation bar
        /// — guests can share photo of high-resolution or not
        /// — non-guest users can set favorites in addition
        self.shareBarButton.enabled = hasImagesSelected;
        if (!NetworkVarsObjc.hasGuestRights && ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
            self.favoriteBarButton.enabled = hasImagesSelected;
            BOOL areFavorites = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:self.selectedImageIds];
            [self.favoriteBarButton setFavoriteImageFor:areFavorites];
            self.favoriteBarButton.action = areFavorites ? @selector(removeFromFavorites) : @selector(addToFavorites);
        }
    }
}

// Buttons are disabled (greyed) when retrieving image data
// They are also disabled during an action
-(void)setEnableStateOfButtons:(BOOL)state
{
    self.cancelBarButton.enabled = state;
    self.actionBarButton.enabled = state;
    self.deleteBarButton.enabled = state;
    self.moveBarButton.enabled = state;
    self.shareBarButton.enabled = state;
    // pwg.users.favorites… methods available from Piwigo version 2.10
    if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
        self.favoriteBarButton.enabled = state;
    }
}


#pragma mark - Category Data

-(void)getCategoryData:(NSNotification *)notification
{
    // Extract notification user info
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.categoryId) return;
        
        // Disable cache?
        self.isCachedAtInit = [[userInfo objectForKey:@"fromCache"] boolValue];
    }

    // Reload category data
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"getCategoryData => getAlbumListForCategory(ID:%ld, cache:%@)",
          (long)self.categoryId, self.isCachedAtInit ? @"Yes" : @"No");
#endif
    
    // Load category data in recursive mode
    [AlbumService getAlbumListForCategory:self.categoryId
                               usingCache:self.isCachedAtInit
                          inRecursiveMode:YES
     OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
        self.isCachedAtInit = YES;
        
        if (albums == nil) {
            // Album data already in cache
            self.userHasUploadRights = [[CategoriesData.sharedInstance getCategoryById:self.categoryId] hasUploadRights];
        }
        else if (self.categoryId == 0) {
            // Album data freshly loaded in recursive mode
            self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];
            if ([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
                // There exists album in cache ;-)
                [self.imagesCollection reloadData];
                
                // Load favorites in the background before loading image data
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void){
                    [self loadFavorites];
                });

                // For iOS 11 and later: place search bar in navigation bar of root album
                if (@available(iOS 11.0, *)) {
                    // Initialise search controller when displaying root album
                    SearchImagesViewController *resultsCollectionController = [[SearchImagesViewController alloc] init];
                    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:resultsCollectionController];
                    searchController.delegate = self;
                    searchController.hidesNavigationBarDuringPresentation = YES;
                    searchController.searchResultsUpdater = self;
                    
                    searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
                    searchController.searchBar.translucent = NO;
                    searchController.searchBar.showsCancelButton = NO;
                    searchController.searchBar.tintColor = [UIColor piwigoColorOrange];
                    searchController.searchBar.showsSearchResultsButton = NO;
                    searchController.searchBar.delegate = self;        // Monitor when the search button is tapped.
                    self.definesPresentationContext = YES;
                    
                    // Place the search bar in the navigation bar.
                    self.navigationItem.searchController = searchController;
                }
            }
            
            // Hide HUD if needed
            [self.navigationController hidePiwigoHUDWithCompletion:^{ }];
        }
        else {
            // Load, sort images and reload collection (should never reach this line)
            self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId andQuery:@""];
            [self.albumData updateImageSort:self.currentSort OnCompletion:^{

                // Reset navigation bar buttons after image load
                [self updateButtonsInPreviewMode];
                [self.imagesCollection reloadData];

                // For iOS 11 and later: place search bar in navigation bar of root album only
                if (@available(iOS 11.0, *)) {
                    // Remove search bar
                    self.navigationItem.searchController = nil;
                }
            }];
        }
    }
        onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
            NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
        }
     ];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    [AlbumService getAlbumListForCategory:0
                               usingCache:NO
                          inRecursiveMode:YES
         OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
            // Refresh current view
            [self.imagesCollection reloadData];

            // Also refresh list of favorite images
            PiwigoAlbumData *favoritesAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
            [[CategoriesData sharedInstance] updateCategories:@[favoritesAlbum]];
            [[[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId] loadAllCategoryImageDataWithSort:self.currentSort forProgress:nil OnCompletion:^(BOOL completed) {
                    if (refreshControl) [refreshControl endRefreshing];
            }];
        }
        onFailure:^(NSURLSessionTask *task, NSError *error) {
             if (refreshControl) [refreshControl endRefreshing];
         }
     ];
}

-(void)categoriesUpdated
{
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"=> categoriesUpdated… %ld", (long)self.categoryId);
#endif
    
    // Images ?
    if (self.categoryId != 0) {
        // Store current image list
        NSArray *oldImageList = self.albumData.images;
//        NSLog(@"=> categoriesUpdated… %ld contained %ld images", (long)self.categoryId, (long)oldImageList.count);

        // Collect images belonging to the current album
        [self.albumData loadAllImagesOnCompletion:^{

            // Sort images
            [self.albumData updateImageSort:self.currentSort OnCompletion:^{
//                NSLog(@"=> categoriesUpdated… %ld now contains %ld images", (long)self.categoryId, (long)self.albumData.images.count);
                if (oldImageList.count == self.albumData.images.count) {
                    [self.imagesCollection reloadData];     // Total number of images may have changed
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
                     [itemsToInsert addObject:[NSIndexPath indexPathForItem:index inSection:1]];
                    }
                }
                if (itemsToInsert.count > 0) {
                    [self.imagesCollection insertItemsAtIndexPaths:itemsToInsert];
                }

                // Delete cells of deleted images, and remove them from selection
                NSMutableArray<NSIndexPath *> *itemsToDelete = [NSMutableArray new];
                for (NSInteger index = 0; index < oldImageList.count; index++) {
                    PiwigoImageData *imageData = [oldImageList objectAtIndex:index];
                    NSInteger indexOfExistingItem = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger oldIdx, BOOL * _Nonnull stop) {
                     return obj.imageId == imageData.imageId;
                    }];
                    if (indexOfExistingItem == NSNotFound) {
                     [itemsToDelete addObject:[NSIndexPath indexPathForItem:index inSection:1]];
                        NSNumber *imageIdObject = [NSNumber numberWithInteger:imageData.imageId];
                        if ([self.selectedImageIds containsObject:imageIdObject]) {
                            [self.selectedImageIds removeObject:imageIdObject];
                        }
                    }
                }
                for (NSIndexPath *indexPath in itemsToDelete) {
                    if ([self.imagesCollection.indexPathsForVisibleItems containsObject:indexPath]) {
                        [self.imagesCollection deleteItemsAtIndexPaths:@[indexPath]];
                    }
                }

                // Update footer
                UICollectionReusableView *visibleFooter = [[self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter] firstObject];
                NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                if ([visibleFooter isKindOfClass:[NberImagesFooterCollectionReusableView class]]) {
                    NberImagesFooterCollectionReusableView *footer = (NberImagesFooterCollectionReusableView *)visibleFooter;
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
                    footer.noImagesLabel.text = totalImageCount > 1 ?
                    [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]] :
                    [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]];
                }

                // Set navigation bar buttons
                if (self.isSelect == YES) {
                    [self updateButtonsInSelectionMode];
                } else {
                    [self updateButtonsInPreviewMode];
                }
            }];
        }];
    }
    else {
         // The album title is not shown in backButtonItem to provide enough space
         // for image title on devices of screen width <= 414 ==> Restore album title
         self.title = NSLocalizedString(@"tabBar_albums", @"Albums");

         // Set navigation bar buttons
         [self updateButtonsInPreviewMode];

         // Reload collection view
         [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
     }
}

-(void)addImageToCategory:(NSNotification *)notification
{
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.categoryId) return;
        
        // Image Id?
//        NSInteger imageId = [[userInfo objectForKey:@"imageId"] integerValue];
//        NSLog(@"=> addImage %ld to Category %ld", (long)imageId, (long)catId);
        
        // Store current image list
        NSArray *oldImageList = self.albumData.images;
//        NSLog(@"=> category %ld contained %ld images", (long)self.categoryId, (long)oldImageList.count);

        // Load new image (appended to cache) and sort images before updating UI
        [self.albumData loadMoreImagesOnCompletion:^{
            // Sort images
            [self.albumData updateImageSort:self.currentSort OnCompletion:^{

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

                // Refresh collection view if needed
//                NSLog(@"=> category %ld now contains %ld images", (long)self.categoryId, (long)self.albumData.images.count);
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
                     [itemsToInsert addObject:[NSIndexPath indexPathForItem:index inSection:1]];
                    }
                }
                if (itemsToInsert.count > 0) {
                    if ([self.imagesCollection numberOfItemsInSection:1] == self.albumData.images.count - itemsToInsert.count) {
                        [self.imagesCollection insertItemsAtIndexPaths:itemsToInsert];
                    } else {
                        [self.imagesCollection reloadData];
                    }
                }

                // Update footer
                UICollectionReusableView *visibleFooter = [[self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter] firstObject];
                NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                if ([visibleFooter isKindOfClass:[NberImagesFooterCollectionReusableView class]]) {
                    NberImagesFooterCollectionReusableView *footer = (NberImagesFooterCollectionReusableView *)visibleFooter;
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
                    footer.noImagesLabel.text = totalImageCount > 1 ?
                    [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]] :
                    [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]];
                }

                // Set navigation bar buttons
                if (self.isSelect == YES) {
                    [self updateButtonsInSelectionMode];
                } else {
                    [self updateButtonsInPreviewMode];
                }
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

        // Remove image (removed from cache) and sort images before updating UI
        [self.albumData loadMoreImagesOnCompletion:^{
            // Sort images
            [self.albumData updateImageSort:self.currentSort OnCompletion:^{

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

                // Refresh collection view if needed
//                NSLog(@"=> category %ld now contains %ld images", (long)self.categoryId, (long)self.albumData.images.count);
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
                     [itemsToDelete addObject:[NSIndexPath indexPathForItem:index inSection:1]];
                        NSNumber *imageIdObject = [NSNumber numberWithInteger:imageData.imageId];
                        if ([self.selectedImageIds containsObject:imageIdObject]) {
                            [self.selectedImageIds removeObject:imageIdObject];
                        }
                    }
                }
                if (itemsToDelete.count > 0) {
                    if ([self.imagesCollection numberOfItemsInSection:1] == self.albumData.images.count + itemsToDelete.count) {
                        [self.imagesCollection deleteItemsAtIndexPaths:itemsToDelete];
                    } else {
                        [self.imagesCollection reloadData];
                    }
                }

                // Update footer
                UICollectionReusableView *visibleFooter = [[self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter] firstObject];
                NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                if ([visibleFooter isKindOfClass:[NberImagesFooterCollectionReusableView class]]) {
                    NberImagesFooterCollectionReusableView *footer = (NberImagesFooterCollectionReusableView *)visibleFooter;
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
                    footer.noImagesLabel.text = totalImageCount > 1 ?
                    [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]] :
                    [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]];
                }

                // Set navigation bar buttons if the AlbumImagesViewController is visible
                UIViewController *visibleViewController = self.navigationController.visibleViewController;
                if ([visibleViewController isKindOfClass:[AlbumImagesViewController class]]) {
                    if (self.isSelect == YES) {
                        [self updateButtonsInSelectionMode];
                    } else {
                        [self updateButtonsInPreviewMode];
                    }
                }
            }];
        }];
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
            if (thisViewController.categoryId == AlbumVars.defaultCategory) {
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
        rootAlbumViewController = [[AlbumImagesViewController alloc] initWithAlbumId:AlbumVars.defaultCategory inCache:NO];
        NSMutableArray *arrayOfVC = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
        [arrayOfVC insertObject:rootAlbumViewController atIndex:index];
        self.navigationController.viewControllers = arrayOfVC;
    }
    
    // Present the root album
    [self.navigationController popToViewController:rootAlbumViewController animated:YES];
}


#pragma mark - Upload images

-(void)didTapUploadImagesButton
{
    // Check autorisation to access Photo Library before uploading
    if (@available(iOS 14, *)) {
        [PhotosFetch.shared checkPhotoLibraryAuthorizationStatusFor:PHAccessLevelReadWrite for:self onAccess:^{
            // Open local albums view controller in new navigation controller
            UIStoryboard *localAlbumsSB = [UIStoryboard storyboardWithName:@"LocalAlbumsViewController" bundle:nil];
            LocalAlbumsViewController *localAlbumsVC = [localAlbumsSB instantiateViewControllerWithIdentifier:@"LocalAlbumsViewController"];
            localAlbumsVC.categoryId = self.categoryId;
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:localAlbumsVC];
            navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            navController.modalPresentationStyle = UIModalPresentationPageSheet;
            [self presentViewController:navController animated:YES completion:nil];
        } onDeniedAccess:^{}];
    } else {
        // Fallback on earlier versions
        [PhotosFetch.shared checkPhotoLibraryAccessForViewController:self
                onAuthorizedAccess:^{
                    // Open local albums view controller in new navigation controller
                    UIStoryboard *localAlbumsSB = [UIStoryboard storyboardWithName:@"LocalAlbumsViewController" bundle:nil];
                    LocalAlbumsViewController *localAlbumsVC = [localAlbumsSB instantiateViewControllerWithIdentifier:@"LocalAlbumsViewController"];
                    localAlbumsVC.categoryId = self.categoryId;
                    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:localAlbumsVC];
                    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                    navController.modalPresentationStyle = UIModalPresentationPageSheet;
                    [self presentViewController:navController animated:YES completion:nil];
                }
                onDeniedAccess:^{}
         ];
    }

    // Hide CreateAlbum and UploadImages buttons
    [self didCancelTapAddButton];
}

-(void)didTapUploadQueueButton
{
    // Open upload queue controller in new navigation controller
    UINavigationController *navController = nil;
    if (@available(iOS 13.0, *)) {
        UIStoryboard *uploadQueueSB = [UIStoryboard storyboardWithName:@"UploadQueueViewController" bundle:nil];
        UploadQueueViewController *uploadQueueVC = [uploadQueueSB instantiateViewControllerWithIdentifier:@"UploadQueueViewController"];
        navController = [[UINavigationController alloc] initWithRootViewController:uploadQueueVC];
    } else {
        // Fallback on earlier versions
        UIStoryboard *uploadQueueSB = [UIStoryboard storyboardWithName:@"UploadQueueViewControllerOld" bundle:nil];
        UploadQueueViewControllerOld *uploadQueueVC = [uploadQueueSB instantiateViewControllerWithIdentifier:@"UploadQueueViewControllerOld"];
        navController = [[UINavigationController alloc] initWithRootViewController:uploadQueueVC];
    }
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navController animated:YES completion:nil];
}


#pragma mark - Create Sub-Album

-(void)didTapCreateAlbumButton
{
    // Change colour of Upload Images button
    [self.createAlbumButton setBackgroundColor:[UIColor grayColor]];
    
    // Start creating album
    [self showCreateCategoryDialog];
}

-(void)showCreateCategoryDialog
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"createNewAlbum_title", @"New Album")
                                message:NSLocalizedString(@"createNewAlbum_message", @"Enter a name for this album:")
                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = AppVars.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbumDescription_placeholder", @"Description");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = AppVars.isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
            // Cancel action
            if (self.homeAlbumButton.isHidden) {
                [self didCancelTapAddButton];
            }
    }];
    
    self.createAlbumAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertAddButton", @"Add")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Create album
            [self addCategoryWithName:alert.textFields.firstObject.text
                           andComment:alert.textFields.lastObject.text
                             inParent:self.categoryId];
        }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.createAlbumAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)addCategoryWithName:(NSString *)albumName andComment:(NSString *)albumComment
                  inParent:(NSInteger)parentId
{
    // Display HUD during the update
    [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"createNewAlbumHUD_label", @"Creating Album…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    
    // Create album
    [AlbumService createCategoryWithName:albumName
                  withStatus:@"public"
                  andComment:albumComment
                    inParent:parentId
                OnCompletion:^(NSURLSessionTask *task, BOOL createdSuccessfully) {
            if(createdSuccessfully)
            {
                // Reload data
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];

                // Hide HUD
                [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
                    [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                        // Reset buttons
                        [self didCancelTapAddButton];
                    }];
                }];
            }
            else
            {
                // Hide HUD and inform user
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self.navigationController dismissPiwigoErrorWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error") message:NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album") errorMessage:@"" completion:^{
                        // Reset buttons
                        [self didCancelTapAddButton];
                    }];
                }];
            }
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Hide HUD and inform user
            [self.navigationController hidePiwigoHUDWithCompletion:^{
                [self.navigationController dismissPiwigoErrorWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error") message:NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album") errorMessage:error.localizedDescription completion:^{
                    // Reset buttons
                    [self didCancelTapAddButton];
                }];
            }];
        }];
}


#pragma mark - Select Images

-(void)didTapSelect
{
    // Activate Images Selection mode
    self.isSelect = YES;
    
    // Disable interaction with category cells and scroll to first image cell if needed
    NSInteger numberOfImageCells = 0;
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {

        // Disable user interaction with category cell
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
            [categoryCell.contentView setAlpha:0.5];
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
    
    // Update navigation bar and toolbar
    [self initButtonsInSelectionMode];
}

-(void)cancelSelect
{
	// Disable Images Selection mode
    self.isSelect = NO;
    
    // Update navigation bar and toolbar
	[self updateButtonsInPreviewMode];
    
    // Enable interaction with category cells and deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Enable user interaction with category cell
        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
            [categoryCell.contentView setAlpha:1.0];
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
            NSNumber *imageIdObject = [NSNumber numberWithInteger:imageCell.imageData.imageId];
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
                
                // Update the navigation bar
                [self updateButtonsInSelectionMode];
            }
        }
    }
    
    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImageIds = [NSMutableArray new];
    }
}


#pragma mark - Edit Images Parameters

-(void)editSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self setEnableStateOfButtons:NO];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    }
    else {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    self.selectedImagesToEdit = [NSMutableArray new];
    self.selectedImageIdsToEdit = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeEdit];
}

-(void)retrieveImageDataBeforeEdit
{
    if (self.selectedImageIdsToEdit.count <= 0) {
        [self.navigationController hidePiwigoHUDWithCompletion:^{ [self editImages]; }];
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageUtilities getInfosForID:[[self.selectedImageIdsToEdit lastObject] integerValue]
        completion:^(PiwigoImageData * _Nonnull imageData) {
            // Store image data
            [self.selectedImagesToEdit insertObject:imageData atIndex:0];
            
            // Image info retrieved
            [self.selectedImageIdsToEdit removeLastObject];

            // Update HUD
            [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToEdit.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeEdit];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self.navigationController dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                [self retrieveImageDataBeforeEdit];
            }];
        }
    ];
}

-(void)editImages
{
    switch (self.selectedImagesToEdit.count) {
        case 0:     // No image => End (should never happened)
        {
            [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
                [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                    [self cancelSelect];
                }];
            }];
            break;
        }
            
        default:    // Several images
        {
            // Present EditImageParams view
            UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageParamsViewController" bundle:nil];
            EditImageParamsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageParamsViewController"];
            editImageVC.images = [self.selectedImagesToEdit copy];
            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
            editImageVC.hasTagCreationRights = NetworkVarsObjc.hasAdminRights ||
                (NetworkVarsObjc.hasNormalRights && albumData.hasUploadRights);
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
    [self setEnableStateOfButtons:NO];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    }
    else {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    self.selectedImagesToDelete = [NSMutableArray new];
    self.selectedImagesToRemove = [NSMutableArray new];
    self.selectedImageIdsToDelete = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeDelete];
}

-(void)retrieveImageDataBeforeDelete
{
    if (self.selectedImageIdsToDelete.count <= 0) {
        [self.navigationController hidePiwigoHUDWithCompletion:^{
            [self askDeleteConfirmation];
        }];
        return;
    }
    
    // Image data are not complete when retrieved with pwg.categories.getImages
    [ImageUtilities getInfosForID:[[self.selectedImageIdsToDelete lastObject] integerValue]
        completion:^(PiwigoImageData * _Nonnull imageData) {
            // Split orphaned and non-orphaned images
            if (imageData.categoryIds.count > 1) {
                [self.selectedImagesToRemove insertObject:imageData atIndex:0];
            }
            else {
                [self.selectedImagesToDelete insertObject:imageData atIndex:0];
            }
        
            // Image info retrieved
            [self.selectedImageIdsToDelete removeLastObject];

            // Update HUD
            [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToDelete.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeDelete];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self.navigationController dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                [self retrieveImageDataBeforeDelete];
            }];
        }
    ];
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
        handler:^(UIAlertAction * action) {
            [self updateButtonsInSelectionMode];
        }];
    
    UIAlertAction* removeImagesAction = [UIAlertAction
        actionWithTitle: self.selectedImagesToDelete.count == 0 ? NSLocalizedString(@"removeSingleImage_title", @"Remove from Album") : NSLocalizedString(@"deleteCategory_orphanedImages", @"Delete Orphans")
        style: self.selectedImagesToDelete.count == 0 ? UIAlertActionStyleDefault : UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {

        // Display HUD during server update
        self.totalNumberOfImages = self.selectedImagesToRemove.count
                                 + (self.selectedImagesToDelete.count > 0);
        if (self.totalNumberOfImages > 1) {
            [self.navigationController showPiwigoHUDWithTitle:self.selectedImagesToDelete.count == 0 ?
                NSLocalizedString(@"removeSeveralImagesHUD_removing", @"Removing Photos…") :
                NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…")
                detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
        }
        else {
            [self.navigationController showPiwigoHUDWithTitle:self.selectedImagesToDelete.count == 0 ?
                NSLocalizedString(@"removeSingleImageHUD_removing", @"Removing Photo…") :
                NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…")
                detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
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
        [self.navigationController showPiwigoHUDWithTitle:self.selectedImagesToDelete.count > 1 ? NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") :
            NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…")
            detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];

        // Start deleting images
        [self deleteImages];
    }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteImagesAction];
    if (self.selectedImagesToRemove.count > 0) { [alert addAction:removeImagesAction]; }

    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)removeImages
{
    if (self.selectedImagesToRemove.count <= 0)
    {
        if (self.selectedImagesToDelete.count <= 0) {
            [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self cancelSelect];
                }];
            }];
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
    
    // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
    NSString *newImageCategories = [categoryIds componentsJoinedByString:@";"];
    NSDictionary *paramsDict = @{
        @"image_id" : [NSString stringWithFormat:@"%ld", (long)self.selectedImage.imageId],
        @"categories" : newImageCategories,
        @"multiple_value_mode" : @"replace"
    };
    
    // Send request to Piwigo server
    [ImageUtilities setInfosWith:paramsDict completion:^{
        // Remove image from current category in cache and update UI
        [[CategoriesData sharedInstance] removeImage:self.selectedImage fromCategory:[NSString stringWithFormat:@"%ld", (long)self.categoryId]];

        // Next image
        [self.selectedImagesToRemove removeLastObject];
        
        // Update HUD
        [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImagesToRemove.count / (float)self.totalNumberOfImages];

        // Next image
        [self removeImages];
    } failure:^(NSError * _Nonnull error) {
        // Error — Try again ?
        if (self.selectedImagesToRemove.count > 1) {
            [self cancelDismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed") message:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted.") errorMessage:error.localizedDescription cancel:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } dismiss:^{
                // Bypass image
                [self.selectedImagesToRemove removeLastObject];
                // Continue removing images
                [self removeImages];
            } retry:^{
                // Try relogin if unauthorized
                if (error.code == 401) {        // Unauthorized
                    // Try relogin
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate reloginAndRetryWithCompletion:^{
                        [self removeImages];
                    }];
                } else {
                    [self removeImages];
                }
            }];
        } else {
            [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed") message:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted.") errorMessage:error.localizedDescription dismiss:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                // Try relogin if unauthorized
                if (error.code == 401) {        // Unauthorized
                    // Try relogin
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate reloginAndRetryWithCompletion:^{
                        [self removeImages];
                    }];
                } else {
                    [self removeImages];
                }
            }];
        }
    }];
}

-(void)deleteImages
{
    if (self.selectedImagesToDelete.count <= 0)
    {
        [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
            [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                [self cancelSelect];
            }];
        }];
        return;
    }
    
    // Let's delete all images at once
    [ImageUtilities delete:self.selectedImagesToDelete completion:^{
        // Hide HUD
        [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
            [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                [self cancelSelect];
            }];
        }];
    } failure:^(NSError * _Nonnull error) {
        // Error — Try again ?
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed") message:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted.") errorMessage:[error localizedDescription] dismiss:^{
            [self.navigationController hidePiwigoHUDWithCompletion:^{
                [self updateButtonsInSelectionMode];
            }];
        } retry:^{
            // Try relogin if unauthorized
            NSInteger statusCode = [[[error userInfo] valueForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
            if (statusCode == 401) {        // Unauthorized
                // Try relogin
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate reloginAndRetryWithCompletion:^{
                    [self deleteImages];
                }];
            } else {
                [self deleteImages];
            }
        }];
    }];
}


#pragma mark - Share images

-(void)shareSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self setEnableStateOfButtons:NO];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    self.selectedImagesToShare = [NSMutableArray new];
    self.selectedImageIdsToShare = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeShare];
}

-(void)retrieveImageDataBeforeShare
{
    if (self.selectedImageIdsToShare.count <= 0) {
        [self.navigationController hidePiwigoHUDWithCompletion:^{
            [self checkPhotoLibraryAccessBeforeShare];
        }];
        return;
    }
    
    // Image data are not complete when retrieved using pwg.categories.getImages
    [ImageUtilities getInfosForID:[[self.selectedImageIdsToShare lastObject] integerValue]
        completion:^(PiwigoImageData * _Nonnull imageData) {
            // Store image data
            [self.selectedImagesToShare insertObject:imageData atIndex:0];
            
            // Image info retrieved
            [self.selectedImageIdsToShare removeLastObject];

            // Update HUD
            [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToShare.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeShare];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self.navigationController hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                [self retrieveImageDataBeforeShare];
            }];
        }
    ];
}

-(void)checkPhotoLibraryAccessBeforeShare
{
    // Check autorisation to access Photo Library (camera roll)
    if (@available(iOS 14, *)) {
        [PhotosFetch.shared checkPhotoLibraryAuthorizationStatusFor:PHAccessLevelAddOnly for:self
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
        [PhotosFetch.shared checkPhotoLibraryAccessForViewController:nil
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
    // To exclude some activity types
    NSMutableSet *excludedActivityTypes = [NSMutableSet new];

    // Create new activity provider items to pass to the activity view controller
    self.totalNumberOfImages = self.selectedImagesToShare.count;
    NSMutableArray *itemsToShare = [NSMutableArray new];
    for (PiwigoImageData *imageData in self.selectedImagesToShare) {
        if (imageData.isVideo) {
            // Case of a video
            ShareVideoActivityItemProvider *videoItemProvider = [[ShareVideoActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:videoItemProvider];

            // Exclude "assign to contact" activity
            [excludedActivityTypes addObject:UIActivityTypeAssignToContact];
        }
        else {
            // Case of an image
            ShareImageActivityItemProvider *imageItemProvider = [[ShareImageActivityItemProvider alloc]  initWithPlaceholderImage:imageData];
            
            // Use delegation to monitor the progress of the item method
            imageItemProvider.delegate = self;
            
            // Add to list of items to share
            [itemsToShare addObject:imageItemProvider];
        }
    }

    // Create an activity view controller with the activity provider item.
    // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    
    // Exclude camera roll activity if needed
    if (!hasCameraRollAccess) {
        // Exclude "camera roll" activity when the Photo Library is not accessible
        [excludedActivityTypes addObject:UIActivityTypeSaveToCameraRoll];
    }
    activityViewController.excludedActivityTypes = [excludedActivityTypes allObjects];

    // Delete image/video files and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
//        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
//            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            // Delete shared files & remove observers
            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShare object:nil];

            // Close HUD with success
            [self updatePiwigoHUDwithSuccessWithCompletion:^{
                [self hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                    // Deselect images
                    [self cancelSelect];
                    // Close ActivityView
                    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                }];
            }];
        }
        else {
            if (activityType == NULL) {
//                NSLog(@"User dismissed the view controller without making a selection.");
                [self updateButtonsInSelectionMode];
            }
            else {
                // Check what to do with selection
                if (self.selectedImageIds.count == 0) {
                    [self cancelSelect];
                } else {
                    [self setEnableStateOfButtons:YES];
                }

                // Cancel download task
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownload object:nil];

                // Delete shared file & remove observers
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDidShare object:nil];

                // Close ActivityView
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
        }
    }];
    
    // Present share image activity view controller
    activityViewController.popoverPresentationController.barButtonItem = self.shareBarButton;
    [self presentViewController:activityViewController animated:YES completion:nil];
}

-(void)cancelShareImages
{
    // Cancel image file download and remaining activity shares if any
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownload object:nil];
}


#pragma mark - Move/Copy images to Category

-(void)addImagesToCategory
{
    // Disable buttons
    [self setEnableStateOfButtons:NO];
    
    // Present alert to user
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:nil message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                        [self setEnableStateOfButtons:YES];
                                   }];
    
    UIAlertAction* copyAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
        UIStoryboard *copySB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
        SelectCategoryViewController *copyVC = [copySB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
        NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(self.categoryId), nil];
        [copyVC setInputWithParameter:parameter for:kPiwigoCategorySelectActionCopyImages];
        copyVC.delegate = self;                 // To re-enable toolbar
        copyVC.imageCopiedDelegate = self;      // To update image data after copy
        [self pushView:copyVC];
    }];
    
    UIAlertAction* moveAction = [UIAlertAction
                                 actionWithTitle:NSLocalizedString(@"moveImage_title", @"Move to Album")
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action) {
        UIStoryboard *moveSB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
        SelectCategoryViewController *moveVC = [moveSB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
        NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(self.categoryId), nil];
        [moveVC setInputWithParameter:parameter for:kPiwigoCategorySelectActionMoveImages];
        moveVC.delegate = self;         // To re-enable toolbar
        [self pushView:moveVC];
    }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:copyAction];
    [alert addAction:moveAction];
    
    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.moveBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - Add/remove image from favorites

-(void)loadFavorites
{
    // Should we load the favorites album?
    // pwg.users.favorites… methods available from Piwigo version 2.10
    if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending) &&
        (!NetworkVarsObjc.hasGuestRights) &&
        ([CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] == nil))
    {
        // Perform this load in the background
        NSLog(@"==> Loading favorites in the background...");
        // Unknown list -> initialise album and download list
        PiwigoAlbumData *favoritesAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
        [CategoriesData.sharedInstance updateCategories:@[favoritesAlbum]];
        [[CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] loadAllCategoryImageDataWithSort:self.currentSort
            forProgress:nil
           OnCompletion:^(BOOL completed) {
                // Reload image collection
                NSLog(@"==> Favorites loaded ;-)");
//                dispatch_async(dispatch_get_main_queue(), ^(void){
//                    [self.imagesCollection reloadData];
//                });
            }
        ];
    }
}

-(UIBarButtonItem *)getFavoriteBarButton {
    BOOL areFavorite = [CategoriesData.sharedInstance categoryWithId:self.categoryId containsImagesWithId:self.selectedImageIds];
    UIBarButtonItem *button = [UIBarButtonItem favoriteImageButton:areFavorite target:self];
    button.action = areFavorite ? @selector(removeFromFavorites) : @selector(addToFavorites);
    return button;
}

-(void)addToFavorites
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self setEnableStateOfButtons:NO];

    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    [self addImageToFavorites];
}

-(void)addImageToFavorites
{
    if (self.selectedImageIds.count <= 0) {
        // Close HUD with success
        [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
            [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                // Update button
                [self.favoriteBarButton setFavoriteImageFor:YES];
                self.favoriteBarButton.action = @selector(removeFromFavorites);
                // Deselect images
                [self cancelSelect];
                // Show favorite icons
                for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
                    if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                        ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                        imageCell.isFavorite = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:@[[NSNumber numberWithInteger:imageCell.imageData.imageId]]];
                    }
                }
            }];
        }];
        return;
    }

    // Get image data
    PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[[self.selectedImageIds lastObject] integerValue]];
    
    // Add image to favorites
    [ImageUtilities addToFavorites:imageData completion:^{
        // Update HUD
        [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIds.count / (float)self.totalNumberOfImages];

        // Image info retrieved
        [self.selectedImageIds removeLastObject];

        // Next image
        [self addImageToFavorites];
        
    } failure:^(NSError * _Nonnull error) {
        // Failed — Ask user if he/she wishes to retry
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageFavorites_title", @"Favorites") message:NSLocalizedString(@"imageFavoritesAddError_message", @"Failed to add this photo to your favorites.") errorMessage:error.localizedDescription dismiss:^{
            [self.navigationController hidePiwigoHUDWithCompletion:^{
                [self updateButtonsInSelectionMode];
            }];
        } retry:^{
            [self addImageToFavorites];
        }];
    }];
}

-(void)removeFromFavorites
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self setEnableStateOfButtons:NO];

    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self.navigationController showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    [self removeImageFromFavorites];
}

-(void)removeImageFromFavorites
{
    if (self.selectedImageIds.count <= 0) {
        // Close HUD with success
        [self.navigationController updatePiwigoHUDwithSuccessWithCompletion:^{
            [self.navigationController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                // Update button
                [self.favoriteBarButton setFavoriteImageFor:NO];
                self.favoriteBarButton.action = @selector(addToFavorites);
                // Deselect images
                [self cancelSelect];
                // Hide favorite icons
                for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
                    if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                        ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                        imageCell.isFavorite = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:@[[NSNumber numberWithInteger:imageCell.imageData.imageId]]];
                    }
                }
            }];
        }];
        return;
    }

    // Get image data
    PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[[self.selectedImageIds lastObject] integerValue]];
    
    // Add image to favorites
    [ImageUtilities removeFromFavorites:imageData completion:^{
        // Update HUD
        [self.navigationController updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIds.count / (float)self.totalNumberOfImages];

        // Image info retrieved
        [self.selectedImageIds removeLastObject];

        // Next image
        [self removeImageFromFavorites];
        
    } failure:^(NSError * _Nonnull error) {
        // Failed — Ask user if he/she wishes to retry
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageFavorites_title", @"Favorites") message:NSLocalizedString(@"imageFavoritesRemoveError_message", @"Failed to remove this photo from your favorites.") errorMessage:error.localizedDescription dismiss:^{
            [self.navigationController hidePiwigoHUDWithCompletion:^{
                [self updateButtonsInSelectionMode];
            }];
        } retry:^{
            [self removeImageFromFavorites];
        }];
    }];
}


#pragma mark - UICollectionView Headers & Footers

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
                header.commentLabel.textColor = [UIColor piwigoColorHeader];
                return header;
            }
            break;
        }
            
        case 1:    // Section 1 — Image collection
        {
            if(kind == UICollectionElementKindSectionFooter)
            {
                NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
                footer.noImagesLabel.textColor = [UIColor piwigoColorHeader];

                // Get number of images
                NSInteger totalImageCount = NSNotFound;
                if (self.categoryId == 0) {
                    // Only albums in Root Album => total number of images
                    for (PiwigoAlbumData *albumData in [[CategoriesData sharedInstance] getCategoriesForParentCategory:0]) {
                        if (totalImageCount == NSNotFound) { totalImageCount = 0; }
                        totalImageCount += albumData.totalNumberOfImages;
                    }
                } else {
                    // Number of images in current album
                    totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
                }

                if (totalImageCount == NSNotFound) {
                    // Is loading…
                    footer.noImagesLabel.text = NSLocalizedString(@"loadingHUD_label", @"Loading…");
                }
                else if (totalImageCount == 0) {
                    // Not loading and no images
                    footer.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
                }
                else {
                    // Display number of images…
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
                    footer.noImagesLabel.text = totalImageCount > 1 ?
                    [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]] :
                    [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]];
                }
                return footer;
            }
            break;
        }
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
    }

    return CGSizeZero;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    switch (section) {
        case 1:    // Section 1 — Image collection
        {
            NSString *footer = @"";
            // Get number of images
            NSInteger totalImageCount = NSNotFound;
            if (self.categoryId == 0) {
                // Only albums in Root Album => total number of images
                for (PiwigoAlbumData *albumData in [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId]) {
                    totalImageCount += albumData.totalNumberOfImages;
                }
            } else {
                // Number of images in current album
                totalImageCount = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].totalNumberOfImages;
            }

            if (totalImageCount == NSNotFound) {
                // Is loading…
                footer = NSLocalizedString(@"loadingHUD_label", @"Loading…");
            }
            else if (totalImageCount == 0) {
                // Not loading and no images
                footer = NSLocalizedString(@"noImages", @"No Images");
            }
            else {
                // Display number of images…
                NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
                footer = totalImageCount > 1 ?
                [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]] :
                [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), [numberFormatter stringFromNumber:[NSNumber numberWithInteger:totalImageCount]]];
            }
 
            if ([footer length] > 0) {
                NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontLight]};
                NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
                context.minimumScaleFactor = 1.0;
                CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:attributes
                                                         context:context];
                return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(footerRect.size.height));
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
        {
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
            }
            else if (self.categoryId == 0) {
                if (@available(iOS 13.0, *)) {
                    return UIEdgeInsetsMake(0, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
                } else {
                    return UIEdgeInsetsMake(10, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
                }
            }
            else {
                return UIEdgeInsetsMake(10, kAlbumMarginsSpacing, 0, kAlbumMarginsSpacing);
            }
            break;
        }
            
        default:            // Images
        {
            PiwigoAlbumData *albumData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
            if ([collectionView numberOfItemsInSection:section] == 0) {
                return UIEdgeInsetsMake(0, kImageMarginsSpacing, 0, kImageMarginsSpacing);
            }
            else if ([albumData.comment length] == 0) {
                return UIEdgeInsetsMake(4, kImageMarginsSpacing, 4, kImageMarginsSpacing);
            }
            else {
                return UIEdgeInsetsMake(10, kImageMarginsSpacing, 4, kImageMarginsSpacing);
            }
            break;
        }
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return 0.0;
            break;
            
        default:            // Images
            return (CGFloat)[ImagesCollection imageCellVerticalSpacingForCollectionType:kImageCollectionFull];
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    switch (section) {
        case 0:             // Albums
            return (CGFloat)kAlbumCellSpacing;
            break;
            
        default:            // Images
            return (CGFloat)[ImagesCollection imageCellHorizontalSpacingForCollectionType:kImageCollectionFull];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:             // Albums (see XIB file)
        {
            float nberAlbumsPerRow = [ImagesCollection numberOfAlbumsPerRowForViewInPortrait:collectionView withMaxWidth:384.0];
            CGFloat size = (CGFloat)[ImagesCollection albumSizeForView:collectionView andNberOfAlbumsPerRowInPortrait:nberAlbumsPerRow];
            return CGSizeMake(size, 156.5);
            break;
        }
            
        default:            // Images
        {
            // Calculate the optimum image size
            CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
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
                [cell.contentView setAlpha:0.5];
                [cell setUserInteractionEnabled:NO];
            } else {
                [cell.contentView setAlpha:1.0];
                [cell setUserInteractionEnabled:YES];
            }
            
            return cell;
        }
            
        default:            // Images
        {
            ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
            
            if (self.albumData.images.count > indexPath.row) {
                // Create cell from Piwigo data
                PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
//                NSLog(@"Index:%ld => image ID:%ld - %@", indexPath.row, (long)imageData.imageId, imageData.fileName);
                [cell setupWithImageData:imageData inCategoryId:self.categoryId];
                cell.isSelected = [self.selectedImageIds containsObject:[NSNumber numberWithInteger:imageData.imageId]];

                // pwg.users.favorites… methods available from Piwigo version 2.10
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] == NSOrderedAscending)) {
                    cell.isFavorite = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:@[[NSNumber numberWithInteger:imageData.imageId]]];
                }
                
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
            NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:collectionView imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
            
            // Load image data in advance if possible (page after page…)
            if ((indexPath.row > fmaxf(roundf(2 * imagesPerPage / 3.0), [collectionView numberOfItemsInSection:1] - roundf(imagesPerPage / 3.0))) &&
                (self.albumData.images.count < [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
            {
                [self.albumData loadMoreImagesOnCompletion:^{
                    [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
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
                // Add category to list of recent albums
                NSDictionary *userInfo = @{@"categoryId" : [NSNumber numberWithLong:self.categoryId]};
                [[NSNotificationCenter defaultCenter] postNotificationName:[PwgNotificationsObjc addRecentAlbum] object:nil userInfo:userInfo];

                // Selection mode not active => display full screen image
                UIStoryboard *imageDetailSB = [UIStoryboard storyboardWithName:@"ImageDetailViewController" bundle:nil];
                self.imageDetailView = [imageDetailSB instantiateViewControllerWithIdentifier:@"ImageDetailViewController"];
                self.imageDetailView.imageIndex = indexPath.row;
                self.imageDetailView.categoryId = self.categoryId;
                self.imageDetailView.images = [self.albumData.images copy];
                self.imageDetailView.hidesBottomBarWhenPushed = YES;
                self.imageDetailView.imgDetailDelegate = self;
                self.imageDetailView.modalPresentationCapturesStatusBarAppearance = YES;
//                self.imageDetailView.transitioningDelegate = self;
//                self.selectedCellImageViewSnapshot = [self.selectedCell.cellImage snapshotViewAfterScreenUpdates:NO];
                [self.navigationController pushViewController:self.imageDetailView animated:YES];
            }
            else
            {
                // Selection mode active => add/remove image from selection
                NSNumber *imageIdObject = [NSNumber numberWithInteger:selectedCell.imageData.imageId];
                if(![self.selectedImageIds containsObject:imageIdObject]) {
                    [self.selectedImageIds addObject:imageIdObject];
                    selectedCell.isSelected = YES;
                } else {
                    selectedCell.isSelected = NO;
                    [self.selectedImageIds removeObject:imageIdObject];
                }
                
                // and update nav buttons
                [self updateButtonsInSelectionMode];
            }
        }
    }
}


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add Category action
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        [self.createAlbumAction setEnabled:(textField.text.length >= 1)];
    }
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add Category action if album name is non null
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        [self.createAlbumAction setEnabled:(finalString.length >= 1)];
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Add Category action
    if ([textField.placeholder isEqualToString:NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name")])
    {
        [self.createAlbumAction setEnabled:NO];
    }
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}


#pragma mark - ImageDetailDelegate Methods

-(void)didSelectImageWithId:(NSInteger)imageId
{
    // Determine index of image
    NSInteger indexOfImage = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *image, NSUInteger index, BOOL * _Nonnull stop) {
     return image.imageId == imageId;
    }];
    
    // Scroll view to center image
    if (indexOfImage != NSNotFound) {
        self.imageOfInterest = [NSIndexPath indexPathForItem:indexOfImage inSection:1];
        [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
    }
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:1];
}

-(void)needToLoadMoreImages
{
    [self.albumData loadMoreImagesOnCompletion:^{
        if(self.imageDetailView != nil)
        {
            self.imageDetailView.images = [self.albumData.images mutableCopy];
        }
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
    }];
}


#pragma mark - EditImageParamsDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Deselect image
    [self.selectedImageIds removeObject:[NSNumber numberWithInteger:imageId]];
    [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
}

-(void)didRenameFileOfImage:(PiwigoImageData *)imageData
{
    // Update image data
    [self.albumData updateImage:imageData];
}

-(void)didChangeParamsOfImage:(PiwigoImageData *)params
{
    // Update image data
    NSInteger indexOfUpdatedImage = [self.albumData updateImage:params];
    if (indexOfUpdatedImage != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfUpdatedImage inSection:1];
        [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
    }
}

-(void)didFinishEditingParameters
{
    [self cancelSelect];
}


#pragma mark - SelectCategoryDelegate Methods

-(void)didSelectCategoryWithId:(NSInteger)category
{
    if (category == NSNotFound) {
        [self setEnableStateOfButtons:YES];
    } else {
        [self cancelSelect];
    }
}


#pragma mark - SelectCategoryImageCopiedDelegate Methods

-(void)didCopyImageWithData:(PiwigoImageData *)imageData
{
    // Determine index of updated image
    NSMutableArray<PiwigoImageData *> *newImages = [[NSMutableArray<PiwigoImageData *> alloc] initWithArray:self.albumData.images];
    NSInteger indexOfUpdatedImage = [newImages indexOfObjectPassingTest:^BOOL(PiwigoImageData *image, NSUInteger index, BOOL * _Nonnull stop) {
     return image.imageId == imageData.imageId;
    }];

    // Update image data
    if (indexOfUpdatedImage != NSNotFound) {
        [newImages replaceObjectAtIndex:indexOfUpdatedImage withObject:imageData];
        self.albumData.images = newImages;
    }
}


#pragma mark - ChangedSettingsDelegate Methods

-(void)didChangeDefaultAlbum
{
    // Change default album
    self.categoryId = AlbumVars.defaultCategory;

    // Reset Add button icon
    if (self.categoryId == 0) {
        [self.addButton setImage:[UIImage imageNamed:@"createLarge"] forState:UIControlStateNormal];
    } else {
        [self.addButton setImage:[UIImage imageNamed:@"add"] forState:UIControlStateNormal];
    }

    // Reload category data
    self.isCachedAtInit = FALSE;
    [self getCategoryData:nil];
}


#pragma mark - CategorySortObjcDelegate Methods

//-(void)didSelectCategorySortType:(kPiwigoSortObjc)sortType
//{
//	self.currentSort = sortType;
//    [self.albumData updateImageSort:sortType OnCompletion:^{
////        NSLog(@"didSelectCategorySortType:Sorting images…");
//        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
//    }];
//}


#pragma mark - Push Views (incl. CategoryCollectionViewCellDelegate Method)

-(void)pushCategoryView:(UIViewController *)viewController
{
    // Push sub-album, Discover or Favorites album
    if ([viewController isKindOfClass:[AlbumImagesViewController class]]) {
        // Push sub-album view
        [self.navigationController pushViewController:viewController animated:YES];
    }
    else {
        // Push album list
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            viewController.modalPresentationStyle = UIModalPresentationPopover;
            viewController.popoverPresentationController.sourceView = self.imagesCollection;
            viewController.popoverPresentationController.permittedArrowDirections = 0;
            [self.navigationController presentViewController:viewController animated:YES completion:nil];
        }
        else {
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
            navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            [self.navigationController presentViewController:navController animated:YES completion:nil];
        }
    }
}

-(void)pushView:(UIViewController *)viewController
{
    // Push sub-album, Discover or Favorites album
    if (([viewController isKindOfClass:[DiscoverImagesViewController class]]) ||
        ([viewController isKindOfClass:[FavoritesImagesViewController class]]) ) {
        // Push sub-album view
        [self.navigationController pushViewController:viewController animated:YES];
    }
    else {
        // Push album list or tag list
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            viewController.modalPresentationStyle = UIModalPresentationPopover;
            if ([viewController isKindOfClass:[SelectCategoryViewController class]]) {
                viewController.popoverPresentationController.barButtonItem = self.moveBarButton;
                viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                [self.navigationController presentViewController:viewController animated:YES completion:nil];
            }
            else if ([viewController isKindOfClass:[TagSelectorViewController class]]) {
                viewController.popoverPresentationController.barButtonItem = self.discoverBarButton;
                viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
                [self.navigationController presentViewController:viewController animated:YES completion:nil];
            }
            else if ([viewController isKindOfClass:[EditImageParamsViewController class]]) {
                // Push Edit view embedded in navigation controller
                UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
                navController.modalPresentationStyle = UIModalPresentationPopover;
                navController.popoverPresentationController.barButtonItem = self.actionBarButton;
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
}


#pragma mark - ShareImageActivityItemProviderDelegate Methods

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider withTitle:(NSString *)title
{
    // Show HUD to let the user know the image is being downloaded in the background.
    NSString *detailsLabel = [NSString stringWithFormat:@"%ld / %ld", (long)(self.totalNumberOfImages - self.selectedImageIds.count + 1), (long)self.totalNumberOfImages];
    [self.presentedViewController showPiwigoHUDWithTitle:title detail:detailsLabel buttonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel") buttonTarget:self buttonSelector:@selector(cancelShareImages) inMode:MBProgressHUDModeAnnularDeterminate];
}

-(void)imageActivityItemProvider:(UIActivityItemProvider *)imageActivityItemProvider preprocessingProgressDidUpdate:(float)progress
{
    // Update HUD
    [self.presentedViewController updatePiwigoHUDWithProgress:progress];
}

-(void)imageActivityItemProviderPreprocessingDidEnd:(UIActivityItemProvider *)imageActivityItemProvider withImageId:(NSInteger)imageId
{
    // Close HUD
    NSNumber *imageIdObject = [NSNumber numberWithInteger:imageId];
    if ([imageActivityItemProvider isCancelled]) {
        [self.presentedViewController hidePiwigoHUDWithCompletion:^{ }];
    } else {
        if ([self.selectedImageIds containsObject:imageIdObject]) {
            // Remove image from selection
            [self.selectedImageIds removeObject:imageIdObject];
            [self updateButtonsInSelectionMode];

            // Close HUD if last image
            if ([self.selectedImageIds count] == 0) {
                [self.presentedViewController updatePiwigoHUDwithSuccessWithCompletion:^{
                    [self.presentedViewController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{ }];
                }];
            }
        }
    }
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message
{
    // Cancel remaining shares
    [self cancelShareImages];
    
    // Close HUD if needed
    [self.presentedViewController hidePiwigoHUDWithCompletion:^{ }];
    
    // Display error alert after trying to share image
    [self.presentedViewController dismissPiwigoErrorWithTitle:title message:message errorMessage:@"" completion:^{
        // Close ActivityView
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }];
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height;
//    NSLog(@"==>> %f", scrollView.contentOffset.y + navBarHeight);
    if ((roundf(scrollView.contentOffset.y + navBarHeight) > 1) ||
        (self.categoryId != AlbumVars.defaultCategory)) {
        // Show navigation bar border
        if (@available(iOS 13.0, *)) {
            UINavigationItem *navBar = self.navigationItem;
            UINavigationBarAppearance *barAppearance = navBar.standardAppearance;
            UIColor *shadowColor = AppVars.isDarkPaletteActive ? [UIColor colorWithWhite:1.0 alpha:0.15] : [UIColor colorWithWhite:0.0 alpha:0.3];
            if (barAppearance.shadowColor != shadowColor) {
                barAppearance.shadowColor = shadowColor;
                navBar.scrollEdgeAppearance = barAppearance;
            }
        }
    } else {
        // Hide navigation bar border
        if (@available(iOS 13.0, *)) {
            UINavigationItem *navBar = self.navigationItem;
            UINavigationBarAppearance *barAppearance = navBar.standardAppearance;
            if (barAppearance.shadowColor != [UIColor clearColor]) {
                barAppearance.shadowColor = [UIColor clearColor];
                navBar.scrollEdgeAppearance = barAppearance;
            }
        }
    }
}


#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // Animates Cancel button appearance
    [searchBar setShowsCancelButton:YES animated:YES];
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    // Title forgotten when searching immediately after launch
    if (self.categoryId == 0) {
        self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
    } else {
        self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
    }
    
    // Animates Cancel button disappearance
    [searchBar setShowsCancelButton:NO animated:YES];
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
    NSString *searchString = [searchController.searchBar text];
    
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

    UIAlertAction* favoritesSelectorAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"categoryDiscoverFavorites_title", @"Your favorites")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Show tags for selecting images
            [self discoverFavoritesImages];
         }];
    
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
    if ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)
    {
        [alert addAction:favoritesSelectorAction];
    }
    [alert addAction:tagSelectorAction];
    [alert addAction:mostVisitedAction];
    [alert addAction:bestRatedAction];
    [alert addAction:recentAction];
    
    // Present list of Discover views
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.discoverBarButton;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
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
    UIStoryboard *tagSelectorSB = [UIStoryboard storyboardWithName:@"TagSelectorViewController" bundle:nil];
    TagSelectorViewController *tagSelectorVC = [tagSelectorSB instantiateViewControllerWithIdentifier:@"TagSelectorViewController"];
    tagSelectorVC.tagSelectedDelegate = self;
    [self pushView:tagSelectorVC];
}

-(void)discoverFavoritesImages
{
    // Create Discover view
    FavoritesImagesViewController *discoverController = [[FavoritesImagesViewController alloc] init];
    [self pushView:discoverController];
}

#pragma mark - TagSelectViewDelegate Methods

-(void)pushTaggedImagesView:(UIViewController *)viewController
{
    // Push sub-album view
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
