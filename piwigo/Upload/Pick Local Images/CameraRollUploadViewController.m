//
//  CameraRollUploadViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25 March 2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "AppDelegate.h"
#import "CameraRollUploadViewController.h"
#import "CategoriesData.h"
#import "ImageDetailViewController.h"
#import "ImageUpload.h"
#import "ImageUploadManager.h"
#import "ImageUploadProgressView.h"
#import "ImageUploadViewController.h"
#import "ImagesCollection.h"
#import "LocalImagesHeaderReusableView.h"
#import "LocalImageCollectionViewCell.h"
#import "LocationsData.h"
#import "MBProgressHUD.h"
#import "NberImagesFooterCollectionReusableView.h"
#import "NotUploadedYet.h"
#import "PhotosFetch.h"

@interface CameraRollUploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, PHPhotoLibraryChangeObserver, ImageUploadProgressDelegate, LocalImagesHeaderDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) PHFetchResult<PHAssetCollection *> *imageCollections;
@property (nonatomic, assign) NSInteger nberOfImagesPerRow;
@property (nonatomic, strong) NSArray *imagesInSections;

@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, strong) UIBarButtonItem *sortBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, strong) NSMutableArray *touchedImages;
@property (nonatomic, strong) NSMutableArray *selectedImages;
@property (nonatomic, strong) NSMutableArray *selectedSections;

@property (nonatomic, assign) kPiwigoSortBy sortType;
@property (nonatomic, assign) BOOL removedUploadedImages;
@property (nonatomic, strong) UIViewController *hudViewController;

@end

@implementation CameraRollUploadViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
    self = [super init];
    if(self)
    {
        self.categoryId = categoryId;
        self.sortType = kPiwigoSortByNewest;
        self.imageCollections = [PhotosFetch getMomentCollectionsWithSortType:kPiwigoSortByNewest];
//        NSLog(@"=> %lu sections", (unsigned long)self.imageCollections.count);

        // Log first collection (i.e. section)
//        if (self.imageCollections.count > 0) {
//            PHAssetCollection *firstObject = [self.imageCollections objectAtIndex:0];
//            NSLog(@"=> %@", [firstObject startDate]);
//            NSLog(@"=> %@", [firstObject endDate]);
//            NSLog(@"=> %@", [firstObject localizedTitle]);
//            NSLog(@"=> %@", [firstObject localizedLocationNames]);
//        }
        
        // Images inside sections
        self.imagesInSections = [[PhotosFetch sharedInstance] getImagesOfMomentCollections:self.imageCollections];

        // Arrays managing selections
        self.removedUploadedImages = NO;
        self.touchedImages = [NSMutableArray new];
        self.selectedImages = [NSMutableArray new];
        
        // Collection of images
        UICollectionViewFlowLayout *collectionFlowLayout = [UICollectionViewFlowLayout new];
        collectionFlowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        if (@available(iOS 9.0, *)) {
            collectionFlowLayout.sectionHeadersPinToVisibleBounds = YES;
        }
        self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:collectionFlowLayout];
        self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.localImagesCollection.backgroundColor = [UIColor clearColor];
        self.localImagesCollection.alwaysBounceVertical = YES;
        self.localImagesCollection.showsVerticalScrollIndicator = YES;
        self.localImagesCollection.dataSource = self;
        self.localImagesCollection.delegate = self;
        [self.localImagesCollection setAccessibilityIdentifier:@"CameraRoll"];

        [self.localImagesCollection registerNib:[UINib nibWithNibName:@"LocalImagesHeaderReusableView" bundle:nil] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"LocalImagesHeaderReusableView"];
        [self.localImagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        [self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"LocalImageCollectionViewCell"];

        [self.view addSubview:self.localImagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.localImagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Bar buttons
        self.sortBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list"] landscapeImagePhone:[UIImage imageNamed:@"listCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(askSortType)];
        [self.sortBarButton setAccessibilityIdentifier:@"Sort"];
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
        [self.cancelBarButton setAccessibilityIdentifier:@"Cancel"];
        self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"] style:UIBarButtonItemStylePlain target:self action:@selector(presentImageUploadView)];
        
        // Register Photo Library changes
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoPaletteChangedNotification object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
    {
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    }

    // Navigation bar
    self.navigationController.navigationBar.accessibilityIdentifier = @"CameraRollNav";
}

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];

    // Collection view
    self.localImagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.localImagesCollection reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Initialise arrays managing selections
    [self initSelectButtons];

    // Set colors, fonts, etc.
    [self applyColorPalette];
    
    // Update navigation bar and title
    [self updateNavBar];
    
    // Scale width of images on iPad so that they seem to adopt a similar size
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGFloat mainScreenWidth = MIN([UIScreen mainScreen].bounds.size.width,
                                     [UIScreen mainScreen].bounds.size.height);
        CGFloat currentViewWidth = MIN(self.view.bounds.size.width,
                                       self.view.bounds.size.height);
        self.nberOfImagesPerRow = roundf(currentViewWidth / mainScreenWidth * [Model sharedInstance].thumbnailsPerRowInPortrait);
    }
    else {
        self.nberOfImagesPerRow = [Model sharedInstance].thumbnailsPerRowInPortrait;
    }

    // Progress bar
    [ImageUploadProgressView sharedInstance].delegate = self;
    [[ImageUploadProgressView sharedInstance] changePaletteMode];
    
    if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
    {
        [[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
    }
    
    // Reload collection after feeding cache (and display images being uploaded)
    [self.localImagesCollection reloadData];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Save position of collection view
    NSArray *visibleCells = [self.localImagesCollection visibleCells];
    LocalImageCollectionViewCell *cell = [visibleCells firstObject];
    NSIndexPath *indexPath = [self.localImagesCollection indexPathForCell:cell];
    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];

    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavBar];
        [self.localImagesCollection reloadData];
        
        // Scroll to previous position
        NSIndexPath *indexPath = [self indexPathOfImageAsset:imageAsset];
        [self.localImagesCollection scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
    } completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)updateNavBar
{
    switch (self.selectedImages.count) {
        case 0:
            self.navigationItem.leftBarButtonItems = @[];
            // Do not show two buttons to provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
                [self.uploadBarButton setEnabled:NO];
            }
            self.title = NSLocalizedString(@"selectImages", @"Select Images");
            break;
            
        case 1:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            // Do not show two buttons to provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
            }
            [self.uploadBarButton setEnabled:YES];
            self.title = NSLocalizedString(@"selectImageSelected", @"1 Image Selected");
            break;
            
        default:
            self.navigationItem.leftBarButtonItems = @[self.cancelBarButton];
            // Do not show two buttons to provide enough space for title
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
                self.navigationItem.rightBarButtonItems = @[self.uploadBarButton];
            }
            else {
                self.navigationItem.rightBarButtonItems = @[self.sortBarButton, self.uploadBarButton];
            }
            [self.uploadBarButton setEnabled:YES];
            self.title = [NSString stringWithFormat:NSLocalizedString(@"selectImagesSelected", @"%@ Images Selected"), @(self.selectedImages.count)];
            break;
    }
}


#pragma mark - Manage Images

-(NSIndexPath *)indexPathOfImageAsset:(PHAsset *)imageAsset
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    
    // Loop over all sections
    for (NSInteger section = 0; section < [self.localImagesCollection numberOfSections]; section++)
    {
        // Index of image in section?
        NSInteger item = [[self.imagesInSections objectAtIndex:section] indexOfObject:imageAsset];
        if (item != NSNotFound) {
            indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            break;
        }
    }
    return indexPath;
}

-(void)askSortType
{
    UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"sortBy", @"Sort by")
            message:NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images")
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    UIAlertAction *newestAction = [UIAlertAction
           actionWithTitle:[PhotosFetch getNameForSortType:kPiwigoSortByNewest]
           style:UIAlertActionStyleDefault
           handler:^(UIAlertAction *action) {
               // Change sort option
               self.sortType = kPiwigoSortByNewest;
               self.removedUploadedImages = NO;

               // Sort images
               [self performSelectorInBackground:@selector(sortImagesInAscendingOrder) withObject:nil];
           }];
    
    UIAlertAction* oldestAction = [UIAlertAction
        actionWithTitle:[PhotosFetch getNameForSortType:kPiwigoSortByOldest]
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Change sort option
            self.sortType = kPiwigoSortByOldest;
            self.removedUploadedImages = NO;

            // Sort images
            [self performSelectorInBackground:@selector(sortImagesInAscendingOrder) withObject:nil];
        }];
    
    UIAlertAction* uploadedAction = [UIAlertAction
        actionWithTitle:self.removedUploadedImages ? [NSString stringWithFormat:@"✓ %@", NSLocalizedString(@"localImageSort_notUploaded", @"Not Uploaded")] : NSLocalizedString(@"localImageSort_notUploaded", @"Not Uploaded")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
         // Remove uploaded images?
         if (self.removedUploadedImages)
         {
             // Store choice
             self.removedUploadedImages = NO;
             
             // Sort images
             [self performSelectorInBackground:@selector(sortImagesInAscendingOrder) withObject:nil];
         }
         else {
             // Store choice
             self.removedUploadedImages = YES;
             
             // Remove uploaded images from collection
             [self performSelectorInBackground:@selector(removeUploadedImagesFromCollection) withObject:nil];
         }
        }];
    
    // Add actions
    [alert addAction:cancelAction];
    switch (self.sortType) {
        case kPiwigoSortByNewest:
            [alert addAction:oldestAction];
            [alert addAction:uploadedAction];
            break;
            
        case kPiwigoSortByOldest:
            [alert addAction:newestAction];
            [alert addAction:uploadedAction];
            break;
            
        default:
            break;
    }
    
    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.sortBarButton;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)sortImagesInAscendingOrder
{
    // Show HUD during job
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"imageSortingHUD", @"Sorting Images")];
    });
    
    // Collect new list of images
    self.imageCollections = [PhotosFetch getMomentCollectionsWithSortType:self.sortType];
    
    // Images in sections
    self.imagesInSections = [[PhotosFetch sharedInstance] getImagesOfMomentCollections:self.imageCollections];
    
    // Hide HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideHUDwithSuccess:YES completion:^{
            self.hudViewController = nil;
            
            // Refresh collection view
            [self.localImagesCollection reloadData];
            
            // Update Select buttons status
            [self updateSelectButtons];
        }];
    });
}

-(void)removeUploadedImagesFromCollection
{
    // Show HUD during download
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"imageUploadRemove", @"Removing Uploaded Images")];
    });
    
    // Remove uploaded images from the collection
    [NotUploadedYet getListOfImageNamesThatArentUploadedForCategory:self.categoryId
         withImages:self.imagesInSections
      andSelections:self.selectedSections
        forProgress:nil
       onCompletion:^(NSArray *imagesNotUploaded, NSIndexSet *sectionsToDelete)
           {
               dispatch_async(dispatch_get_main_queue(),
                              ^(void){
                   // Check returned data
                   if (imagesNotUploaded)
                   {
                       // Update image list
                       self.imagesInSections = imagesNotUploaded;
                       
                       // Hide HUD
                       [self hideHUDwithSuccess:YES completion:^{
                           self.hudViewController = nil;
                          
                           // Refresh collection view
                           [self.localImagesCollection deleteSections:sectionsToDelete];
                           
                           // Update selections
                           [self updateSelectButtons];
                        }];
                   }
                   else {
                        [self hideHUDwithSuccess:NO completion:^{
                              self.hudViewController = nil;
                        }];
                   }
                });
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
    hud.mode = MBProgressHUDModeIndeterminate;
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


#pragma mark - Select Images

-(void)initSelectButtons
{
    self.selectedSections = [NSMutableArray arrayWithCapacity:[self.imagesInSections count]];
    for (NSInteger section = 0; section < [self.imagesInSections count]; section++) {
        [self.selectedSections addObject:[NSNumber numberWithBool:NO]];
    }
}

-(void)updateSelectButtons
{
    // Update status of Select buttons
    // Same number of sections, or fewer if uploaded images removed
    for (NSInteger section = 0; section < [self.imagesInSections count]; section++) {
        [self updateSelectButtonForSection:section];
    }
}

-(void)cancelSelect
{
    // Loop over all sections
    for (NSInteger section = 0; section < [self.localImagesCollection numberOfSections]; section++)
    {
        // Loop over images in section
        for (NSInteger row = 0; row < [self.localImagesCollection numberOfItemsInSection:section]; row++)
        {
            // Deselect image
            LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:(section+1)]];
            cell.cellSelected = NO;
        }
        
        // Update state of Select button
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }
    
    // Clear list of selected images
    self.selectedImages = [NSMutableArray new];
    
    // Update navigation bar
    [self updateNavBar];
    
    // Update collection
    [self.localImagesCollection reloadData];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
{
    // Will interpret touches only in horizontal direction
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *gPR = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint translation = [gPR translationInView:self.localImagesCollection];
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
        CGPoint point = [gestureRecognizer locationInView:self.localImagesCollection];
        
        // Get item at touch position
        NSIndexPath *indexPath = [self.localImagesCollection indexPathForItemAtPoint:point];
        if ((indexPath.section == NSNotFound) || (indexPath.row == NSNotFound)) return;
        
        // Get cell at touch position
        UICollectionViewCell *cell = [self.localImagesCollection cellForItemAtIndexPath:indexPath];
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        if ((cell == nil) || (imageAsset == nil)) return;
        
        // Only consider image cells
        if ([cell isKindOfClass:[LocalImageCollectionViewCell class]])
        {
            LocalImageCollectionViewCell *imageCell = (LocalImageCollectionViewCell *)cell;
            
            // Update the selection if not already done
            if (![self.touchedImages containsObject:imageAsset]) {
                
                // Store that the user touched this cell during this gesture
                [self.touchedImages addObject:imageAsset];
                
                // Update the selection state
                if(![self.selectedImages containsObject:imageAsset]) {
                    [self.selectedImages addObject:imageAsset];
                    imageCell.cellSelected = YES;
                } else {
                    imageCell.cellSelected = NO;
                    [self.selectedImages removeObject:imageAsset];
                }
                
                // Update navigation bar
                [self updateNavBar];
                
                // Refresh cell
                [cell reloadInputViews];
                
                // Update state of Select button if needed
                [self updateSelectButtonForSection:indexPath.section];
            }
        }
    }
    
    // Is this the end of the gesture?
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        self.touchedImages = [NSMutableArray new];
    }
}

-(void)updateSelectButtonForSection:(NSInteger)section
{
    // Number of images in section
    NSInteger nberOfImages = [[self.imagesInSections objectAtIndex:section] count];
    
    // Count selected images in section
    NSInteger nberOfSelectedImages = 0;
    for (NSInteger item = 0; item < nberOfImages; item++) {
        
        // Retrieve image asset
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:section] objectAtIndex:item];
        
        // Is this image selected?
        if ([self.selectedImages containsObject:imageAsset]) {
            nberOfSelectedImages++;
        }
    }
    
    // Update state of Select button only if needed
    if (nberOfImages == nberOfSelectedImages)
    {
        if (![[self.selectedSections objectAtIndex:section] boolValue]) {
            [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:YES]];
            [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:section]];
        }
    }
    else {
        if ([[self.selectedSections objectAtIndex:section] boolValue]) {
            [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
            [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:section]];
        }
    }
}

-(void)presentImageUploadView
{
    // Reset Select buttons
    for (NSInteger section = 0; section < self.imagesInSections.count; section++) {
        [self.selectedSections replaceObjectAtIndex:section withObject:[NSNumber numberWithBool:NO]];
    }

    // Present Image Upload View
    ImageUploadViewController *imageUploadVC = [ImageUploadViewController new];
    imageUploadVC.selectedCategory = self.categoryId;
    imageUploadVC.imagesSelected = self.selectedImages;
    [self.navigationController pushViewController:imageUploadVC animated:YES];
    
    // Clear list of selected images
    self.selectedImages = [NSMutableArray new];    
}


#pragma mark - UICollectionView - Headers

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    // Header with place name
    if (kind == UICollectionElementKindSectionHeader)
    {
        if (self.imagesInSections.count > 0)    // Display data in header of section
        {
            UINib *nib = [UINib nibWithNibName:@"LocalImagesHeaderReusableView" bundle:nil];
            [collectionView registerNib:nib forCellWithReuseIdentifier:@"LocalImagesHeaderReusableView"];
            LocalImagesHeaderReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"LocalImagesHeaderReusableView" forIndexPath:indexPath];
            
            // Retrieve place name (=> placeLabel)
            NSMutableDictionary *placeNames = [NSMutableDictionary new];
            NSString *placeLabelName = [[self.imageCollections objectAtIndex:indexPath.section] localizedTitle];
            if (placeLabelName) [placeNames setValue:placeLabelName forKey:@"placeLabel"];
            
            // Retrieve second place name (=> dateLabel)
            NSArray *names = [self.imageCollections objectAtIndex:indexPath.section].localizedLocationNames;
            NSMutableString *dateLabelName = [NSMutableString new];
            if (([names count] > 0) && ([[names firstObject] length] > 0)) {
                [dateLabelName setString:[names firstObject]];
                for (NSInteger i = 1; i < [names count]; i++) {
                    if ([[names objectAtIndex:i] length] > 0) {
                        [dateLabelName appendFormat:@", %@", [names objectAtIndex:i]];
                    }
                }
                if (dateLabelName) [placeNames setValue:dateLabelName forKey:@"dateLabel"];
            }

            // Set up header
            [header setupWithImages:[self.imagesInSections objectAtIndex:indexPath.section] andPlaceNames:placeNames inSection:indexPath.section andSelectionMode:[[self.selectedSections objectAtIndex:indexPath.section] boolValue]];
            header.headerDelegate = self;

            return header;
        }
    }
    else if (kind == UICollectionElementKindSectionFooter)
    {
        // Display "No Images" if needed
        NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
        footer.noImagesLabel.textColor = [UIColor piwigoHeaderColor];

        if ([[self.imagesInSections objectAtIndex:indexPath.section] count] == 0) {
            // Display "No images"
            footer.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
        } else {
            // Display number of images…
            footer.noImagesLabel.text = [NSString stringWithFormat:@"%ld %@", (long)[[self.imagesInSections objectAtIndex:indexPath.section] count], ([[self.imagesInSections objectAtIndex:indexPath.section] count] > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
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
        view.backgroundColor = [[UIColor piwigoBackgroundColor] colorWithAlphaComponent:0.75];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(collectionView.frame.size.width, 40.0);
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    // Display "No Images" if needed
    NSString *footer = @"";
    if ([[self.imagesInSections objectAtIndex:section] count] == 0) {
        footer = NSLocalizedString(@"noImages", @"No Images");
    } else {
        // Display number of images…
        footer = [NSString stringWithFormat:@"%ld %@", (long)[[self.imagesInSections objectAtIndex:section] count], ([[self.imagesInSections objectAtIndex:section] count] > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
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

#pragma mark - UICollectionView - Sections

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return (self.imagesInSections.count);
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10, kImageMarginsSpacing, 10, kImageMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)[ImagesCollection imageCellVerticalSpacingForCollectionType:kImageCollectionPopup];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)[ImagesCollection imageCellHorizontalSpacingForCollectionType:kImageCollectionPopup];
}


#pragma mark - UICollectionView - Rows

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[self.imagesInSections objectAtIndex:section] count];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:self.nberOfImagesPerRow collectionType:kImageCollectionPopup];
    
    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Create cell
    LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LocalImageCollectionViewCell" forIndexPath:indexPath];
    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    [cell setupWithImageAsset:imageAsset andThumbnailSize:(CGFloat)[ImagesCollection imageSizeForView:collectionView imagesPerRowInPortrait:self.nberOfImagesPerRow collectionType:kImageCollectionPopup]];
    
    // Add pan gesture recognition
    UIPanGestureRecognizer *imageSeriesRocognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(touchedImages:)];
    imageSeriesRocognizer.minimumNumberOfTouches = 1;
    imageSeriesRocognizer.maximumNumberOfTouches = 1;
    imageSeriesRocognizer.cancelsTouchesInView = NO;
    imageSeriesRocognizer.delegate = self;
    [cell addGestureRecognizer:imageSeriesRocognizer];
    cell.userInteractionEnabled = YES;
    
    // Cell state
    cell.cellSelected = [self.selectedImages containsObject:imageAsset];
    NSString *originalFilename = [[PhotosFetch sharedInstance] getFileNameFomImageAsset:imageAsset];
    cell.cellUploading = [[ImageUploadManager sharedInstance].imageNamesUploadQueue containsObject:[originalFilename stringByDeletingPathExtension]];
    
    return cell;
}


#pragma mark - UICollectionView Delegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
    
    // Image asset
    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    
    // Update cell and selection
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
    
    // Update navigation bar
    [self updateNavBar];
    
    // Refresh cell
    [selectedCell reloadInputViews];
    
    // Update state of Select button if needed
    [self updateSelectButtonForSection:indexPath.section];
}


#pragma mark - ImageUploadProgress Delegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    //    NSLog(@"AlbumUploadViewController[imageProgress:]");
    NSIndexPath *indexPath = [self indexPathOfImageAsset:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:indexPath];
    
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
        //        NSLog(@"AlbumUploadViewController[ImageProgress]: %.2f", uploadProgress);
    } else {
        cell.progress = (iCloudProgress + uploadProgress) / 2.0;
        //        NSLog(@"AlbumUploadViewController[ImageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
    }
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
    //    NSLog(@"AlbumUploadViewController[imageUploaded:]");
    NSIndexPath *indexPath = [self indexPathOfImageAsset:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:indexPath];
    
    // Image upload ended, deselect cell
    cell.cellUploading = NO;
    cell.cellSelected = NO;
    if ([self.selectedImages containsObject:image.imageAsset]) {
        [self.selectedImages removeObject:image.imageAsset];
    }
    
    // Update list of "Not Uploaded" images
    if (self.removedUploadedImages)
    {
        NSMutableArray *newList = [self.imagesInSections mutableCopy];
        [newList removeObject:image.imageAsset];
        self.imagesInSections = newList;
        
        // Update image cell
        [self.localImagesCollection reloadItemsAtIndexPaths:@[indexPath]];
    }
}


#pragma mark - Changes occured in the Photo library

- (void)photoLibraryDidChange:(PHChange *)changeInfo {
    // Photos may call this method on a background queue;
    // switch to the main queue to update the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Collect new list of images
        self.imageCollections = [PhotosFetch getMomentCollectionsWithSortType:self.sortType];
        
        // Images in sections
        self.imagesInSections = [[PhotosFetch sharedInstance] getImagesOfMomentCollections:self.imageCollections];
        
        // Loop over selection
        for (PHAsset *selectedImage in [self.selectedImages copy])
        {
            // Loop over all sections
            BOOL selectedImageExists = NO;
            for (NSInteger section = 0; section < [self.imagesInSections count]; section++)
            {
                // Loop over images in section
                for (NSInteger row = 0; row < [[self.imagesInSections objectAtIndex:section] count]; row++)
                {
                    // Check that image exists
                    PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:section] objectAtIndex:row];
                    if ([self.selectedImages containsObject:imageAsset]) {
                        selectedImageExists = YES;
                    }
                }
            }
            
            // Remove selected image if it has been deleted
            if (!selectedImageExists) [self.selectedImages removeObject:selectedImage];
        }
        
        // Reload local image collection
        [self.localImagesCollection reloadData];
        
        // Update Select buttons
        [self updateSelectButtons];
    });
}


#pragma mark - LocalImagesHeaderReusableView Delegate Methods

-(void)didSelectImagesOfSection:(NSInteger)section
{
    // What is the current selection mode of the whole section?
    BOOL wasSelected = [[self.selectedSections objectAtIndex:section] boolValue];
    
    // Number of images in section
    NSInteger nberOfImages = [[self.imagesInSections objectAtIndex:section] count];
    
    // Loop over all items in section
    for (NSInteger item = 0; item < nberOfImages; item++) {
        
        // Corresponding image asset
        PHAsset *imageAsset = [[self.imagesInSections objectAtIndex:section] objectAtIndex:item];
        
        // Corresponding collection view cell
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
        LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:indexPath];
        
        // Select or deselect cell
        if (wasSelected)
        {    // Deselect the cell
            if ([self.selectedImages containsObject:imageAsset]) {
                [self.selectedImages removeObject:imageAsset];
                selectedCell.cellSelected = NO;
            }
        }
        else
        {    // Select the cell
            if (![self.selectedImages containsObject:imageAsset]) {
                [self.selectedImages addObject:imageAsset];
                selectedCell.cellSelected = YES;
            }
        }
    }
    
    // Update navigation bar
    [self updateNavBar];
    
    // Update section
    [self updateSelectButtonForSection:section];
}


#pragma mark - NotUploadedYet Delegate Methods

- (void)showProgressWithSubTitle:(NSString *)title
{
    [MBProgressHUD HUDForView:self.hudViewController.view].detailsLabel.text = title;
}

@end
