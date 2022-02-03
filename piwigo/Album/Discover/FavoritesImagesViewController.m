//
//  FavoritesImagesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/10/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AlbumData.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "FavoritesImagesViewController.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"

@interface FavoritesImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UIGestureRecognizerDelegate, ImageDetailDelegate, EditImageParamsDelegate, SelectCategoryDelegate, SelectCategoryImageCopiedDelegate, ShareImageActivityItemProviderDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, assign) CGSize imageCellSize;
@property (nonatomic, assign) NSInteger didScrollToImageIndex;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL displayImageTitles;

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

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger totalNumberOfImages;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIds;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *touchedImageIds;

@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToEdit;
@property (nonatomic, strong) NSMutableArray<PiwigoImageData *> *selectedImagesToEdit;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToDelete;
@property (nonatomic, strong) NSMutableArray<PiwigoImageData *> *selectedImagesToDelete;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *selectedImageIdsToShare;
@property (nonatomic, strong) NSMutableArray<PiwigoImageData *> *selectedImagesToShare;
@property (nonatomic, strong) PiwigoImageData *selectedImage;

@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

//#ifndef DEBUG_LIFECYCLE
//#define DEBUG_LIFECYCLE
//#endif

@implementation FavoritesImagesViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        // Initialisation
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
        self.displayImageTitles = AlbumVars.displayImageTitles;
        
        // Initialise selection mode
        self.isSelect = NO;
        self.touchedImageIds = [NSMutableArray new];
        self.selectedImageIds = [NSMutableArray new];

        // Collection of images
        self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagesCollection.backgroundColor = [UIColor clearColor];
        self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
        self.imagesCollection.delegate = self;
        self.imagesCollection.dataSource = self;
        
        [self.imagesCollection registerNib:[UINib nibWithNibName:@"ImageCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        
        [self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Navigation bar and toolbar buttons
        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(didTapSelect)];
        [self.selectBarButton setAccessibilityIdentifier:@"Select"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];

        // Hide toolbar
        self.navigationController.toolbarHidden = YES;

        // Albums related Actions & Menus
        if (@available(iOS 14.0, *)) {
            // Copy images to album
            self.imagesCopyAction = [UIAction actionWithTitle:NSLocalizedString(@"copyImage_title", @"Copy to Album") image:[UIImage systemImageNamed:@"rectangle.stack.badge.plus"] identifier:@"Copy" handler:^(__kindof UIAction * _Nonnull action) {
                
                // Disable buttons during action
                [self setEnableStateOfButtons:NO];
                
                // Present album selector for copying image
                UIStoryboard *copySB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
                SelectCategoryViewController *copyVC = [copySB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
                NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(kPiwigoFavoritesCategoryId), nil];
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
                NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(kPiwigoFavoritesCategoryId), nil];
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
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];

    // Calculates size of image cells
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:self.imagesCollection imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
    self.imageCellSize = CGSizeMake(size, size);

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette)
                                                 name:PwgNotificationsObjc.paletteChanged object:nil];
}

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
    NSArray *headers = [self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader];
    if (headers.count > 0) {
        CategoryHeaderReusableView *header = headers.firstObject;
        header.commentLabel.textColor = [UIColor piwigoColorHeader];
    }
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell*)cell;
            [imageCell applyColorPalette];
        }
    }
    NSArray *footers = [self.imagesCollection visibleSupplementaryViewsOfKind:UICollectionElementKindSectionFooter];
    if (footers.count > 0) {
        NberImagesFooterCollectionReusableView *footer = footers.firstObject;
        footer.noImagesLabel.textColor = [UIColor piwigoColorHeader];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
#if defined(DEBUG_LIFECYCLE)
    NSLog(@"viewWillAppear    => ID:%ld", (long)kPiwigoFavoritesCategoryId);
#endif
    // Initialise data source
    self.albumData = [[AlbumData alloc] initWithCategoryId:kPiwigoFavoritesCategoryId andQuery:@""];

    // Set navigation bar buttons
    [self updateButtonsInPreviewMode];

    // Set colors, fonts, etc.
    [self applyColorPalette];
    
    // Initialise favorite album in cache if needed
    if ([[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId] == nil) {
        PiwigoAlbumData *discoverAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoFavoritesCategoryId];
        [[CategoriesData sharedInstance] updateCategories:@[discoverAlbum]];
    }

    // Load, sort images and reload collection
    NSArray *oldImageList = self.albumData.images;
    [self.albumData updateImageSort:(kPiwigoSortObjc)AlbumVars.defaultSort onCompletion:^{
        // Reset navigation bar buttons after image load
        [self updateButtonsInPreviewMode];
        [self reloadImagesCollectionFrom:oldImageList];
    }
    onFailure:^(NSURLSessionTask *task, NSError *error) {
        [self dismissPiwigoErrorWithTitle:NSLocalizedString(@"albumPhotoError_title", @"Get Album Photos Error") message:NSLocalizedString(@"albumPhotoError_message", @"Failed to get album photos (corrupt image in your album?)") errorMessage:error.localizedDescription completion:^{}];
    }];
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
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Update the navigation bar on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Calculates new size of image cells
        CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:self.imagesCollection imagesPerRowInPortrait:AlbumVars.thumbnailsPerRowInPortrait];
        self.imageCellSize = CGSizeMake(size, size);

        // Reload colelction
        [self.imagesCollection reloadData];
        
        // Update buttons if necessary
        if (self.isSelect) {
            [self initButtonsInSelectionMode];
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
    
    if (@available(iOS 15, *)) {
        // Keep title
    } else {
        // Do not show album title in backButtonItem of child view to provide enough space for image title
        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
        if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
            self.title = @"";
        }
    }
}

-(void)dealloc
{
    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PwgNotificationsObjc.paletteChanged object:nil];
}


#pragma mark - Buttons in Preview mode

-(void)updateButtonsInPreviewMode
{
    // Title
    self.title = [[[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId] name];

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


#pragma mark - Buttons in Selection mode

-(void)initButtonsInSelectionMode {
    // Hide back, Settings, Upload and Home buttons
    [self.navigationItem setHidesBackButton:YES];

    // Button displayed in all circumstances
    self.shareBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareSelection)];
    self.shareBarButton.tintColor = [UIColor piwigoColorOrange];

    if (@available(iOS 14, *)) {
        // Interface depends on device and orientation
        UIInterfaceOrientation orientation = UIApplication.sharedApplication.windows.firstObject.windowScene.interfaceOrientation;

        // User with admin or upload rights can do everything
        if (NetworkVarsObjc.hasAdminRights) {
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
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
                if ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [rightBarButtonItems insertObjects:@[self.favoriteBarButton] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 1)]];
                }
                [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:YES];

                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        }
        else if (!NetworkVarsObjc.hasGuestRights &&
                 ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
        if (NetworkVarsObjc.hasAdminRights) {
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
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
                if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
                    self.favoriteBarButton = [self getFavoriteBarButton];
                    [rightBarButtonItems insertObjects:@[self.favoriteBarButton] atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 1)]];
                }
                [self.navigationItem setRightBarButtonItems:rightBarButtonItems animated:YES];

                // Hide toolbar
                [self.navigationController setToolbarHidden:YES animated:YES];
            }
        }
        else if (!NetworkVarsObjc.hasGuestRights &&
                 ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
    if (NetworkVarsObjc.hasAdminRights)
    {
        self.cancelBarButton.enabled = YES;
        self.actionBarButton.enabled = hasImagesSelected;
        self.shareBarButton.enabled = hasImagesSelected;
        self.deleteBarButton.enabled = hasImagesSelected;
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
    else      // Case of guest, generic or normal user
    {
        // Left side of navigation bar
        self.cancelBarButton.enabled = YES;

        // Right side of navigation bar
        /// — guests can share photo of high-resolution or not
        /// — non-guest users can set favorites in addition
        self.shareBarButton.enabled = hasImagesSelected;
        if (!NetworkVarsObjc.hasGuestRights && ([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
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
    if (([@"2.10.0" compare:NetworkVarsObjc.pwgVersion options:NSNumericSearch] != NSOrderedDescending)) {
        self.favoriteBarButton.enabled = state;
    }
}


#pragma mark - Category Data

-(void)reloadImagesCollectionFrom:(NSArray<PiwigoImageData*> *)oldImages
{
    if (oldImages.count == 0) {
        [self.imagesCollection reloadData];
    }
    else {
        for (NSIndexPath *indexPath in self.imagesCollection.indexPathsForVisibleItems) {
            // Retrieve old image Id
            if (indexPath.item >= oldImages.count) { continue; }
            NSInteger oldImageId = oldImages[indexPath.item].imageId;
            
            // Did we replace a dummy image with a real image?
            NSInteger newImageId = self.albumData.images[indexPath.item].imageId;
            if (newImageId == oldImageId) { continue; }
            
            // We should update this cell
            [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
        }
    }
}

-(void)removeImageWithId:(NSInteger)imageId
{
    // Remove image from the selection
    NSNumber *imageIdObject = [NSNumber numberWithInteger:imageId];
    if ([self.selectedImageIds containsObject:imageIdObject]) {
        [self.selectedImageIds removeObject:imageIdObject];
    }

    // Get index of deleted image
    NSInteger indexOfExistingItem = [self.albumData.images indexOfObjectPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger oldIdx, BOOL * _Nonnull stop) {
     return obj.imageId == imageId;
    }];
    if (indexOfExistingItem != NSNotFound) {
        // Remove image from data source
        NSMutableArray<PiwigoImageData *> *imageList = [self.albumData.images mutableCopy];
        [imageList removeObjectAtIndex:indexOfExistingItem];
        self.albumData.images = imageList;
        // Delete corresponding cell
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


#pragma mark - Select Images

-(void)didTapSelect
{
    // Activate Images Selection mode
    self.isSelect = YES;
    
    // Initialisae navigation bar and toolbar
    [self initButtonsInSelectionMode];
}

-(void)cancelSelect
{
    // Disable Images Selection mode
    self.isSelect = NO;
    
    // Update navigation bar and toolbar
    [self updateButtonsInPreviewMode];

    // Deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Deselect image cell and disable interaction
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            if(imageCell.isSelected) imageCell.isSelection = NO;
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
            NSNumber *imageIdObject = [NSNumber numberWithInteger:imageCell.imageData.imageId];
            if (![self.touchedImageIds containsObject:imageIdObject]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImageIds addObject:imageIdObject];
                
                // Update the selection state
                if(![self.selectedImageIds containsObject:imageIdObject]) {
                    [self.selectedImageIds addObject:imageIdObject];
                    imageCell.isSelection = YES;
                } else {
                    imageCell.isSelection = NO;
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


#pragma mark - Edit images

-(void)editSelection
{
    if (self.selectedImageIds.count <= 0) return;

    // Disable buttons
    [self setEnableStateOfButtons:NO];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    }
    else {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }
    
    // Retrieve image data
    self.selectedImagesToEdit = [NSMutableArray new];
    self.selectedImageIdsToEdit = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeEdit];
}

-(void)retrieveImageDataBeforeEdit
{
    if (self.selectedImageIdsToEdit.count <= 0) {
        [self hidePiwigoHUDWithCompletion:^{ [self editImages]; }];
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
            [self updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToEdit.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeEdit];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                // Try relogin if unauthorized
                if (error.code == 401) {        // Unauthorized
                    // Try relogin
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate reloginAndRetryWithCompletion:^{
                        [self retrieveImageDataBeforeEdit];
                    }];
                } else {
                    [self retrieveImageDataBeforeEdit];
                }
            }];
        }
    ];
}

-(void)editImages
{
    switch (self.selectedImagesToEdit.count) {
        case 0:     // No image => End (should never happened)
        {
            [self updatePiwigoHUDwithSuccessWithCompletion:^{
                [self hidePiwigoHUDWithCompletion:^{ [self cancelSelect]; }];
            }];
            break;
        }
            
        default:    // Several images
        {
            // Present EditImageParams view
            UIStoryboard *editImageSB = [UIStoryboard storyboardWithName:@"EditImageParamsViewController" bundle:nil];
            EditImageParamsViewController *editImageVC = [editImageSB instantiateViewControllerWithIdentifier:@"EditImageParamsViewController"];
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
    [self setEnableStateOfButtons:NO];
    
    // Display HUD
    self.totalNumberOfImages = self.selectedImageIds.count;
    if (self.totalNumberOfImages > 1) {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    }
    else {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    self.selectedImagesToDelete = [NSMutableArray new];
    self.selectedImageIdsToDelete = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeDelete];
}

-(void)retrieveImageDataBeforeDelete
{
    if (self.selectedImageIdsToDelete.count <= 0) {
        [self hidePiwigoHUDWithCompletion:^{ [self askDeleteConfirmation]; }];
        return;
    }
    
    // Image data are not complete when retrieved with pwg.categories.getImages
    [ImageUtilities getInfosForID:[[self.selectedImageIdsToDelete lastObject] integerValue]
        completion:^(PiwigoImageData * _Nonnull imageData) {
            // Collect orphaned and non-orphaned images
            [self.selectedImagesToDelete insertObject:imageData atIndex:0];
        
            // Image info retrieved
            [self.selectedImageIdsToDelete removeLastObject];

            // Update HUD
            [self updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToDelete.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeDelete];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                // Try relogin if unauthorized
                if (error.code == 401) {        // Unauthorized
                    // Try relogin
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate reloginAndRetryWithCompletion:^{
                        [self retrieveImageDataBeforeDelete];
                    }];
                } else {
                    [self retrieveImageDataBeforeDelete];
                }
            }];
        }
    ];
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
            [self updateButtonsInSelectionMode];
        }];
    
    UIAlertAction* deleteImagesAction = [UIAlertAction
        actionWithTitle:self.selectedImagesToDelete.count > 1 ? [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_title", @"Delete %@ Images"), @(self.selectedImagesToDelete.count)] : NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            
            // Display HUD during server update
            [self showPiwigoHUDWithTitle:self.selectedImagesToDelete.count > 1 ? NSLocalizedString(@"deleteSingleImageHUD_deleting", @"Deleting Image…") :
                NSLocalizedString(@"deleteSeveralImagesHUD_deleting", @"Deleting Images…")
                detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];

            // Start deleting images
            [self deleteImages];
       }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteImagesAction];

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

-(void)deleteImages
{
    if (self.selectedImagesToDelete.count <= 0)
    {
        [self updatePiwigoHUDwithSuccessWithCompletion:^{
            [self hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                [self cancelSelect];
            }];
        }];
        return;
    }
    
    // Let's delete all images at once
    [ImageUtilities delete:self.selectedImagesToDelete completion:^{
        // Hide HUD
        [self updatePiwigoHUDwithSuccessWithCompletion:^{
            [self hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                [self cancelSelect];
            }];
        }];
    } failure:^(NSError * _Nonnull error) {
        // Error — Try again ?
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed") message:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted.") errorMessage:[error localizedDescription] dismiss:^{
            [self hidePiwigoHUDWithCompletion:^{
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
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }
    
    // Retrieve image data
    self.selectedImagesToShare = [NSMutableArray new];
    self.selectedImageIdsToShare = [NSMutableArray arrayWithArray:[self.selectedImageIds mutableCopy]];
    [self retrieveImageDataBeforeShare];
}

-(void)retrieveImageDataBeforeShare
{
    if (self.selectedImageIdsToShare.count <= 0) {
        [self hidePiwigoHUDWithCompletion:^{
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
            [self updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIdsToShare.count / (float)self.totalNumberOfImages];

            // Next image
            [self retrieveImageDataBeforeShare];
        }
        failure:^(NSError * _Nonnull error) {
            // Failed — Ask user if he/she wishes to retry
            [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed") message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?") errorMessage:error.localizedDescription dismiss:^{
                [self hidePiwigoHUDWithCompletion:^{
                    [self updateButtonsInSelectionMode];
                }];
            } retry:^{
                // Try relogin if unauthorized
                if (error.code == 401) {        // Unauthorized
                    // Try relogin
                    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                    [appDelegate reloginAndRetryWithCompletion:^{
                        [self retrieveImageDataBeforeShare];
                    }];
                } else {
                    [self retrieveImageDataBeforeShare];
                }
            }];
        }
    ];
}

-(void)checkPhotoLibraryAccessBeforeShare
{
    // Check autorisation to access Photo Library (camera roll)
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
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }

    // Delete image/video files and remove observers after dismissing activity view controller
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError){
//        NSLog(@"Activity Type selected: %@", activityType);
        if (completed) {
//            NSLog(@"Selected activity was performed and returned error:%ld", (long)activityError.code);
            // Delete shared file & remove observers
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
                [self setEnableStateOfButtons:YES];
            }
            else {
                // Check what to do with selection
                if (self.selectedImageIds.count == 0) {
                    [self cancelSelect];
                } else {
                    [self setEnableStateOfButtons:YES];
                }

                // Cancel download tasks
                [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCancelDownload object:nil];
                
                // Delete shared files & remove observers
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
    
    // Present album list for copying images into
    UIStoryboard *copySB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
    SelectCategoryViewController *copyVC = [copySB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
    NSArray<id> *parameter = [[NSArray<id> alloc] initWithObjects:self.selectedImageIds, @(kPiwigoFavoritesCategoryId), nil];
    [copyVC setInputWithParameter:parameter for:kPiwigoCategorySelectActionCopyImages];
    copyVC.delegate = self;                 // To re-enable toolbar
    copyVC.imageCopiedDelegate = self;      // To update image data after copy
    [self pushView:copyVC];
}


#pragma mark - Add/remove image from favorites

-(UIBarButtonItem *)getFavoriteBarButton {
    BOOL areFavorite = [CategoriesData.sharedInstance categoryWithId:kPiwigoFavoritesCategoryId containsImagesWithId:self.selectedImageIds];
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
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    [self addImageToFavorites];
}

-(void)addImageToFavorites
{
    if (self.selectedImageIds.count <= 0) {
        // Close HUD with success
        [self updatePiwigoHUDwithSuccessWithCompletion:^{
            [self hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
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
    PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:kPiwigoFavoritesCategoryId andId:[[self.selectedImageIds lastObject] integerValue]];
    
    // Add image to favorites
    [ImageUtilities addToFavorites:imageData completion:^{
        // Update HUD
        [self updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIds.count / (float)self.totalNumberOfImages];

        // Image info retrieved
        [self.selectedImageIds removeLastObject];

        // Next image
        [self addImageToFavorites];
        
    } failure:^(NSError * _Nonnull error) {
        // Failed — Ask user if he/she wishes to retry
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageFavorites_title", @"Favorites") message:NSLocalizedString(@"imageFavoritesAddError_message", @"Failed to add this photo to your favorites.") errorMessage:error.localizedDescription dismiss:^{
            [self hidePiwigoHUDWithCompletion:^{
                [self updateButtonsInSelectionMode];
            }];
        } retry:^{
            // Try relogin if unauthorized
            if (error.code == 401) {        // Unauthorized
                // Try relogin
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate reloginAndRetryWithCompletion:^{
                    [self addImageToFavorites];
                }];
            } else {
                [self addImageToFavorites];
            }
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
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
    } else {
        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    }

    // Retrieve image data
    [self removeImageFromFavorites];
}

-(void)removeImageFromFavorites
{
    if (self.selectedImageIds.count <= 0) {
        // Close HUD with success
        [self updatePiwigoHUDwithSuccessWithCompletion:^{
            [self hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                // Update button
                [self.favoriteBarButton setFavoriteImageFor:NO];
                self.favoriteBarButton.action = @selector(addToFavorites);
                // Deselect images
                [self cancelSelect];
                // Remove favorites from collection
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
    PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:kPiwigoFavoritesCategoryId andId:[[self.selectedImageIds lastObject] integerValue]];
    
    // Remove image from favorites
    [ImageUtilities removeFromFavorites:imageData completion:^{
        // Update HUD
        [self updatePiwigoHUDWithProgress:1.0 - (float)self.selectedImageIds.count / (float)self.totalNumberOfImages];

        // Image removed from the favorites
        [self.selectedImageIds removeLastObject];

        // Next image
        [self removeImageFromFavorites];
        
    } failure:^(NSError * _Nonnull error) {
        // Failed — Ask user if he/she wishes to retry
        [self dismissRetryPiwigoErrorWithTitle:NSLocalizedString(@"imageFavorites_title", @"Favorites") message:NSLocalizedString(@"imageFavoritesRemoveError_message", @"Failed to remove this photo from your favorites.") errorMessage:error.localizedDescription dismiss:^{
            [self hidePiwigoHUDWithCompletion:^{
                [self updateButtonsInSelectionMode];
            }];
        } retry:^{
            // Try relogin if unauthorized
            if (error.code == 401) {        // Unauthorized
                // Try relogin
                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate reloginAndRetryWithCompletion:^{
                    [self removeImageFromFavorites];
                }];
            } else {
                [self removeImageFromFavorites];
            }
        }];
    }];
}


#pragma mark - UICollectionView Headers & Footers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if(kind == UICollectionElementKindSectionFooter)
    {
        // Display number of images
        NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].numberOfImages;
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
    NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].numberOfImages;
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
    
    if (self.albumData.images.count > indexPath.item) {
        // Remember that user did scroll down to this item
        self.didScrollToImageIndex = indexPath.item;
        
        // Create cell from Piwigo data
        PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
        [cell configWith:imageData inCategoryId:kPiwigoFavoritesCategoryId for:self.imageCellSize];
        cell.isSelection = [self.selectedImageIds containsObject:[NSNumber numberWithInteger:imageData.imageId]];
        cell.isFavorite = YES;
        
        // Add pan gesture recognition
        UIPanGestureRecognizer *imageSeriesRocognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touchedImages:)];
        imageSeriesRocognizer.minimumNumberOfTouches = 1;
        imageSeriesRocognizer.maximumNumberOfTouches = 1;
        imageSeriesRocognizer.cancelsTouchesInView = NO;
        imageSeriesRocognizer.delegate = self;
        [cell addGestureRecognizer:imageSeriesRocognizer];
        cell.userInteractionEnabled = YES;
    }
    
    // Load more image data if possible (page after page…)
    if (![[[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId] hasAllImagesInCache]) {
        [self needToLoadMoreImages];
    }

    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];

    // Avoid rare crashes…
    if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) { return; }
    if (self.albumData.images[indexPath.item].imageId == 0) { return; }

    // Action depends on mode
    if (!self.isSelect)
    {
        // Remember that user did tap this image
        self.imageOfInterest = indexPath;
        
        // Selection mode not active => display full screen image
        UIStoryboard *imageDetailSB = [UIStoryboard storyboardWithName:@"ImageDetailViewController" bundle:nil];
        self.imageDetailView = [imageDetailSB instantiateViewControllerWithIdentifier:@"ImageDetailViewController"];
        self.imageDetailView.imageIndex = indexPath.row;
        self.imageDetailView.categoryId = kPiwigoFavoritesCategoryId;
        self.imageDetailView.images = [self.albumData.images copy];
        self.imageDetailView.hidesBottomBarWhenPushed = YES;
        self.imageDetailView.imgDetailDelegate = self;
        [self.navigationController pushViewController:self.imageDetailView animated:YES];
    }
    else
    {
        // Selection mode active => add/remove image from selection
        NSNumber *imageIdObject = [NSNumber numberWithInteger:selectedCell.imageData.imageId];
        if(![self.selectedImageIds containsObject:imageIdObject]) {
            [self.selectedImageIds addObject:imageIdObject];
            selectedCell.isSelection = YES;
        } else {
            selectedCell.isSelection = NO;
            [self.selectedImageIds removeObject:imageIdObject];
        }
        [collectionView reloadItemsAtIndexPaths:@[indexPath]];

        // and update nav buttons
        [self updateButtonsInSelectionMode];
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
    NSInteger downloadedImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].imageList.count;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self.albumData loadMoreImagesOnCompletion:^(BOOL hasNewImages) {
            // Did we collect more images?
            if (!hasNewImages) { return; }

            // Prepare indexPaths of cells to reload
            NSInteger newDownloadedImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoFavoritesCategoryId].imageList.count;
            NSMutableArray *indexPaths = [NSMutableArray new];
            for (NSInteger i = downloadedImageCount; i < newDownloadedImageCount; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
            }

            // Back to main thread…
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update detail view if needed
                if (self.imageDetailView != nil) {
                    self.imageDetailView.images = [self.albumData.images mutableCopy];
                }
                
                // Add indexPaths of cell presented with placeholder
                UIImage *placeHolderImage = [UIImage imageNamed:@"placeholderImage"];
                for (NSIndexPath *indexPath in self.imagesCollection.indexPathsForVisibleItems) {
                    if ([indexPaths containsObject:indexPath]) { continue; }
                    UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:indexPath];
                    if (![cell isKindOfClass:[ImageCollectionViewCell class]]) { continue; }
                    ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                    if ([imageCell.cellImage.image isEqual:placeHolderImage]) {
                        [indexPaths addObject:indexPath];
                    }
                }
                
                // Reload cells
                [self.imagesCollection reloadItemsAtIndexPaths:indexPaths];
                
                // Display HUD if it will take more than a second to load image data
                CFAbsoluteTime diff = (CFAbsoluteTimeGetCurrent() - start)*1000.0;
                CFAbsoluteTime perImage = fabs(diff / (double)(newDownloadedImageCount - downloadedImageCount));
                CFAbsoluteTime left = perImage * (double)MAX(0, (self.didScrollToImageIndex - newDownloadedImageCount));
                NSLog(@"expected time: %.2f ms (diff: %.0f, perImage: %.0f)", left, diff, perImage);
                if (left > 1000.0) {
                    if ([self.view viewWithTag:loadingViewTag] == nil) {
                        [self showPiwigoHUDWithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeAnnularDeterminate];
                    } else {
                        float fraction = (float)newDownloadedImageCount / (float)(self.didScrollToImageIndex);
                        [self updatePiwigoHUDWithProgress:fraction];
                    }
                } else {
                    [self hidePiwigoHUDWithCompletion:^{}];
                }

                // Should we continue loading images?
                NSLog(@"==> Should we continue loading images? (scrolled to %ld)", (long)self.didScrollToImageIndex);
                if (self.didScrollToImageIndex >= newDownloadedImageCount) {
                    [self needToLoadMoreImages];
                }
            });
        } onFailure:nil];
    });
}


#pragma mark - EditImageParamsDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Deselect image
    [self.selectedImageIds removeObject:[NSNumber numberWithInteger:imageId]];
    [self.imagesCollection reloadData];
}

-(void)didChangeImageParameters:(PiwigoImageData *)params
{
    // Update cached image data
    [[CategoriesData.sharedInstance getCategoryById:kPiwigoFavoritesCategoryId] updateImageAfterEdit:params];
    for (NSNumber *catId in params.categoryIds) {
        [[CategoriesData.sharedInstance getCategoryById:catId.intValue] updateImageAfterEdit:params];
    }

    // Update data source
    NSInteger indexOfUpdatedImage = [self.albumData updateImage:params];
    if (indexOfUpdatedImage == NSNotFound) { return; }
    
    // Refresh image cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:indexOfUpdatedImage inSection:0];
    if ([self.imagesCollection.indexPathsForVisibleItems containsObject:indexPath]) {
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
    if (indexOfUpdatedImage == NSNotFound) { return; }

    // Update image data
    [newImages replaceObjectAtIndex:indexOfUpdatedImage withObject:imageData];
    self.albumData.images = newImages;
}


#pragma mark - ShareImageActivityItemProviderDelegate

-(void)imageActivityItemProviderPreprocessingDidBegin:(UIActivityItemProvider *)imageActivityItemProvider
                                            withTitle:(NSString *)title
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


#pragma mark - Utilities

-(void)pushView:(UIViewController *)viewController
{
    // Push album list or image properties editor
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        viewController.modalPresentationStyle = UIModalPresentationPopover;
        viewController.popoverPresentationController.sourceView = self.imagesCollection;
        if ([viewController isKindOfClass:[SelectCategoryViewController class]]) {
            if (@available(iOS 14.0, *)) {
                viewController.popoverPresentationController.barButtonItem = self.actionBarButton;
            } else {
                viewController.popoverPresentationController.barButtonItem = self.moveBarButton;
            }
            viewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
            [self.navigationController presentViewController:viewController animated:YES completion:nil];
        }
        else if ([viewController isKindOfClass:[EditImageParamsViewController class]]) {
            // Push Edit view embedded in navigation controller
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
            navController.modalPresentationStyle = UIModalPresentationPopover;
            navController.popoverPresentationController.sourceView = self.view;
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

@end
