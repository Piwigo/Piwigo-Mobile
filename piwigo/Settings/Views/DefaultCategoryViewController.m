//
//  DefaultCategoryViewController
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import "AppDelegate.h"
#import "DefaultCategoryViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "Model.h"
#import "CategoryTableViewCell.h"
#import "MBProgressHUD.h"
#import "AlbumImagesViewController.h"

@interface DefaultCategoryViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableArray *categoriesThatShowSubCategories;
@property (nonatomic, strong) PiwigoAlbumData *selectedCategory;
@property (nonatomic, strong) UIViewController *hudViewController;

@end

@implementation DefaultCategoryViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"tabBar_albums", @"Albums");
		self.selectedCategory = category;

        // List of categories to present in 2nd section
        self.categories = [NSMutableArray new];
        self.categoriesThatShowSubCategories = [NSMutableArray new];
        
        // Table view
        self.categoriesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.categoriesTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.categoriesTableView.backgroundColor = [UIColor clearColor];
        self.categoriesTableView.alwaysBounceVertical = YES;
        self.categoriesTableView.showsVerticalScrollIndicator = YES;
        self.categoriesTableView.delegate = self;
        self.categoriesTableView.dataSource = self;
        [self.categoriesTableView registerNib:[UINib nibWithNibName:@"CategoryTableViewCell" bundle:nil] forCellReuseIdentifier:@"CategoryTableViewCell"];
        [self.view addSubview:self.categoriesTableView];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.categoriesTableView]];

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
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Table view
    self.categoriesTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.categoriesTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self buildCategoryArrayUsingCache:YES UntilCompletion:^(BOOL result) {
        // Build complete list
        [self.categoriesTableView reloadData];
    } orFailure:^(NSURLSessionTask *task, NSError *error) {
        // Invite users to refresh?
    }];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
    // Set colors, fonts, etc.
    [self paletteChanged];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"setDefaultCategory_title", @"Default Album")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    
    // Text
    NSString *textString = NSLocalizedString(@"categoryUpload_defaultSelect", @"Please select the album or sub-album which will become your default album");
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"setDefaultCategory_title", @"Default Album")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString = NSLocalizedString(@"categoryUpload_defaultSelect", @"Please select the album or sub-album which will become your default album");
    NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
    [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                 range:NSMakeRange(0, [textString length])];
    [headerAttributedString appendAttributedString:textAttributedString];
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;

    // Header view
    UIView *header = [[UIView alloc] init];
    [header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint
                   constraintsWithVisualFormat:@"|-[header]-|"
                                       options:kNilOptions
                                       metrics:nil
                                         views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint
                   constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                       options:kNilOptions
                                       metrics:nil
                                         views:@{@"header" : headerLabel}]];
    }
	
	return header;
}

#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryTableViewCell" forIndexPath:indexPath];
    
    // Determine the depth before setting up the cell
    PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
    NSInteger depth = [categoryData getDepthOfCategory];
    PiwigoAlbumData *defaultCategoryData = [self.categories objectAtIndex:0];
    depth -= [defaultCategoryData getDepthOfCategory];
    [cell setupWithCategoryData:categoryData atDepth:depth];
    
    // Cell accessory
    if(categoryData.albumId == self.selectedCategory.albumId)
    {
        cell.categoryLabel.textColor = [UIColor piwigoRightLabelColor];
    }

    // Switch between Open/Close cell disclosure
    cell.categoryDelegate = self;
    if([self.categoriesThatShowSubCategories containsObject:@(categoryData.albumId)]) {
        cell.upDownImage.image = [UIImage imageNamed:@"cellClose"];
    } else {
        cell.upDownImage.image = [UIImage imageNamed:@"cellOpen"];
    }

    cell.isAccessibilityElement = YES;
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PiwigoAlbumData *categoryData;
    categoryData = [self.categories objectAtIndex:indexPath.row];
    
    if(categoryData.albumId == self.selectedCategory.albumId) return;
    
    NSString *message;
    if (categoryData.albumId == 0) {
        message = [NSString stringWithFormat:NSLocalizedString(@"setDefaultCategory_message", @"Are you sure you want to set the album \"%@\" as default album?"), NSLocalizedString(@"categorySelection_root", @"Root Album")];
    } else {
        message = [NSString stringWithFormat:NSLocalizedString(@"setDefaultCategory_message", @"Are you sure you want to set the album \"%@\" as default album?"), [[[CategoriesData sharedInstance] getCategoryById:categoryData.albumId] name]];
    }
    
    UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"setDefaultCategory_title", @"Default Album")
                             message:message
                      preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *cancelAction = [UIAlertAction
                     actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                               style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction * action) { }];
    
    UIAlertAction *setCategoryAction = [UIAlertAction
                     actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action) {
                                 // Set as Default Album
                                 [Model sharedInstance].defaultCategory = categoryData.albumId;
                                
                                 // Store modified setting
                                 [[Model sharedInstance] saveToDisk];

                                 // Prepare Default album view
                                 [self changedDefaultCategory];
                                 
                                 // Return to Settings
                                 [self.navigationController popViewControllerAnimated:YES];
                             }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:setCategoryAction];
    
    // Determine position of cell in table view
    CGRect rectOfCellInTableView = [tableView rectForRowAtIndexPath:indexPath];
    
    // Determine width of text
    CategoryTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *textString = cell.categoryLabel.text;
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    
    // Calculate horizontal position of popover view
    rectOfCellInTableView.origin.x -= tableView.frame.size.width - textRect.size.width - tableView.layoutMargins.left - 12;
    
    // Present popover view
    alert.popoverPresentationController.sourceView = tableView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft;
    alert.popoverPresentationController.sourceRect = rectOfCellInTableView;
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)changedDefaultCategory
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
            if (thisViewController.categoryId == self.selectedCategory.albumId) {
                // This current view controller will become the child view controller
                index = cur;
            }
        }
        cur++;
    }
    
    // The view controller of the default album does not exist yet
    if (!rootAlbumViewController) {
        // Create an instance of the default album view controller
        rootAlbumViewController = [[AlbumImagesViewController alloc] initWithAlbumId:[Model sharedInstance].defaultCategory inCache:NO];
        // The existing album view controller must become a child of the default album view controller
        NSMutableArray *arrayOfVC = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
        [arrayOfVC insertObject:rootAlbumViewController atIndex:index];
        self.navigationController.viewControllers = arrayOfVC;
    }
    
    // Dismiss Settings and present default album
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            // Replace current album view with default album view
            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationBackToDefaultAlbum object:nil];
        }];
    } else {
        [self.navigationController popToViewController:rootAlbumViewController animated:YES];
    }
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
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
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


#pragma mark - Category List Builder

-(void)buildCategoryArrayUsingCache:(BOOL)useCache
                    UntilCompletion:(void (^)(BOOL result))completion
                          orFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Show loading HUD when not using cache option,
    if (!(useCache && [Model sharedInstance].loadAllCategoryInfo
          && ([Model sharedInstance].defaultCategory == 0))) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")];
        
        // Reload category data and set current category
//        NSLog(@"buildCategoryDf => getAlbumListForCategory(%ld,NO,YES)", (long)0);
        [AlbumService getAlbumListForCategory:0
                                   usingCache:NO
                              inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Build category array
                                     [self buildCategoryArray];
                                     
                                     // Hide loading HUD
                                     [self hideHUD];
                                     
                                     if (completion) {
                                         completion(YES);
                                     }
                                 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        // Hide loading HUD
                                        [self hideHUD];
                                        
                                        if(fail) {
                                            fail(task, error);
                                        }
                                    }
         ];
    } else {
        // Build category array from cache
        [self buildCategoryArray];
        
        if (completion) {
            completion(YES);
        }
    }
}

-(void)buildCategoryArray
{
    self.categories = [NSMutableArray new];
    
    // Build list of categories from complete known lists
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    NSArray *comCategories = [CategoriesData sharedInstance].communityCategoriesForUploadOnly;
    
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for categories which are not already displayed
    for(PiwigoAlbumData *category in allCategories)
    {
        // Search album should not be proposed
        if (category.albumId == kPiwigoSearchCategoryId) {
            continue;
        }
        
        // Non-admin Community users can only upload in specific albums
        if (![Model sharedInstance].hasAdminRights && !category.hasUploadRights) {
            continue;
        }
        
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        if(doesNotExist)
        {
            [diff addObject:category];
        }
    }
    
    // Build list of categories to be displayed
    for(PiwigoAlbumData *category in diff)
    {
        // Always add categories in default album
        if (category.parentAlbumId == 0)
        {
            [self.categories addObject:category];
            continue;
        }
    }
    
    // Add Community private categories
    for(PiwigoAlbumData *category in comCategories)
    {
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        
        if(doesNotExist)
        {
            [self.categories addObject:category];
        }
    }

    // Add root album
    PiwigoAlbumData *rootAlbum = [PiwigoAlbumData new];
    rootAlbum.albumId = 0;
    rootAlbum.name = NSLocalizedString(@"categorySelection_root", @"Root Album");
    [self.categories insertObject:rootAlbum atIndex:0];
}


#pragma mark - CategoryCellDelegate Methods

-(void)tappedDisclosure:(PiwigoAlbumData *)categoryTapped
{
    // Build list of categories from list of known categories
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    NSMutableArray *subcategories = [NSMutableArray new];
    
    // Look for known requested sub-categories
    for(PiwigoAlbumData *category in allCategories)
    {
        // Only add sub-categories of tapped category
        if ((category.parentAlbumId != categoryTapped.albumId) ||
            (category.albumId == self.selectedCategory.albumId)) {
            continue;
        }
        [subcategories addObject:category];
    }
    
    // Look for sub-categories which are already displayed
    NSInteger nberDisplayedSubCategories = 0;
    for(PiwigoAlbumData *category in subcategories)
    {
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                nberDisplayedSubCategories++;
                break;
            }
        }
    }
    
    // This test depends on the caching option loadAllCategoryInfo:
    // => if YES: compare number of sub-albums inside category to be closed
    // => if NO: compare number of sub-sub-albums inside category to be closed
    if ((subcategories.count > 0) && (subcategories.count == nberDisplayedSubCategories))
    {
        // User wants to hide sub-categories
        [self removeSubCategoriesToCategoryID:categoryTapped];
    }
    else if (subcategories.count > 0)
    {
        // Sub-categories are already known
        [self addSubCateroriesToCategoryID:categoryTapped];
    }
    else
    {
        // Sub-categories are not known
//        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")];

        [AlbumService getAlbumListForCategory:categoryTapped.albumId
                                   usingCache:[Model sharedInstance].loadAllCategoryInfo
                              inRecursiveMode:NO
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Add sub-categories
                                     [self addSubCateroriesToCategoryID:categoryTapped];
                                     
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
}

-(void)addSubCateroriesToCategoryID:(PiwigoAlbumData *)categoryTapped
{
    // Build list of categories from complete known list
    NSArray *allCategories = [CategoriesData sharedInstance].allCategories;
    
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for categories which are not already displayed
    for(PiwigoAlbumData *category in allCategories)
    {
        // Non-admin Community users can only upload in specific albums
        if (![Model sharedInstance].hasAdminRights && !category.hasUploadRights) {
            continue;
        }
        
        // Only add sub-categories of tapped category
        if ((category.nearestUpperCategory != categoryTapped.albumId) ||
            (category.albumId == self.selectedCategory.albumId)) {
            continue;
        }
        
        // Is this category already in displayed list?
        BOOL doesNotExist = YES;
        for(PiwigoAlbumData *existingCat in self.categories)
        {
            if(category.albumId == existingCat.albumId)
            {
                doesNotExist = NO;
                break;
            }
        }
        if(doesNotExist)
        {
            [diff addObject:category];
        }
    }
    
    // Build list of categories to be displayed
    for(PiwigoAlbumData *category in diff)
    {
        // Should we add sub-categories?
        if(category.upperCategories.count > 0)
        {
            NSInteger indexOfParent = 0;
            for(PiwigoAlbumData *existingCategory in self.categories)
            {
                if([category containsUpperCategory:existingCategory.albumId])
                {
                    [self.categories insertObject:category atIndex:indexOfParent+1];
                    break;
                }
                indexOfParent++;
            }
        }
    }
    
    // Add tapped category to list of categories having shown sub-categories
    [self.categoriesThatShowSubCategories addObject:@(categoryTapped.albumId)];
    
    // Reload table view
    [self.categoriesTableView reloadData];
}

-(void)removeSubCategoriesToCategoryID:(PiwigoAlbumData *)categoryTapped
{
    // Proposed list is collected in diff
    NSMutableArray *diff = [NSMutableArray new];
    
    // Look for sub-categories to remove
    for(PiwigoAlbumData *category in self.categories)
    {
        // Keep the parent category
        if (category.albumId == categoryTapped.albumId) {
            continue;
        }
        
        // Remove the sub-categories
        NSArray *upperCategories = category.upperCategories;
        if ([upperCategories containsObject:[NSString stringWithFormat:@"%ld", (long)categoryTapped.albumId]])
        {
            [diff addObject:category];
        }
    }
    
    // Remove objects from displayed list
    [self.categories removeObjectsInArray:diff];
    
    // Remove tapped category from list of categories having shown sub-categories
    if ([self.categoriesThatShowSubCategories containsObject:@(categoryTapped.albumId)]) {
        [self.categoriesThatShowSubCategories removeObject:@(categoryTapped.albumId)];
    }
    
    // Sub-categories will not be known if user closes several layers at once
    // and caching option loadAllCategoryInfo is not activated
    if (![Model sharedInstance].loadAllCategoryInfo) {
//        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")];

        [AlbumService getAlbumListForCategory:categoryTapped.albumId
                                   usingCache:NO
                              inRecursiveMode:[Model sharedInstance].loadAllCategoryInfo
                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                     // Reload table view
                                     [self.categoriesTableView reloadData];
                                     
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
    } else {
        // Reload table view
        [self.categoriesTableView reloadData];
    }
}

@end
