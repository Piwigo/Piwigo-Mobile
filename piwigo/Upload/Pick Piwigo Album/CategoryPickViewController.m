//
//  CategoryPickViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController.h"
#import "AlbumService.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "CategoryPickViewController.h"
#import "CategoryTableViewCell.h"
#import "LocalAlbumsViewController.h"
#import "LabelTableViewCell.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "PhotosFetch.h"

@interface CategoryPickViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, CategoryCellDelegate>

@property (nonatomic, strong) UITableView *categoriesTableView;
@property (nonatomic, assign) NSInteger currentCategoryId;
@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, strong) NSMutableArray *categoriesThatShowSubCategories;
@property (nonatomic, strong) UIAlertAction *createAlbumAction;
@property (nonatomic, strong) UIViewController *hudViewController;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;

@end

@implementation CategoryPickViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId;
{

    self = [super init];
    if(self)
    {
        // User can upload images/videos if he/she has:
        // — admin rights
        // — opened a session on a server having Community extension installed
        if(([Model sharedInstance].hasAdminRights) ||
           ([Model sharedInstance].usesCommunityPluginV29 && [Model sharedInstance].hadOpenedSession))
        {
            self.title = NSLocalizedString(@"tabBar_upload", @"Upload");
            
            // Current category
            self.currentCategoryId = categoryId;
            
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
            self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitUpload)];
            
            // Register category changes
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeCurrentCategory:) name:kPiwigoNotificationChangedCurrentCategory object:nil];

            // Register palette changes
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
        }
        else
        {
            self = (CategoryPickViewController*)[[UIViewController alloc] init];
            
            UILabel *adminLabel = [UILabel new];
            adminLabel.translatesAutoresizingMaskIntoConstraints = NO;
            adminLabel.font = [UIFont piwigoFontNormal];
            adminLabel.font = [adminLabel.font fontWithSize:20];
            adminLabel.textColor = [UIColor piwigoWhiteCream];
            adminLabel.text = NSLocalizedString(@"uploadRights_title", @"Upload Rights Needed");
            adminLabel.minimumScaleFactor = 0.5;
            adminLabel.adjustsFontSizeToFitWidth = YES;
            adminLabel.textAlignment = NSTextAlignmentCenter;
            [self.view addSubview:adminLabel];
            [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:adminLabel]];
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[admin]-10-|"
                                                                              options:kNilOptions
                                                                              metrics:nil
                                                                                views:@{@"admin" : adminLabel}]];
            
            UILabel *description = [UILabel new];
            description.translatesAutoresizingMaskIntoConstraints = NO;
            description.font = [UIFont piwigoFontNormal];
            description.textColor = [UIColor piwigoWhiteCream];
            description.numberOfLines = 4;
            description.textAlignment = NSTextAlignmentCenter;
            description.text = NSLocalizedString(@"uploadRights_message", @"You must have upload rights to be able to upload images or videos.");
            description.adjustsFontSizeToFitWidth = YES;
            description.minimumScaleFactor = 0.5;
            [self.view addSubview:description];
            [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:description]];
            [self.view addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"|-[description]-|"
                                       options:kNilOptions metrics:nil
                                       views:@{@"description" : description}]];
            
            if (@available(iOS 11, *)) {
                [self.view addConstraints:[NSLayoutConstraint
                                           constraintsWithVisualFormat:@"V:|-[admin]-[description]"
                                           options:kNilOptions metrics:nil
                                           views:@{@"admin" : adminLabel, @"description" : description}]];
            } else {
                [self.view addConstraints:[NSLayoutConstraint
                                           constraintsWithVisualFormat:@"V:|-64-[admin]-[description]"
                                           options:kNilOptions metrics:nil
                                           views:@{@"admin" : adminLabel, @"description" : description}]];
            }
        }
    }
	return self;
}


#pragma mark - View Lifecycle

-(void)didChangeCurrentCategory:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    self.currentCategoryId = [[userInfo objectForKey:@"currentCategoryId"] integerValue];
}

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
    
    // Add Done button
    [self.navigationItem setRightBarButtonItems:@[self.doneBarButton] animated:YES];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload tableview on orientation change, to add/remove disclosure indicators
    [self.categoriesTableView reloadData];
}

-(void)quitUpload
{
    // Leave Upload action and return to Albums and Images
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *titleString, *textString;
    NSDictionary *titleAttributes, *textAttributes;
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect, textRect;
    CGFloat heightOfHeader;

    switch (section) {
        case 0:                 // List of actions for the current album
            // Title
            if (self.currentCategoryId == 0) {
                titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categorySelection_root", @"Root Album")];
            } else {
                titleString = [NSString stringWithFormat:@"%@\n", [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] name]];
            }
            titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
            titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:titleAttributes
                                                  context:context];
            
            // Text
            textString = NSLocalizedString(@"categorySelection_action", @"Select an action for this album");
            textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
            textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:textAttributes
                                                context:context];
            heightOfHeader = fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
            break;

        default:                // List of albums to upload images to
            // Title
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categorySelection_titleSub", @"Sub-Albums")];
            titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
            titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:titleAttributes
                                                  context:context];
            
            // Text
            textString = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select a sub-album to upload images to");
            textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
            textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                options:NSStringDrawingUsesLineFragmentOrigin
                                             attributes:textAttributes
                                                context:context];
            heightOfHeader = fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
            break;
    }
    
    return heightOfHeader;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    NSString *titleString, *textString;
    NSMutableAttributedString *titleAttributedString, *textAttributedString;
    
    switch (section) {
        case 0:                 // List of actions for the current album
        {
            // Title
            if (self.currentCategoryId == 0) {
                titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categorySelection_root", @"Root Album")];
            } else {
                titleString = [NSString stringWithFormat:@"%@\n", [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] name]];
            }
            titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
            [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                          range:NSMakeRange(0, [titleString length])];
            [headerAttributedString appendAttributedString:titleAttributedString];
        
            // Text
            textString = NSLocalizedString(@"categorySelection_action", @"Select an action for this album");
            textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
            [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                         range:NSMakeRange(0, [textString length])];
            [headerAttributedString appendAttributedString:textAttributedString];
            break;
        }
            
        default:                // List of albums to upload images to
        {
            // Title
            titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"categorySelection_titleSub", @"Sub-Albums")];
            titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
            [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                          range:NSMakeRange(0, [titleString length])];
            [headerAttributedString appendAttributedString:titleAttributedString];
            
            // Text
            if (self.categories.count == 0) {
                textString = NSLocalizedString(@"categoryUpload_noSubAlbum", @"There is no sub-album to upload images to");
            } else {
                textString = NSLocalizedString(@"categoryUpload_chooseAlbum", @"Select a sub-album to upload images to");
            }
            textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
            [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                         range:NSMakeRange(0, [textString length])];
            [headerAttributedString appendAttributedString:textAttributedString];
        }
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
    NSInteger nberRows = 0;
    switch (section) {
        case 0:                 // List of actions for the current album
            // Upload images only in non-root album and if user has admin or upload rights
            nberRows = (self.currentCategoryId != 0) &&
                       ([Model sharedInstance].hasAdminRights ||
                        [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights]);

            // Only admins can create sub-albums
            nberRows += ([Model sharedInstance].hasAdminRights ? 1 : 0);
            
            // Anyone can set a default album
            nberRows += (self.currentCategoryId != [Model sharedInstance].defaultCategory);
            break;
            
        default:                // List of sub-albums to upload images to
            nberRows = self.categories.count;
            break;
    }
    
    return nberRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];

    switch (indexPath.section) {
        case 0:                 // List of actions for the current album
        {
            switch (indexPath.row) {
                case 0:         // Upload images (or Create sub-album)
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadAction1"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    if ((self.currentCategoryId != 0) &&
                        ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights])) {
                        cell.leftText = NSLocalizedString(@"categoryUpload_images", @"Upload Images");
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    }
                    else if ([Model sharedInstance].hasAdminRights) {
                        cell.leftText = NSLocalizedString(@"categoryUpload_subAlbum", @"Create Sub-Album");
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    else {
                        cell.leftText = NSLocalizedString(@"categoryUpload_defaultAlbum", @"Set as Default Album");
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    tableViewCell = cell;
                    break;
                }
                case 1:         // Create sub-album (or Set as default album)
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadAction2"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    if (((self.currentCategoryId != 0) &&
                         ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights])) &&
                        ([Model sharedInstance].hasAdminRights)) {
                        cell.leftText = NSLocalizedString(@"categoryUpload_subAlbum", @"Create Sub-Album");
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    else {
                        cell.leftText = NSLocalizedString(@"categoryUpload_defaultAlbum", @"Set as Default Album");
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    tableViewCell = cell;
                    break;
                }
                case 2:         // Set as default album
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadAction3"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"categoryUpload_defaultAlbum", @"Set as Default Album");
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    tableViewCell = cell;
                    break;
                }
                default:
                    break;
            }
            break;
        }

        default:                // List of albums to upload images to
        {
            CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CategoryTableViewCell" forIndexPath:indexPath];
            
            // Display disclosure indicator on large screens
            // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
            if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 Plus
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }

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
            
            tableViewCell = cell;
            break;
        }
    }
    
    tableViewCell.isAccessibilityElement = YES;
    return tableViewCell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case 0:                 // List of actions for the current album
        {
            // Which action ?
            switch (indexPath.row) {
                case 0:
                {
                    if ((self.currentCategoryId != 0) &&
                        ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights])) {
                        // Upload images in the current category
                        [self selectedCategory:self.currentCategoryId];
                    }
                    else if ([Model sharedInstance].hasAdminRights) {
                        // Create Sub-Album
                        [self showCreateCategoryDialog];
                    }
                    else {
                        // Set as Default Album
                        [self setCurrentCategoryAsDefaultCategoryAndUpdateTableView:tableView];
                    }
                    break;
                }
                case 1:
                {
                    if (((self.currentCategoryId != 0) &&
                         ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights])) &&
                        ([Model sharedInstance].hasAdminRights)) {
                        // Create Sub-Album
                        [self showCreateCategoryDialog];
                    }
                    else {
                        // Set as Default Album
                        [self setCurrentCategoryAsDefaultCategoryAndUpdateTableView:tableView];
                    }
                    break;
                }
                case 2:
                {
                    // Set as Default Album
                    [self setCurrentCategoryAsDefaultCategoryAndUpdateTableView:tableView];
                    break;
                }
                    
                default:
                    break;
            }
            break;
        }
            
        default:                // List of albums to upload images to
        {
            if(self.categories.count > indexPath.row)
            {
                // Upload images in the selected category
                NSInteger categoryId = [[self.categories objectAtIndex:indexPath.row] albumId];
                [self selectedCategory:categoryId];
            }
            break;
        }
    }    
}


#pragma mark - Upload Images

// Upload images in selected category
-(void)selectedCategory:(NSInteger)categoryId
{
    // Upload images except in root album
    if (categoryId == 0) return;

    // Check autorisation to access Photo Library before uploading
    [[PhotosFetch sharedInstance] checkPhotoLibraryAccessForViewController:self
            onAuthorizedAccess:^{
                      // Open local albums view controller
                      LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:categoryId];
                      [self.navigationController pushViewController:localAlbums animated:YES];
            } onDeniedAccess:nil];
}


#pragma mark - Set Default Category

// Set current category as new default category
-(void)setCurrentCategoryAsDefaultCategoryAndUpdateTableView:(UITableView *)tableView
{
    NSString *message;
    if (self.currentCategoryId == 0) {
        message = [NSString stringWithFormat:NSLocalizedString(@"setDefaultCategory_message", @"Are you sure you want to set the album \"%@\" as default album?"), NSLocalizedString(@"categorySelection_root", @"Root Album")];
    } else {
        message = [NSString stringWithFormat:NSLocalizedString(@"setDefaultCategory_message", @"Are you sure you want to set the album \"%@\" as default album?"), [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] name]];
    }
    
    UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@""
            message:message
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction
               actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
               style:UIAlertActionStyleCancel
               handler:^(UIAlertAction * action) {}];
    
    UIAlertAction *setCategoryAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction * action) {
                    // Set as Default Album
                    // Number of rows will change accordingly
                    [Model sharedInstance].defaultCategory = self.currentCategoryId;

                    // Store modified setting
                    [[Model sharedInstance] saveToDisk];

                    // Position of the row that should be removed
                    NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(
                            ((self.currentCategoryId != 0) && ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights]))
                            + ([Model sharedInstance].hasAdminRights ? 1 : 0)
                            + (self.currentCategoryId != [Model sharedInstance].defaultCategory)) inSection:0];

                    // Remove row in existing table
                    [tableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    
                    // Refresh list of categories
                    [self refreshCategoryList];
                }];
    
    // Add actions
    [alert addAction:cancelAction];
    [alert addAction:setCategoryAction];

    // Determine position of cell in table view
    NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(
                ((self.currentCategoryId != 0) && ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.currentCategoryId] hasUploadRights]))
                + ([Model sharedInstance].hasAdminRights ? 1 : 0)
                + (self.currentCategoryId != [Model sharedInstance].defaultCategory) - 1)
                                                     inSection:0];
    CGRect rectOfCellInTableView = [tableView rectForRowAtIndexPath:rowAtIndexPath];

    // Determine width of text
    NSString *textString = NSLocalizedString(@"categoryUpload_defaultAlbum", @"Set as Default Album");
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


#pragma mark - Create Sub-Album

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
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbumDescription_placeholder", @"Description");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    self.createAlbumAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertAddButton", @"Add")
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * action) {
                                  // Create album
                                  [self addCategoryWithName:alert.textFields.firstObject.text
                                                 andComment:alert.textFields.lastObject.text
                                                   inParent:self.currentCategoryId];
                              }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.createAlbumAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)addCategoryWithName:(NSString *)albumName andComment:(NSString *)albumComment
                  inParent:(NSInteger)parentId
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithTitle:NSLocalizedString(@"createNewAlbumHUD_label", @"Creating Album…")];
    });
    
    // Create album
    [AlbumService createCategoryWithName:albumName
                  withStatus:@"public"
                  andComment:albumComment
                    inParent:parentId
                OnCompletion:^(NSURLSessionTask *task, BOOL createdSuccessfully) {
                    if(createdSuccessfully)
                    {
                        // Post to the app that category data have changed
                        if ([Model sharedInstance].loadAllCategoryInfo) {
                            NSDictionary *userInfo = @{@"NoHUD" : @"YES", @"fromCache" : @"NO"};
                            [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationGetCategoryData object:nil userInfo:userInfo];
                        }

                        // Refresh list of categories (and cache)
                        [self refreshCategoryList];

                        // Hide HUD
                        [self hideHUDwithSuccess:YES completion:nil];
                    }
                    else
                    {
                        // Hide HUD and inform user
                        [self hideHUDwithSuccess:NO completion:^{
                            [self showCreateCategoryErrorWithMessage:nil];
                        }];
                    }
                } onFailure:^(NSURLSessionTask *task, NSError *error) {
                    // Hide HUD and inform user
                    [self hideHUDwithSuccess:NO completion:^{
                        [self showCreateCategoryErrorWithMessage:[error localizedDescription]];
                    }];
                }];
}

-(void)showCreateCategoryErrorWithMessage:(NSString*)message
{
    NSString *errorMessage = NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error")
            message:errorMessage
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:dismissAction];

    // Present list of actions
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - HUD Methods

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


#pragma mark - Category List Builder

-(void)refreshCategoryList
{
    // Rebuild list of categories
    [self buildCategoryArrayUsingCache:NO UntilCompletion:^(BOOL result) {
        [self.categoriesTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    } orFailure:^(NSURLSessionTask *task, NSError *error) {
        // Invite users to refresh?
    }];
}

-(void)buildCategoryArrayUsingCache:(BOOL)useCache
                    UntilCompletion:(void (^)(BOOL result))completion
                          orFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    // Show loading HUD when not using cache option,
    if (!(useCache && [Model sharedInstance].loadAllCategoryInfo)) {
        // Show loading HD
        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")];
        
        // Reload category data and set current category
//        NSLog(@"buildCategoryPk => getAlbumListForCategory(%ld,NO,YES)", (long)self.currentCategoryId);
        [AlbumService getAlbumListForCategory:self.currentCategoryId
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
        if (category.parentAlbumId == self.currentCategoryId)
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
    
    // Reload table view
    [self.categoriesTableView reloadData];

    // Sub-categories will not be known if user closes several layers at once
    // and caching option loadAllCategoryInfo is not activated
//    if (![Model sharedInstance].loadAllCategoryInfo) {
//        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);
//
//        // Show loading HD
//        [self showHUDwithTitle:NSLocalizedString(@"loadingHUD_label", @"Loading…")];
//        
//        [AlbumService getAlbumListForCategory:categoryTapped.albumId
//                                   usingCache:[Model sharedInstance].loadAllCategoryInfo
//                              inRecursiveMode:NO
//                                 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
//                                     // Reload table view
//                                     [self.categoriesTableView reloadData];
//                                     
//                                     // Hide loading HUD
//                                     [self hideHUD];
//                                 }
//                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
//#if defined(DEBUG)
//                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
//#endif
//                                        // Hide loading HUD
//                                        [self hideHUD];
//                                    }
//         ];
//    } else {
//        // Reload table view
//        [self.categoriesTableView reloadData];
//    }
}

@end
