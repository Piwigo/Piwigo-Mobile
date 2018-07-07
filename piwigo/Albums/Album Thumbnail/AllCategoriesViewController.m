//
//  AllCategoriesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "AllCategoriesViewController.h"
#import "CategoriesData.h"
#import "AlbumService.h"
#import "Model.h"
#import "CategoryTableViewCell.h"
#import "MBProgressHUD.h"

@interface AllCategoriesViewController () <UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableArray *categoriesThatShowSubCategories;
@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) PiwigoAlbumData *categoryData;
@property (nonatomic, strong) UIViewController *hudViewController;

@end

@implementation AllCategoriesViewController

-(instancetype)initForImageId:(NSInteger)imageId andCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.title = NSLocalizedString(@"categorySelection_select", @"Select Album");
		self.imageId = imageId;
		self.categoryId = categoryId;
        self.categoryData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];

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
        [self.categoriesTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
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


#pragma mark - UITableView - Headers

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    
    if (section == 0)
    {
        // Title
        NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
        NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
        CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:titleAttributes
                                                     context:context];
        
        // Text
        NSString *textString = NSLocalizedString(@"categorySelection_current", @"Select the current album for this image");
        NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
        CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:textAttributes
                                                   context:context];
        return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
    }
    
    // Text
    NSString *textString = NSLocalizedString(@"categorySelection_other", @"or select another album for this image");
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return ceil(textRect.size.height + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    if (section == 0)   // Current album
    {
        // Title
        NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"tabBar_albums", @"Albums")];
        NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
        [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                      range:NSMakeRange(0, [titleString length])];
        [headerAttributedString appendAttributedString:titleAttributedString];
        
        // Text
        NSString *textString = NSLocalizedString(@"categorySelection_current", @"Select the current album for this image");
        NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
        [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                     range:NSMakeRange(0, [textString length])];
        [headerAttributedString appendAttributedString:textAttributedString];
    }
    else                // Or other albums
    {
        // Text
        NSString *textString = NSLocalizedString(@"categorySelection_other", @"or select another album for this image");
        NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
        [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                     range:NSMakeRange(0, [textString length])];
        [headerAttributedString appendAttributedString:textAttributedString];
    }
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
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
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 0)
	{
		return 1;
	}
	return self.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAlbumCell_ID];
    if (!cell) {
        [tableView registerNib:[UINib nibWithNibName:@"CategoryTableViewCell" bundle:nil] forCellReuseIdentifier:kAlbumCell_ID];
        cell = [tableView dequeueReusableCellWithIdentifier:kAlbumCell_ID];
    }

	if(indexPath.section == 0)
	{
        [cell setupDefaultCellWithCategoryData:self.categoryData];
	}
	else
	{
        // Determine the depth before setting up the cell
        PiwigoAlbumData *categoryData = [self.categories objectAtIndex:indexPath.row];
        NSInteger depth = [categoryData getDepthOfCategory];
        PiwigoAlbumData *defaultCategoryData = [self.categories objectAtIndex:0];
        depth -= [defaultCategoryData getDepthOfCategory];
        [cell setupWithCategoryData:categoryData atDepth:depth];

        // Switch between Open/Close cell disclosure
        cell.categoryDelegate = self;
        if([self.categoriesThatShowSubCategories containsObject:@(categoryData.albumId)]) {
            cell.upDownImage.image = [UIImage imageNamed:@"cellClose"];
        } else {
            cell.upDownImage.image = [UIImage imageNamed:@"cellOpen"];
        }
    }

	return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *categoryData;
	
	if(indexPath.section == 1)
	{
        categoryData = [self.categories objectAtIndex:indexPath.row];
	}
	else
	{
		categoryData = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	}
	
    UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"categoryImageSet_title", @"Set Image Thumbnail")
                message:[NSString stringWithFormat:NSLocalizedString(@"categoryImageSet_message", @"Are you sure you want to set this image for the album \"%@\"?"), categoryData.name]
                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
               actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                         style:UIAlertActionStyleCancel
                       handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* setImageAction = [UIAlertAction
             actionWithTitle:NSLocalizedString(@"categoryImageSet_title", @"Set Image Thumbnail")
                       style:UIAlertActionStyleDefault
                     handler:^(UIAlertAction * action) {
                         [self setRepresentativeForCategoryId:categoryData.albumId];
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
    alert.popoverPresentationController.sourceView = tableView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft;
    alert.popoverPresentationController.sourceRect = rectOfCellInTableView;
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Set Category Thumbnail

-(void)setRepresentativeForCategoryId:(NSInteger)categoryId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"categoryImageSetHUD_updating", @"Updating Album Thumbnail…")];
    });
    
    // Set image as representative
	[AlbumService setCategoryRepresentativeForCategory:categoryId
                forImageId:self.imageId
              OnCompletion:^(NSURLSessionTask *task, BOOL setSuccessfully) {
                  if(setSuccessfully)
                  {
                      // Update image Id of album
                      PiwigoAlbumData *category = [[CategoriesData sharedInstance] getCategoryById:categoryId];
                      category.albumThumbnailId = self.imageId;
                      
                      // Update image URL of album
                      PiwigoImageData *imgData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:[NSString stringWithFormat:@"%@", @(self.imageId)]];
                      category.albumThumbnailUrl = imgData.ThumbPath;

                      // Image will be downloaded when displaying list of albums
                      category.categoryImage = nil;
                      
                      // Close HUD
                      [self hideHUDwithSuccess:YES completion:^{
                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 700 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                              [self.navigationController popViewControllerAnimated:YES];
                          });
                      }];
                  }
                  else
                  {
                      // Close HUD and inform user
                      [self hideHUDwithSuccess:NO completion:^{
                          dispatch_async(dispatch_get_main_queue(),^{
                              [self showSetRepresentativeError:nil];
                          });
                      }];
                  }
              } onFailure:^(NSURLSessionTask *task, NSError *error) {
                  // Close HUD and display error
                  [self hideHUDwithSuccess:NO completion:^{
                      dispatch_async(dispatch_get_main_queue(),^{
                          [self showSetRepresentativeError:[error localizedDescription]];
                      });
                  }];
              }];
}

-(void)showSetRepresentativeError:(NSString*)message
{
	NSString *bodyMessage = NSLocalizedString(@"categoryImageSetError_message", @"Failed to set the album image");
	if(message) {
		bodyMessage = [NSString stringWithFormat:@"%@\n%@", bodyMessage, message];
	}
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"categoryImageSetError_title", @"Image Set Error")
                         message:bodyMessage
                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
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


#pragma mark - Category List Builder

-(void)buildCategoryArrayUsingCache:(BOOL)useCache
                    UntilCompletion:(void (^)(BOOL result))completion
                          orFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Show loading HUD when not using cache option,
    if (!(useCache && [Model sharedInstance].loadAllCategoryInfo)) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"categorySelectionHUD_label", @"Retrieving Albums Data…")];
        
        // Reload category data and set current category
        NSLog(@"buildCategoryTh => getAlbumListForCategory(%ld,NO,YES)", (long)[Model sharedInstance].defaultCategory);
        [AlbumService getAlbumListForCategory:[Model sharedInstance].defaultCategory
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
        if (category.parentAlbumId == [Model sharedInstance].defaultCategory)
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
        if (category.parentAlbumId != categoryTapped.albumId) {
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
        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"categorySelectionHUD_label", @"Retrieving Albums Data…")];
        
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
        if (category.nearestUpperCategory != categoryTapped.albumId) {
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
        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"categorySelectionHUD_label", @"Retrieving Albums Data…")];
        
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
