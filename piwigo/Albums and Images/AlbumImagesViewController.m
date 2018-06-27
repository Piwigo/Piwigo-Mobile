//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <StoreKit/StoreKit.h>

#import "AlbumImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageService.h"
#import "CategoriesData.h"
#import "Model.h"
#import "ImageDetailViewController.h"
#import "ImageDownloadView.h"
#import "SortHeaderCollectionReusableView.h"
#import "NoImagesHeaderCollectionReusableView.h"
//#import "CategorySortViewController.h"
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

CGFloat const kRadius = 25.0;

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, UITabBarControllerDelegate, ImageDetailDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSString *currentSort;
@property (nonatomic, assign) BOOL loadingImages;
@property (nonatomic, assign) BOOL displayImageTitles;

@property (nonatomic, assign) CGFloat previousContentYOffset;
@property (nonatomic, assign) CGFloat minContentYOffset;

@property (nonatomic, strong) UIBarButtonItem *rootAlbumBarButton;
@property (nonatomic, strong) UIBarButtonItem *settingsBarButton;
@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIButton *uploadButton;

@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger startDeleteTotalImages;
@property (nonatomic, assign) NSInteger totalImagesToDownload;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) ImageDownloadView *downloadView;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) LoadingView *loadingView;

@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId
{
    self = [super init];
	if(self)
	{
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.categoryId = albumId;
        self.loadingImages = (albumId != 0);
        
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId];
		self.currentSortCategory = [Model sharedInstance].defaultSort;
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
		
        // Before starting scrolling
        self.previousContentYOffset = -INFINITY;
        
        // Collection of images
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.backgroundColor = [UIColor clearColor];
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
        self.rootAlbumBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"rootAlbum"] style:UIBarButtonItemStylePlain target:self action:@selector(setRootAlbumAsDefaultCategory)];
        self.settingsBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"preferences"] style:UIBarButtonItemStylePlain target:self action:@selector(displayPreferences)];
        self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImages)];
		self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImages)];
		self.isSelect = NO;
		self.selectedImageIds = [NSMutableArray new];
		
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
        
        // No download at start
		self.downloadView.hidden = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCategoryData) name:kPiwigoNotificationGetCategoryData object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
	}
	return self;
}

#pragma mark - View Lifecycle

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Title of the album
    self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];

    // Reload category data and refresh showing cells
    [self getCategoryData];
    [self refreshShowingCells];

    // Inform Upload view controllers that user selected this category
    NSDictionary *userInfo = @{@"currentCategoryId" : @(self.categoryId)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationChangedCurrentCategory object:nil userInfo:userInfo];
    
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    self.imagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;

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

    // Tab bar appearance
    self.tabBarController.delegate = self;
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    self.tabBarItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];
    
	// Albums
    if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0) {
        [self.imagesCollection reloadData];
	}
    
    // Images
    self.loadingImages = YES;
    [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{

        // Set navigation bar buttons
        [self loadNavButtons];

        self.loadingImages = NO;
        [self.imagesCollection reloadData];
    }];
    
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
    [self loadNavButtons];
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
    
    // Tab bar must be visible if content does not fill the screen
    if (![self tabBarIsVisible] && (self.navigationController.toolbar.bounds.size.height + self.navigationController.navigationBar.bounds.size.height + self.imagesCollection.collectionViewLayout.collectionViewContentSize.height < [UIScreen mainScreen].bounds.size.height)) {
        [self setTabBarVisible:YES animated:YES completion:nil];
    }
    
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
    self.tabBarItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");

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
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 1)]];
    } completion:nil];
}

-(void)loadNavButtons
{
    if(!self.isSelect) {    // Image selection mode inactive
        
        // User can upload images/videos if he/she has:
        // — admin rights
        // — opened a session on a server having Community extension installed
        if(([Model sharedInstance].hasAdminRights) ||
           ([Model sharedInstance].usesCommunityPluginV29 && [Model sharedInstance].hadOpenedSession))
        {
            [self.uploadButton setHidden:NO];
        }

        // Left side of navigation bar
        if (self.categoryId == 0) {
            // Button for accessing settings
            [self.navigationItem setLeftBarButtonItems:@[self.settingsBarButton] animated:YES];
            [self.navigationItem setHidesBackButton:YES];
        }
        else if (([Model sharedInstance].defaultCategory != 0) &&
            ([Model sharedInstance].defaultCategory == self.categoryId)) {
            
            // Buttons for resetting default album Id to 0 and accessing settings
            [self.navigationItem setLeftBarButtonItems:@[self.rootAlbumBarButton, self.settingsBarButton] animated:YES];
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
        
        // First hide back button item and upload button
        [self.navigationItem setHidesBackButton:YES];
        [self.uploadButton setHidden:YES];
        
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

-(void)getCategoryData
{
    // Reload category data
//    NSLog(@"getCategoryData => getAlbumListForCategory(%ld,YES,NO)", (long)self.categoryId);
    [AlbumService getAlbumListForCategory:self.categoryId
                     usingCacheIfPossible:YES
                          inRecursiveMode:NO
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
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
//    NSLog(@"refreshControl => getAlbumListForCategory(%ld,NO,NO)", (long)self.categoryId);
    [AlbumService getAlbumListForCategory:self.categoryId
                     usingCacheIfPossible:NO
                          inRecursiveMode:NO
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [self.imagesCollection reloadData];
                                 [refreshControl endRefreshing];
                             }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                                 [refreshControl endRefreshing];
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
//    NSLog(@"categoriesUpdated => loadAllImagesOnCompletion…");
    // Reload albums collection view
     [self.imagesCollection reloadData];

     // Images
     if (self.categoryId != 0) {
         [self.albumData loadAllImagesOnCompletion:^{
            
             // Sort images
            [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{
                
                // Reload images collection view
                self.loadingImages = NO;
                [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:1]];
                
                // Set navigation bar buttons
                [self loadNavButtons];

                // The album title is not shown in backButtonItem to provide enough space
                // for image title on devices of screen width <= 414 ==> Restore album title
                self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
                self.tabBarItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");
            }];
        }];
     }
     else {
         // The album title is not shown in backButtonItem to provide enough space
         // for image title on devices of screen width <= 414 ==> Restore album title
         self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
         self.tabBarItem.title = NSLocalizedString(@"tabBar_albums", @"Albums");

         // Set navigation bar buttons
         [self loadNavButtons];
     }
}

#pragma mark - Default Category Management

-(void)setRootAlbumAsDefaultCategory
{
    // Root album becomes default category
    [Model sharedInstance].defaultCategory = 0;
    [[Model sharedInstance] saveToDisk];
    
    // Does this view controller already exists?
    NSInteger cur = 0, index = 0;
    AlbumImagesViewController *rootAlbumViewController = nil;
    for (UIViewController *viewController in self.navigationController.viewControllers) {

        // Look for AlbumImagesViewControllers
        if ([viewController isKindOfClass:[AlbumImagesViewController class]]) {
            AlbumImagesViewController *thisViewController = (AlbumImagesViewController *) viewController;

            // Is this the view controller of the root album?
            if (thisViewController.categoryId == 0) {
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

    // The view controller of the root album does not exist yet
    if (!rootAlbumViewController) {
        rootAlbumViewController = [[AlbumImagesViewController alloc] initWithAlbumId:0];
        NSMutableArray *arrayOfVC = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
        [arrayOfVC insertObject:rootAlbumViewController atIndex:index];
        self.navigationController.viewControllers = arrayOfVC;
    }
    
    // Present the root album
    [self.navigationController popToViewController:rootAlbumViewController animated:YES];
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController;
{
    // Do not return to root album if user's root album being used
    if (([Model sharedInstance].defaultCategory != 0) &&
        (viewController == [self.tabBarController.viewControllers objectAtIndex:0]) &&
        (viewController == self.tabBarController.selectedViewController)) {
        
        if (self.categoryId != [Model sharedInstance].defaultCategory) {
            AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumId:[Model sharedInstance].defaultCategory];
            [self.navigationController pushViewController:album animated:NO];
        } else {
            [self refresh:nil];
        }
        return NO;
    }
    
    return YES;
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
        for (ImageCollectionViewCell *cell in self.imagesCollection.visibleCells) {

            // Will scroll to position of no visible image cell
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                numberOfImageCells++;
                break;
            }
        }

        // Scroll to position of images if needed
        if (numberOfImageCells == 0)
            [self.imagesCollection scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
        
        // Refresh collection view
        [self.imagesCollection setNeedsDisplay];
    }
    
    // Update navigation items
    [self loadNavButtons];

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
}

-(void)cancelSelect
{
	// Disable Images Selection mode
    self.isSelect = NO;
    
    // Refresh button items
	[self loadNavButtons];
    
    // Put back the name of the category
	self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
    
    // Enable interaction with category cells and deselect image cells
    for (UICollectionViewCell *cell in self.imagesCollection.visibleCells) {
        
        // Enable user interaction with category cell
//        if ([cell isKindOfClass:[CategoryCollectionViewCell class]]) {
//            CategoryCollectionViewCell *categoryCell = (CategoryCollectionViewCell *)cell;
//            [categoryCell setAlpha:1.0];
//            [categoryCell setUserInteractionEnabled:YES];
//        }
        
        // Deselect image cell
        if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
            ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
            if(imageCell.isSelected) imageCell.isSelected = NO;
        }
    }
    
    // Refresh collection view
    [self.imagesCollection setNeedsDisplay];

    // Hide download view, clear array of selected images and allow iOS device to sleep
    self.downloadView.hidden = YES;
	self.selectedImageIds = [NSMutableArray new];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
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

                if (self.albumData.images.count == 0) {
                    // No images ?
                    if (self.loadingImages) {
                        // Currently trying to load images…
                        header.noImagesLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
                        return header;
                    }
                    else if (self.categoryId != 0) {
                        // Not loading —> No images
                        header.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
                        return header;
                    }
                }
                header.noImagesLabel.text = @"";
                return header;
            }
            break;
        }
    }

	UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
	return view;
}

//-(void)didSelectCollectionViewHeader
//{
//    CategorySortViewController *categorySort = [CategorySortViewController new];
//    categorySort.currentCategorySortType = self.currentSortCategory;
//    categorySort.sortDelegate = self;
//    [self.navigationController pushViewController:categorySort animated:YES];
//}


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
            if (self.albumData.images.count == 0) {
                // No images ?
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
	if(indexPath.section == 1)      // Images thumbnails
	{
		ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
		
		if(self.albumData.images.count > indexPath.row) {
			PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
			[cell setupWithImageData:imageData];
            cell.isSelected = [self.selectedImageIds containsObject:imageData.imageId];
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
			[collectionView reloadItemsAtIndexPaths:@[indexPath]];

            // and display nav buttons
            [self select];
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


#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // NOP if content not yet complete
    if (scrollView.contentSize.height == 0) return;
    
    // First time ever, set parameters
    if (self.previousContentYOffset == -INFINITY) {
        self.minContentYOffset = scrollView.contentOffset.y;
    }
    
    // Initialisation
    CGFloat y = scrollView.contentOffset.y - self.minContentYOffset;
    CGFloat yMax = fmaxf(scrollView.contentSize.height - scrollView.frame.size.height + self.tabBarController.tabBar.bounds.size.height - self.minContentYOffset, self.minContentYOffset);
//    NSLog(@"contentSize:%g, frameSize:%g", scrollView.contentSize.height, scrollView.frame.size.height);
//    NSLog(@"offset=%3.0f, y=%3.0f, yMax=%3.0f", self.minContentYOffset, y, yMax);
    
    // Depends on current tab bar visibility
    if ([self tabBarIsVisible]) {
        // Hide the tab bar when scrolling down
        if ((y > self.previousContentYOffset) &&        // Scrolling down
            (y > 44) && (y < yMax - 44))                // from the top with margin
        {
            // User scrolls content to the bootm, starting from the top
            [self setTabBarVisible:NO animated:YES completion:nil];
        }
    } else {
        // Decide whether tab bar should be shown
        if ((y < self.previousContentYOffset) &&        // Scrolling up
            (y < yMax - 44))                            // from the bottom with margin
        {
            // User scrolls content near the top or bottom
            [self setTabBarVisible:YES animated:YES completion:nil];
        }
        else if ((y > self.previousContentYOffset) &&   // Scrolling down
                 (y > yMax - 44))                       // near the bottom
        {
            // User scrolls content to the bootm, starting from the top
            [self setTabBarVisible:YES animated:YES completion:nil];
        }
    }
    
    // Store actual position for next time
    self.previousContentYOffset = y;
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    // User tapped the status bar
    __weak typeof(self) weakSelf = self;
    [self setTabBarVisible:YES animated:YES completion:^(BOOL finished) {
        weakSelf.previousContentYOffset = scrollView.contentOffset.y;
    }];
    
    return YES;
}

// Pass a param to describe the state change, an animated flag and a completion block matching UIView animations completion
- (void)setTabBarVisible:(BOOL)visible animated:(BOOL)animated completion:(void (^)(BOOL))completion {
    
    // bail if the current state matches the desired state
    if ([self tabBarIsVisible] == visible) return (completion)? completion(YES) : nil;
    
    // get a frame calculation ready
    CGRect frame = self.tabBarController.tabBar.frame;
    CGFloat height = frame.size.height;
    CGFloat offsetY = (visible)? -height : height;
    
    // zero duration means no animation
    CGFloat duration = (animated)? 0.3 : 0.0;
    
    [UIView animateWithDuration:duration animations:^{
        self.tabBarController.tabBar.frame = CGRectOffset(frame, 0, offsetY);
    } completion:completion];
}

// Getter to know the current state
- (BOOL)tabBarIsVisible {
    return self.tabBarController.tabBar.frame.origin.y < CGRectGetMaxY(self.view.frame);
}

@end
