//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <StoreKit/StoreKit.h>

#import "AppDelegate.h"
#import "AlbumImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageService.h"
#import "CategoriesData.h"
#import "Model.h"
#import "ImageDetailViewController.h"
#import "ImageDownloadView.h"
#import "SortHeaderCollectionReusableView.h"
#import "NoImagesHeaderCollectionReusableView.h"
#import "CategoryImageSort.h"
#import "LoadingView.h"
#import "UICountingLabel.h"
#import "CategoryCollectionViewCell.h"
#import "AlbumService.h"
#import "LocalAlbumsViewController.h"
#import "AlbumData.h"
#import "NetworkHandler.h"
#import "ImagesCollection.h"
#import "SAMKeychain.h"
#import "CategoryPickViewController.h"
#import "CategoryHeaderReusableView.h"
#import "SettingsViewController.h"
#import "MBProgressHUD.h"

CGFloat const kRadius = 25.0;

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, ImageDetailDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, assign) BOOL isCachedAtInit;
@property (nonatomic, strong) NSString *currentSort;
@property (nonatomic, assign) BOOL loadingImages;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, strong) UIViewController *hudViewController;

@property (nonatomic, strong) UIBarButtonItem *settingsBarButton;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIButton *uploadButton;
@property (nonatomic, strong) UIButton *homeAlbumButton;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger startDeleteTotalImages;
@property (nonatomic, assign) NSInteger totalImagesToDownload;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) NSMutableArray *touchedImageIds;
@property (nonatomic, strong) ImageDownloadView *downloadView;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) LoadingView *loadingView;

@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached
{
    self = [super init];
	if(self)
	{
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.categoryId = albumId;
        self.loadingImages = NO;
        self.isCachedAtInit = isCached;
        
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId];
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

        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		[self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"category"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"categoryHeader"];
        [self.imagesCollection registerClass:[CategoryHeaderReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"categoryHeader"];
		[self.imagesCollection registerClass:[SortHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"sortHeader"];
        [self.imagesCollection registerClass:[NoImagesHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"noImagesHeader"];

		[self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];

        // Bar buttons
        self.settingsBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"preferences"] style:UIBarButtonItemStylePlain target:self action:@selector(displayPreferences)];
        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImages)];
		self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImages)];
		
        // Upload button above collection view
        self.uploadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
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
        [self.uploadButton setImage:[UIImage imageNamed:@"cloud"] forState:UIControlStateNormal];
        [self.uploadButton addTarget:self action:@selector(displayUpload)
               forControlEvents:UIControlEventTouchUpInside];
        self.uploadButton.hidden = YES;
        [self.view addSubview:self.uploadButton];

        // Home album button above collection view
        self.homeAlbumButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
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

        // No download at start
		self.downloadView.hidden = YES;

        // Register category data updates
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCategoryData:) name:kPiwigoNotificationGetCategoryData object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

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
    
    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoBackgroundColor];
    [self refreshShowingCells];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Set colors, fonts, etc.
    [self paletteChanged];
    
    // Reload category data and refresh showing cells
    [self getCategoryData:nil];
    [self refreshShowingCells];

    // Inform Upload view controllers that user selected this category
    NSDictionary *userInfo = @{@"currentCategoryId" : @(self.categoryId)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedCurrentCategory object:nil userInfo:userInfo];
    
	// Albums
    if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
        [self.imagesCollection reloadData];
	}
    
    // Images
    if (self.categoryId != 0) {
        self.loadingImages = YES;
        [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

            // Set navigation bar buttons
            [self updateNavBar];

            self.loadingImages = NO;
            [self.imagesCollection reloadData];
        }];
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

    // Set navigation bar buttons
    [self updateNavBar];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
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
    
    // Replace iRate as from v2.1.5 (75) — See https://github.com/nicklockwood/iRate
    // Tells StoreKit to ask the user to rate or review the app, if appropriate.
#if !defined(DEBUG)
    if (NSClassFromString(@"SKStoreReviewController")) {
        [SKStoreReviewController requestReview];
    }
#endif
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
        CGFloat xPos = [UIScreen mainScreen].bounds.size.width - 3*kRadius;
        CGFloat yPos = [UIScreen mainScreen].bounds.size.height - 3*kRadius;
        self.uploadButton.frame = CGRectMake(xPos, yPos, 2*kRadius, 2*kRadius);
        self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 1)]];
    } completion:nil];
}

-(void)updateNavBar
{
    // Update buttons
    if(!self.isSelect) {    // Image selection mode inactive
        
        // Title is name of the category
        if (self.categoryId == 0) {
            self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
        } else {
            self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
        }

        // User can upload images/videos if he/she has:
        // — admin rights
        // — opened a session on a server having Community extension installed
        if(([Model sharedInstance].hasAdminRights) ||
           ([Model sharedInstance].usesCommunityPluginV29 && [Model sharedInstance].hadOpenedSession))
        {
            // Show Upload button
            [self.uploadButton setHidden:NO];
        }
        
        // Show navigation button if not in root or default album
        if ((self.categoryId == 0) ||
            (self.categoryId == [Model sharedInstance].defaultCategory)) {
            // Hide Home button
            [self.homeAlbumButton setHidden:YES];
        }
        else
        {
            // Display Home button
            CGFloat xPos = self.uploadButton.frame.origin.x;
            CGFloat yPos = self.uploadButton.frame.origin.y;
            self.homeAlbumButton.frame = CGRectMake(xPos - 3*kRadius, yPos, 2*kRadius, 2*kRadius);
            [self.homeAlbumButton setHidden:NO];
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
        if ((self.categoryId != 0) &&
            (self.albumData.images.count > 0)){
            
            // Button for activating the selection mode
            [self.navigationItem setRightBarButtonItems:@[self.selectBarButton] animated:YES];
        }
        else {
            // No images: no button
            [self.navigationItem setRightBarButtonItems:@[] animated:YES];
        }
    }
    else {                  // Image selection mode active
        
        // Hide back button item and upload button
        [self.navigationItem setHidesBackButton:YES];
        [self.uploadButton setHidden:YES];
        [self.homeAlbumButton setHidden:YES];

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

        // Update buttons
        if([Model sharedInstance].hasAdminRights)
        {
            // Only admins have delete rights
            if (self.selectedImageIds.count > 0) {
                // Images selected
                [self.navigationItem setLeftBarButtonItems:@[self.downloadBarButton, self.deleteBarButton] animated:YES];
            } else {
                // No images selected
                [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
            }
        }
        else {
            // No admin rights
            if (self.selectedImageIds.count > 0) {
                // Images selected
                [self.navigationItem setLeftBarButtonItems:@[self.downloadBarButton] animated:YES];
            } else {
                // No images selected
                [self.navigationItem setLeftBarButtonItems:@[] animated:YES];
            }
        }
        
        // Right side of navigation bar
        [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
    }
}


#pragma mark - Category Data

-(void)getCategoryData:(NSNotification *)notification
{
    // Reload category data
    NSLog(@"getCategoryData => getAlbumListForCategory(%ld,%d,%d)", (long)self.categoryId,([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit),[Model sharedInstance].loadAllCategoryInfo);

    // Display HUD if requested
    BOOL noHUD = NO;
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;
        noHUD = [[userInfo objectForKey:@"NoHUD"] boolValue];
    }
    if (!([Model sharedInstance].loadAllCategoryInfo && self.isCachedAtInit) && !noHUD) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"categorySelectionHUD_label", @"Retrieving Albums Data…")];
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
                                 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                                 
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
    NSLog(@"refreshControl => getAlbumListForCategory(%ld,NO,NO)", [Model sharedInstance].loadAllCategoryInfo ? (long)0 : (long)self.categoryId);

    // Show loading HD
    [self showHUDwithTitle:NSLocalizedString(@"categorySelectionHUD_label", @"Retrieving Albums Data…")];

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
                [imageCell setupWithImageData:imageData];

                if([self.selectedImageIds containsObject:imageData.imageId])
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
    NSLog(@"=> categoriesUpdated…");
    // Albums
    [self.imagesCollection reloadData];

    // Images
    if (self.categoryId != 0) {
        self.loadingImages = YES;
        [self.albumData loadAllImagesOnCompletion:^{

             // Sort images
            [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{
            
                // Reload images collection view
                self.loadingImages = NO;
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
            
                // Set navigation bar buttons
                [self updateNavBar];

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
            }];
        }];
    }
     else {
         // The album title is not shown in backButtonItem to provide enough space
         // for image title on devices of screen width <= 414 ==> Restore album title
         self.title = NSLocalizedString(@"tabBar_albums", @"Albums");

         // Set navigation bar buttons
         [self updateNavBar];
     }
}

#pragma mark - Default Category Management

-(void)returnToDefaultCategory
{
    // Does this view controller already exists?
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
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navController animated:YES completion:nil];
}

-(void)displayUpload
{
    CategoryPickViewController *uploadViewController = [[CategoryPickViewController alloc] initWithCategoryId:self.categoryId];
    uploadViewController.title = NSLocalizedString(@"tabBar_upload", @"Upload");

    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:uploadViewController];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
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

    // Hide download view, clear array of selected images and allow iOS device to sleep
    self.downloadView.hidden = YES;
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
    // To prevent a crash
    if (gestureRecognizer.view == nil) return;
    
    // Select/deselect the cell or scroll the view
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
            if (![self.touchedImageIds containsObject:imageCell.imageData.imageId]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImageIds addObject:imageCell.imageData.imageId];
                
                // Update the selection state
                if(![self.selectedImageIds containsObject:imageCell.imageData.imageId]) {
                    [self.selectedImageIds addObject:imageCell.imageData.imageId];
                    imageCell.isSelected = YES;
                } else {
                    imageCell.isSelected = NO;
                    [self.selectedImageIds removeObject:imageCell.imageData.imageId];
                }
                
                // Reload the cell and update the navigation bar
                [self.imagesCollection reloadItemsAtIndexPaths:@[indexPath]];
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

-(void)deleteImages
{
	if(self.selectedImageIds.count <= 0) return;
	
    // Do we really want to delete these images?
    NSString *titleString, *messageString;
    if (self.selectedImageIds.count > 1) {
        titleString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_title", @"Delete %@ Images"), @(self.selectedImageIds.count)];
        messageString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_message", @"Are you sure you want to delete the selected %@ images?"), @(self.selectedImageIds.count)];
    } else {
        titleString = NSLocalizedString(@"deleteSingleImage_title", @"Delete Image");
        messageString = NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image?");
    }

    // Do we really want to delete these images?
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:titleString
                                message:messageString
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
                                   actionWithTitle:titleString
                                   style:UIAlertActionStyleDestructive
                                   handler:^(UIAlertAction * action) {
                                       self.startDeleteTotalImages = self.selectedImageIds.count;
                                       [self deleteSelected];
                                   }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    
    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.deleteBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)deleteSelected
{
	if(self.selectedImageIds.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
    
    // Image data are not always available —> Load them
    [ImageService getImageInfoById:[self.selectedImageIds.lastObject integerValue]
              ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {

                  // Let's delete the image
                  [ImageService deleteImage:imageData
                           ListOnCompletion:^(NSURLSessionTask *task) {
                              // Image deleted
                              [self.albumData removeImageWithId:[self.selectedImageIds.lastObject integerValue]];
                              
                              [self.selectedImageIds removeLastObject];
                              NSInteger percentDone = ((CGFloat)(self.startDeleteTotalImages - self.selectedImageIds.count) / self.startDeleteTotalImages) * 100;
                              self.title = [NSString stringWithFormat:NSLocalizedString(@"deleteImageProgress_title", @"Deleting %@%% Done"), @(percentDone)];
                              [self.imagesCollection reloadData];
                              [self deleteSelected];
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
                                          handler:^(UIAlertAction * action) {}];
                              
                              UIAlertAction* retryAction = [UIAlertAction
                                          actionWithTitle:NSLocalizedString(@"alertTryAgainButton", @"Try Again")
                                          style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction * action) {
                                              [self deleteSelected];
                                          }];
                              
                               // Add actions
                               [alert addAction:dismissAction];
                               [alert addAction:retryAction];
                               
                               // Present list of actions
                               [self presentViewController:alert animated:YES completion:nil];
                           }];

              } onFailure:^(NSURLSessionTask *task, NSError *error) {
                  // Error encountered when retrieving image infos
                  UIAlertController* alert = [UIAlertController
                              alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
                              message:NSLocalizedString(@"imageDetailsFetchError_continueMessage", @"Fetching the image data failed\nNContinue?")
                              preferredStyle:UIAlertControllerStyleAlert];
                  
                  UIAlertAction* cancelAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                              style:UIAlertActionStyleCancel
                              handler:^(UIAlertAction * action) {}];
                  
                  UIAlertAction* continueAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                              style:UIAlertActionStyleDestructive
                              handler:^(UIAlertAction * action) {
                                  [self deleteSelected];
                              }];
                  
                  // Add actions
                  [alert addAction:cancelAction];
                  [alert addAction:continueAction];
                  
                  // Present list of actions
                  [self presentViewController:alert animated:YES completion:nil];
              }
     ];
}


#pragma mark - Download images

-(void)downloadImages
{
	if(self.selectedImageIds.count <= 0) return;
	
    // Check access to Photos — Required as system does not always ask
    if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
        // Request authorization to access photos
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            // Nothing to do…
        }];
    }
    else if(([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) ||
            ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted)) {
        // Inform user that he/she denied or restricted access to photos
        UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNotAuthorized_title", @"No Access")
                                    message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
                                    preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction* dismissAction = [UIAlertAction
                                        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                        style:UIAlertActionStyleCancel
                                        handler:^(UIAlertAction * action) {}];
        
        // Add actions
        [alert addAction:dismissAction];

        // Present list of actions
        alert.popoverPresentationController.barButtonItem = self.downloadBarButton;
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Do we really want to download these images?
    NSString *titleString, *messageString;
    if (self.selectedImageIds.count > 1) {
        titleString = [NSString stringWithFormat:NSLocalizedString(@"downloadSeveralImages_title", @"Download %@ Images"), @(self.selectedImageIds.count)];
        messageString = [NSString stringWithFormat:NSLocalizedString(@"downloadSeveralImage_confirmation", @"Are you sure you want to download the selected %@ images?"), @(self.selectedImageIds.count)];
    } else {
        titleString = NSLocalizedString(@"downloadSingleImage_title", @"Download Image");
        messageString = NSLocalizedString(@"downloadSingleImage_confirmation", @"Are you sure you want to download the selected image?");
    }
    
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:titleString
                                message:messageString
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
                                   actionWithTitle:titleString
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                                       self.totalImagesToDownload = self.selectedImageIds.count;
                                       [self downloadImage];
                                   }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];

    // Present list of actions
    alert.popoverPresentationController.barButtonItem = self.downloadBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)downloadImage
{
	if(self.selectedImageIds.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	self.downloadView.multiImage = YES;
	self.downloadView.totalImageDownloadCount = self.totalImagesToDownload;
	self.downloadView.imageDownloadCount = self.totalImagesToDownload - self.selectedImageIds.count + 1;
	
	self.downloadView.hidden = NO;
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
	
	PiwigoImageData *downloadingImage = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject];
	
    // Dummy image for progress view
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
    NSURL *URL = [NSURL URLWithString:downloadingImage.ThumbPath];
    [dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:URL]
					 placeholderImage:[UIImage imageNamed:@"placeholderImage"]
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];
	
    // Launch the download
    if(!downloadingImage.isVideo)
	{
        [ImageService downloadImage:downloadingImage
                         onProgress:^(NSProgress *progress) {
                               dispatch_async(dispatch_get_main_queue(),
                                    ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;});
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                      // Any error ?
                      if (error.code) {
#if defined(DEBUG)
                           NSLog(@"downloadImage fail");
#endif
                      } else {
                          // Try to move photo in Photos.app
                          [self saveImageToCameraRoll:filePath];
                      }
                  }
         ];
	}
	else
	{
        [ImageService downloadVideo:downloadingImage
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                            ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;}
                                            );
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                      // Any error ?
                      if (error.code) {
#if defined(DEBUG)
                          NSLog(@"AlbumImagesViewController: downloadImage fail");
#endif
                      } else {
                          // Try to move video in Photos.app
#if defined(DEBUG)
                          NSLog(@"path= %@", filePath.path);
#endif
                          if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath.path)) {
                              UISaveVideoAtPathToSavedPhotosAlbum(filePath.path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
                          } else {
                              UIAlertController* alert = [UIAlertController
                                      alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                      message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), NSLocalizedString(@"downloadVideoFail_Photos", @"Video format not accepted by Photos!")]
                                      preferredStyle:UIAlertControllerStyleAlert];
                              
                              UIAlertAction* dismissAction = [UIAlertAction
                                      actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * action) {}];
                              
                              [alert addAction:dismissAction];
                              [self presentViewController:alert animated:YES completion:nil];
                          }
                      }
                  }
         ];
        self.downloadView.hidden = NO;
	}
}

-(void)saveImageToCameraRoll:(NSURL *)filePath
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:filePath];
    } completionHandler:^(BOOL success, NSError *error) {
        if (!success) {
            // Failed — Inform user
            UIAlertController* alert = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image")
                                        message:[NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), [error localizedDescription]]
                                        preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* dismissAction = [UIAlertAction
                                            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
                                                [self cancelSelect];
                                            }];
            
            [alert addAction:dismissAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
    
    // Unqueue image and download next image
    [self.selectedImageIds removeLastObject];
    [self downloadImage];
}

-(void)movie:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:NSLocalizedString(@"videoSaveError_title", @"Fail Saving Video")
                    message:[NSString stringWithFormat:NSLocalizedString(@"videoSaveError_message", @"Failed to save video. Error: %@"), [error localizedDescription]]
                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* dismissAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [self cancelSelect];
                    }];
        
        [alert addAction:dismissAction];
        [self presentViewController:alert animated:YES completion:nil];
	}
	else
	{
		[self.selectedImageIds removeLastObject];
		[self downloadImage];
	}
}

-(ImageDownloadView*)downloadView
{
	if(_downloadView) return _downloadView;
	
	_downloadView = [ImageDownloadView new];
	_downloadView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_downloadView];
	[self.view addConstraints:[NSLayoutConstraint constraintFillSize:_downloadView]];
	return _downloadView;
}


#pragma mark - UICollectionView Headers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:     // Section 0 — Album collection
        {
            CategoryHeaderReusableView *header = nil;
            
            if (kind == UICollectionElementKindSectionHeader) {
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"categoryHeader" forIndexPath:indexPath];
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
                header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"noImagesHeader" forIndexPath:indexPath];
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
    switch (section) {
        case 0:             // Albums
            return [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
            break;
            
        default:            // Images
            return self.albumData.images.count;
            break;
    }
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
    if(indexPath.section == 1)
	{
        // Calculate the optimum image size
        CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
        return CGSizeMake(size, size);                                 // Thumbnails
	}
	else
	{
        float nberAlbumsPerRow = [ImagesCollection numberOfAlbumsPerRowForViewInPortrait:collectionView withMaxWidth:384];
        CGFloat size = (CGFloat)[ImagesCollection albumSizeForView:collectionView andNberOfAlbumsPerRowInPortrait:nberAlbumsPerRow];
        return CGSizeMake(size, 188);                                   // Albums
	}
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)      // Images
	{
		ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
		
		if(self.albumData.images.count > indexPath.row) {
			// Create cell from Piwigo data
            PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
			[cell setupWithImageData:imageData];
            cell.isSelected = [self.selectedImageIds containsObject:imageData.imageId];

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
	else        // Albums
	{
		CategoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
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
	}
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 1)
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
            if(![self.selectedImageIds containsObject:selectedCell.imageData.imageId]) {
                [self.selectedImageIds addObject:selectedCell.imageData.imageId];
                selectedCell.isSelected = YES;
            } else {
                selectedCell.isSelected = NO;
                [self.selectedImageIds removeObject:selectedCell.imageData.imageId];
            }
            [collectionView reloadData];

            // and display nav buttons
            [self updateNavBar];
        }
    }
}


#pragma mark - ImageDetailDelegate Methods

-(void)didDeleteImage:(PiwigoImageData *)image
{
	[self.albumData removeImage:image];
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


#pragma mark - HUD methods

-(void)showHUDwithTitle:(NSString *)title
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
                hud.label.text = NSLocalizedString(@"Complete", nil);
                [hud hideAnimated:YES afterDelay:2.f];
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


#pragma mark - CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	self.currentSortCategory = sortType;
    [self.albumData updateImageSort:sortType OnCompletion:^{
        [self.imagesCollection reloadData];
    }];
}


#pragma mark - CategoryCollectionViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
	[self.navigationController pushViewController:viewController animated:YES];
}

-(void)presentView:(UIViewController *)viewController
{
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
    navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:viewController animated:YES completion:nil];
}

@end
