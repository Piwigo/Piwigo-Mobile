//
//  MoveCategoryViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "MoveCategoryViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "NetworkHandler.h"
#import "Model.h"
#import "CategoryTableViewCell.h"
#import "MBProgressHUD.h"

CGFloat const kMoveCategoryViewWidth = 512.0;           // View width

@interface MoveCategoryViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) PiwigoAlbumData *selectedCategory;
@property (nonatomic, strong) NSArray *recentCategories;
@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableArray *categoriesThatShowSubCategories;
@property (nonatomic, strong) UIViewController *hudViewController;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;

@end

@implementation MoveCategoryViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"moveCategory", @"Move Album");
		self.selectedCategory = category;

        // List of categories to present in 1st section
        self.recentCategories = [NSArray new];
        [self buildRecentCategoryArray];
        
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

        // Button for returning to albums/images
        self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(quitMoveCategory)];

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

    // Navigation bar appearence
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

    // Table view
    self.categoriesTableView.separatorColor = [UIColor piwigoColorSeparator];
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
    [self applyColorPalette];

    // Add Cancel button
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // On iPad, the MoveCategory view is presented in a centered popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kMoveCategoryViewWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
            self.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(mainScreenBounds), ceil(CGRectGetHeight(mainScreenBounds)*1/3),0,0);
        }
        
        // Reload table view
        [self.categoriesTableView reloadData];
    } completion:nil];
}

-(void)quitMoveCategory
{
    // Leave Move Category action and return to Albums and Images
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;

    if (section == 0)   // Recent albums (if any)
    {
        // Title
        NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
        NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
        CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:titleAttributes
                                                     context:context];
    
        // Text
        NSString *textString;
        if (self.recentCategories.count > 0) {
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectRecent", @"Select a recent album to move album \"%@\" into"), self.selectedCategory.name];
        } else {
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectParent", @"Select an album to move album \"%@\" into"), self.selectedCategory.name];
        }
        NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
        CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:textAttributes
                                                   context:context];
        
        return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
    }
    
    // Text
    NSString *textString;
    if (self.recentCategories.count > 0) {
        textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectRecentOther", @"or select another album to move album \"%@\" into"), self.selectedCategory.name];
    }
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    
    return fmax(44.0, ceil(textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    if (section == 0)   // Albums containing image
    {
        // Title
        NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
        NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
        [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                      range:NSMakeRange(0, [titleString length])];
        [headerAttributedString appendAttributedString:titleAttributedString];
    
        // Text
        NSString *textString;
        if (self.recentCategories.count > 0) {
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectRecent", @"Select a recent album to move album \"%@\" into"), self.selectedCategory.name];
        } else {
            textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectParent", @"Select an album to move album \"%@\" into"), self.selectedCategory.name];
        }
        NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
        [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                     range:NSMakeRange(0, [textString length])];
        [headerAttributedString appendAttributedString:textAttributedString];
    }
    else                // Or other albums
    {
        // Text
        NSString *textString = [NSString stringWithFormat:NSLocalizedString(@"moveCategory_selectRecentOther", @"or select another album to move album \"%@\" into"), self.selectedCategory.name];
        NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
        [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                     range:NSMakeRange(0, [textString length])];
        [headerAttributedString appendAttributedString:textAttributedString];
    }
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoColorHeader];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;

    // Header view
    UIView *header = [[UIView alloc] init];
    [header addSubview:headerLabel];
	[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
																   options:kNilOptions
																   metrics:nil
																	 views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    }
	
	return header;
}

#pragma mark - UITableView - Rows

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1 + (self.recentCategories.count > 0);
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows;
    if ((self.recentCategories.count > 0) && (section == 0)) {
        numberOfRows = self.recentCategories.count;
    } else {
        numberOfRows = self.categories.count;
    }

    return numberOfRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryTableViewCell" forIndexPath:indexPath];
    
    if ((self.recentCategories.count > 0) && (indexPath.section == 0)) {
        PiwigoAlbumData *categoryData = [self.recentCategories objectAtIndex:indexPath.row];
        [cell setupWithCategoryData:categoryData atDepth:0 withSubCategoryButton:NO];
    }
    else {
        // Determine the depth before setting up the cell
        PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
        NSInteger depth = [categoryData getDepthOfCategory];
        PiwigoAlbumData *defaultCategoryData = [self.categories objectAtIndex:0];
        depth -= [defaultCategoryData getDepthOfCategory];
        [cell setupWithCategoryData:categoryData atDepth:depth withSubCategoryButton:YES];
        
        // Cell is parent category?
        if (categoryData.albumId == self.selectedCategory.parentAlbumId)
        {
            cell.userInteractionEnabled = NO;
            cell.categoryLabel.textColor = [UIColor piwigoColorRightLabel];
        }

        // Switch between Open/Close cell disclosure
        cell.categoryDelegate = self;
        if([self.categoriesThatShowSubCategories containsObject:@(categoryData.albumId)]) {
            cell.upDownImage.image = [UIImage imageNamed:@"cellClose"];
        } else {
            cell.upDownImage.image = [UIImage imageNamed:@"cellOpen"];
        }
    }

    cell.isAccessibilityElement = YES;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
    if (categoryData.albumId == self.selectedCategory.parentAlbumId)
        return NO;
    
    return YES;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PiwigoAlbumData *categoryData;
    if ((self.recentCategories.count > 0) && (indexPath.section == 0)) {
        categoryData = [self.recentCategories objectAtIndex:indexPath.row];
    } else {
        categoryData = [self.categories objectAtIndex:indexPath.row];
    }
    
    // User cannot move album at current place
    if (categoryData.albumId == self.selectedCategory.parentAlbumId) return;

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:@""
        message:[NSString stringWithFormat:NSLocalizedString(@"moveCategory_message", @"Are you sure you want to move \"%@\" into the album \"%@\"?"), self.selectedCategory.name, categoryData.name]
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
       style:UIAlertActionStyleCancel
       handler:^(UIAlertAction * action) {
//           [self.navigationController popViewControllerAnimated:YES];
       }];
    
    UIAlertAction* setImageAction = [UIAlertAction
         actionWithTitle:NSLocalizedString(@"moveCategory", @"Move Album")
         style:UIAlertActionStyleDefault
         handler:^(UIAlertAction * action) {
             [self makeSelectedCategoryAChildOf:categoryData.albumId];
         }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:setImageAction];
    
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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = tableView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft;
    alert.popoverPresentationController.sourceRect = rectOfCellInTableView;
    [self presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - Move album methods

-(void)makeSelectedCategoryAChildOf:(NSInteger)categoryId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"moveCategoryHUD_moving", @"Moving Album…")];
    });
    
	[AlbumService moveCategory:self.selectedCategory.albumId
				  intoCategory:categoryId
				  OnCompletion:^(NSURLSessionTask *task, BOOL movedSuccessfully) {
					  if(movedSuccessfully)
					  {
                          [self hideHUDwithSuccess:YES completion:^{
                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                  // Update old parent category
                                  PiwigoAlbumData *oldParent = [[CategoriesData sharedInstance] getCategoryById:self.selectedCategory.parentAlbumId];
                                  oldParent.numberOfSubCategories--;
                                  
                                  // Update new parent category
                                  PiwigoAlbumData *newParent = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                                  newParent.numberOfSubCategories++;
                                  
                                  // Update moved category
                                  NSMutableArray *upperCategories = [self.selectedCategory.upperCategories mutableCopy];
                                  [upperCategories removeObject:[NSString stringWithFormat:@"%ld", (long)self.selectedCategory.parentAlbumId]];
                                  [upperCategories addObject:[NSString stringWithFormat:@"%ld", (long)categoryId]];
                                  self.selectedCategory.upperCategories = upperCategories;
                                  self.selectedCategory.parentAlbumId = categoryId;
                                  
                                  // Update cache
                                  [[CategoriesData sharedInstance] updateCategories:@[oldParent, newParent, self.selectedCategory]];

                                  [self quitMoveCategory];
                              });
                          }];
					  }
					  else
					  {
                          [self hideHUDwithSuccess:NO completion:^{
                              [self showMoveCategoryErrorWithMessage:nil];
                          }];
					  }
				  } onFailure:^(NSURLSessionTask *task, NSError *error) {
                      [self hideHUDwithSuccess:NO completion:^{
                          [self showMoveCategoryErrorWithMessage:[error localizedDescription]];
                      }];
				  }];
}

-(void)showMoveCategoryErrorWithMessage:(NSString*)message
{
    NSString *errorMessage = NSLocalizedString(@"moveCategoryError_message", @"Failed to move your album");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"moveCategoryError_title", @"Move Fail")
        message:errorMessage
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
    
    [alert addAction:dismissAction];
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
    [self.navigationController popViewControllerAnimated:YES];
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
//        NSLog(@"buildCategoryMv => getAlbumListForCategory(%ld,NO,YES)", (long)0);
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
        // Smart albums should not be proposed
        if (category.albumId <= kPiwigoSearchCategoryId) {
            continue;
        }

        // Non-admin Community users can only upload in specific albums
        if (![Model sharedInstance].hasAdminRights && !category.hasUploadRights) {
            continue;
        }
        
        // The category to be moved must not be presented
        if (category.albumId == self.selectedCategory.albumId) {
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

-(void)buildRecentCategoryArray
{
    // Current recent categories
    NSArray *recentCat = [[Model sharedInstance].recentCategories componentsSeparatedByString:@","];

    // Build mutable list of recent categories
    NSMutableArray *recentCategories = [NSMutableArray new];
    for (NSString *catIdStr in recentCat)
    {
        // Get category data
        NSInteger catId = [catIdStr integerValue];
        PiwigoAlbumData *categoryData = [[CategoriesData sharedInstance] getCategoryById:catId];
        
        // Check collected data are in cache
        if (categoryData == nil) continue;
        
        // Do not add current category
        if (catId == self.selectedCategory.albumId) continue;

        // Do not add parent categories
        if (self.selectedCategory.parentAlbumId == catId) continue;
        if ([self.selectedCategory.upperCategories containsObject:catIdStr]) continue;

        // Add category if it exists in cache
        [recentCategories addObject:categoryData];
        
        // Reach max number of recent categories?
        if (recentCategories.count == [Model sharedInstance].maxNberRecentCategories) break;
    }
    
    // Set list of recent categories
    self.recentCategories = [recentCategories copy];
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
                                   usingCache:[Model sharedInstance].loadAllCategoryInfo
                              inRecursiveMode:NO
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
