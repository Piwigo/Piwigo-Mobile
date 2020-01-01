//
//  ImageUploadParamsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "ImageUploadParamsViewController.h"
#import "EditImagePrivacyTableViewCell.h"
#import "EditImageTextFieldTableViewCell.h"
#import "EditImageTextViewTableViewCell.h"
#import "ImageUploadThumbCollectionViewCell.h"
#import "EditImageTagsTableViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageUpload.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"
#import "PiwigoTagData.h"
#import "SelectPrivacyViewController.h"
#import "TagsData.h"
#import "TagsViewController.h"

CGFloat const kEditImageDetailsViewWidth = 512.0;

typedef enum {
	EditImageDetailsOrderImageName,
	EditImageDetailsOrderAuthor,
	EditImageDetailsOrderPrivacy,
	EditImageDetailsOrderTags,
	EditImageDetailsOrderDescription,
	EditImageDetailsOrderCount
} EditImageDetailsOrder;

@interface ImageUploadParamsViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate, EditImageThumbnailDelegate, SelectPrivacyDelegate, TagsViewControllerDelegate>

@property (nonatomic, strong) ImageUpload *commonParameters;
@property (nonatomic, weak) IBOutlet UITableView *editImageDetailsTableView;
@property (nonatomic, weak) IBOutlet UICollectionView *editImageThumbnailCollectionView;
@property (nonatomic, strong) NSMutableArray<ImageUpload *> *imagesToUpdate;
@property (nonatomic, assign) BOOL shouldUpdateTitle;
@property (nonatomic, assign) BOOL shouldUpdateAuthor;
@property (nonatomic, assign) BOOL shouldUpdatePrivacyLevel;
@property (nonatomic, assign) BOOL shouldUpdateTags;
@property (nonatomic, assign) BOOL shouldUpdateComment;

@end

@implementation ImageUploadParamsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
    self.title = NSLocalizedString(@"imageDetailsView_title", @"Properties");
	
    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
}

#pragma mark - View Lifecycle

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
    self.editImageThumbnailCollectionView.backgroundColor = [UIColor piwigoCellBackgroundColor];
    [self.editImageThumbnailCollectionView reloadData];
    
    // Table view
    self.editImageDetailsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.editImageDetailsTableView.backgroundColor = [UIColor piwigoBackgroundColor];
    [self.editImageDetailsTableView reloadData];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialise common image properties from first supplied image
    self.commonParameters = [[ImageUpload alloc] initWithImageAsset:self.images[0].imageAsset orImageData:nil forCategory:self.images[0].categoryToUploadTo privacyLevel:self.images[0].privacyLevel author:self.images[0].author];
    self.commonParameters.imageTitle = self.images[0].imageTitle;
//    self.commonParameters.categoryToUploadTo = self.images[0].categoryToUploadTo;
//    self.commonParameters.author = self.images[0].author;
//    self.commonParameters.privacyLevel = self.images[0].privacyLevel;
    self.commonParameters.tags = [NSArray arrayWithArray:self.images[0].tags];
    self.commonParameters.comment = self.images[0].comment;

    // Common title?
    for (ImageUpload *imageData in self.images) {
        // Keep title of first image if identical
        if ([self.commonParameters.imageTitle isEqualToString:imageData.imageTitle]) continue;
        
        // Images titles are different
        self.commonParameters.imageTitle = @"";
        break;
    }
    self.shouldUpdateTitle = NO;

    // Common author?
    for (ImageUpload *imageData in self.images) {
        // Keep author of first image if identical
        if ([self.commonParameters.author isEqualToString:imageData.author]) continue;
        
        // Images authors are different
        self.commonParameters.author = @"";
        break;
    }
    self.shouldUpdateAuthor = NO;

    // Common privacy?
    for (ImageUpload *imageData in self.images) {
        // Keep privacy of first image if identical
        if (self.commonParameters.privacyLevel == imageData.privacyLevel) continue;
        
        // Images privacy levels are different, display no level
        self.commonParameters.privacyLevel = NSNotFound;
        break;
    }
    self.shouldUpdatePrivacyLevel = NO;

    // Common tags?
    NSMutableArray *newTags = [[NSMutableArray alloc] initWithArray:self.commonParameters.tags];
    for (ImageUpload *imageData in self.images) {
        // Loop over the common tags
        NSMutableArray *tempTagList = [[NSMutableArray alloc] initWithArray:newTags];
        for (PiwigoTagData *tag in tempTagList) {
            // Remove tags not belonging to other images
            if (![[TagsData sharedInstance] listOfTags:imageData.tags containsTag:tag]) [newTags removeObject:tag];
            // Done if empty list
            if (newTags.count == 0) break;
        }
        // Done if empty list
        if (newTags.count == 0) break;
    }
    self.commonParameters.tags = newTags;
    self.shouldUpdateTags = NO;
    
    // Common comment?
    for (ImageUpload *imageData in self.images) {
        // Keep comment of first image if identical
        if ([self.commonParameters.comment isEqualToString:imageData.comment]) continue;
        
        // Images comments are different, display no comment
        self.commonParameters.comment = @"";
        break;
    }
    self.shouldUpdateComment = NO;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Navigation bar
    self.navigationController.navigationBarHidden = NO;

    // Adjust content inset
    // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
    CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat tableHeight = self.editImageDetailsTableView.bounds.size.height;
    CGFloat viewHeight = self.view.bounds.size.height;

    // On iPad, the form is presented in a popover view
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.editImageDetailsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - viewHeight), 0.0)];
    } else {
        CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        [self.editImageDetailsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - viewHeight), 0.0)];
    }
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // Adjust content inset
        // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
        CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
        CGFloat tableHeight = self.editImageDetailsTableView.bounds.size.height;

        // On iPad, the form is presented in a popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kEditImageDetailsViewWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
            [self.editImageDetailsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - size.height), 0.0)];
        } else {
            CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
            [self.editImageDetailsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - size.height), 0.0)];
        }

        // Reload collection and table views
        [self.editImageThumbnailCollectionView reloadData];
        [self.editImageDetailsTableView reloadData];
    } completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Return updated parameters or nil
    if ([self.delegate respondsToSelector:@selector(didFinishEditingDetails:)])
    {
        [self.delegate didFinishEditingDetails:self.commonParameters];
    }
    
    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationPaletteChanged object:nil];
}


#pragma mark - HUD methods

-(void)showUpdatingImageInfoHUD
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    hud.contentColor = [UIColor piwigoHudContentColor];
    hud.bezelView.color = [UIColor piwigoHudBezelViewColor];
    
    // Define the text
    hud.label.text = NSLocalizedString(@"editImageDetailsHUD_updating", @"Updating Image Info…");
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideUpdatingImageInfoHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
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


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images or albums
    return self.images.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if (@available(iOS 13.0, *)) {
        return UIEdgeInsetsMake(0, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    } else {
        return UIEdgeInsetsMake(10, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageDetailsCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat size = (CGFloat)[ImagesCollection imageDetailsSizeForView:self.view];
    return CGSizeMake(size, 144);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageUploadThumbCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"image" forIndexPath:indexPath];
    if (!cell) {
        cell = [ImageUploadThumbCollectionViewCell new];
    }
    [cell setupWithImage:self.images[indexPath.row] andRemoveOption:(self.images.count > 1)];
    cell.delegate = self;
    return cell;
}


#pragma mark - UITableView - Rows

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;        // To hide the section header
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 44.0;
    switch (indexPath.row)
    {
        case EditImageDetailsOrderPrivacy:
        case EditImageDetailsOrderTags:
            height = 78.0;
            break;
            
        case EditImageDetailsOrderDescription:
            height = 528.0;
            break;
            
        default:
            break;
    }
    
    return height;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return EditImageDetailsOrderCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];
    
    switch(indexPath.row)
    {
        case EditImageDetailsOrderImageName:
        {
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"title" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTextFieldTableViewCell new];
            }
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_title", @"Title:")
                     placeHolder:NSLocalizedString(@"editImageDetails_titlePlaceholder", @"Title")
                  andImageDetail:self.commonParameters.imageTitle];
            cell.cellTextField.tag = EditImageDetailsOrderImageName;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
        }
            
        case EditImageDetailsOrderAuthor:
        {
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"author" forIndexPath:indexPath];
            if(!cell) {
                cell = [EditImageTextFieldTableViewCell new];
            }
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_author", @"Author:")
                     placeHolder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")
                  andImageDetail:[self.commonParameters.author isEqualToString:@"NSNotFound"] ? @"" : self.commonParameters.author];
            cell.cellTextField.tag = EditImageDetailsOrderAuthor;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
        }
            
        case EditImageDetailsOrderPrivacy:
        {
            EditImagePrivacyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImagePrivacyTableViewCell new];
            }
            [cell setLeftLabelText:NSLocalizedString(@"editImageDetails_privacyLevel", @"Who can see this photo?")];
            [cell setPrivacyLevel:self.commonParameters.privacyLevel];
            tableViewCell = cell;
            break;
        }
            
        case EditImageDetailsOrderTags:
        {
            EditImageTagsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tags" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTagsTableViewCell new];
            }
            [cell setTagList:self.commonParameters.tags];
            tableViewCell = cell;
            break;
        }
            
        case EditImageDetailsOrderDescription:
        {
            EditImageTextViewTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"description" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTextViewTableViewCell new];
            }
            [cell setupWithImageDetail:self.commonParameters.comment];
            cell.textView.delegate = self;
            tableViewCell = cell;
            break;
        }
    }
    
    tableViewCell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    tableViewCell.tintColor = [UIColor piwigoOrange];
    return tableViewCell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == EditImageDetailsOrderPrivacy)
    {
        // Dismiss the keyboard
        [self.view endEditing:YES];
        
        // Create view controller
        SelectPrivacyViewController *privacySelectVC = [SelectPrivacyViewController new];
        privacySelectVC.delegate = self;
        [privacySelectVC setPrivacy:(kPiwigoPrivacy)self.commonParameters.privacyLevel];
        [self.navigationController pushViewController:privacySelectVC animated:YES];
    }
    else if (indexPath.row == EditImageDetailsOrderTags)
    {
        // Dismiss the keyboard
        [self.view endEditing:YES];
        
        // Create view controller
        TagsViewController *tagsVC = [TagsViewController new];
        tagsVC.delegate = self;
        tagsVC.alreadySelectedTags = [self.commonParameters.tags mutableCopy];
        [self.navigationController pushViewController:tagsVC animated:YES];
    }
    else if (indexPath.row == EditImageDetailsOrderAuthor) {
        if ([self.commonParameters.author isEqualToString:@"NSNotFound"]) { // only update if not yet set, dont overwrite
            if (0 < [[[Model sharedInstance] defaultAuthor] length]) {  // must know the default author
                self.commonParameters.author = [[Model sharedInstance] defaultAuthor];
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
    
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL result;
    switch (indexPath.row)
    {
        case EditImageDetailsOrderImageName:
        case EditImageDetailsOrderAuthor:
        case EditImageDetailsOrderDescription:
            result = NO;
            break;
            
        default:
            result = YES;
    }
    
    return result;
}


#pragma mark - UITextFieldDelegate Methods

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageDetailsOrderImageName:
        {
            // Title
            self.shouldUpdateTitle = YES;
            break;
        }
            
        case EditImageDetailsOrderAuthor:
        {
            // Author
            self.shouldUpdateAuthor = YES;
            break;
        }
    }
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    switch (textField.tag)
    {
        case EditImageDetailsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = finalString;
            break;
        }
            
        case EditImageDetailsOrderAuthor:
        {
            // Author
            if (finalString.length > 0) {
                self.commonParameters.author = finalString;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageDetailsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = @"";
            break;
        }
            
        case EditImageDetailsOrderAuthor:
        {
            // Author
            self.commonParameters.author = @"NSNotFound";
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.editImageDetailsTableView endEditing:YES];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageDetailsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = textField.text;
            break;
        }
            
        case EditImageDetailsOrderAuthor:
        {
            // Author
            if (textField.text.length > 0) {
                self.commonParameters.author = textField.text;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
}


#pragma mark - UITextViewDelegate Methods

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    self.shouldUpdateComment = YES;
    if ([textView.text isEqualToString:NSLocalizedString(@"editImageDetails_descriptionPlaceholder", @"Description")]) {
        textView.text = @"";
        textView.textColor = [UIColor piwigoLeftLabelColor];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSString *finalString = [textView.text stringByReplacingCharactersInRange:range withString:text];
    if ([finalString isEqualToString:@""]) {
        textView.text = NSLocalizedString(@"editImageDetails_descriptionPlaceholder", @"Description");
        textView.textColor = [UIColor piwigoRightLabelColor];
    }
    
    // Store actual description if cell exists
    self.commonParameters.comment = finalString;
    return YES;
}

-(BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    [self.editImageDetailsTableView endEditing:YES];
    return YES;
}

-(void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@""]) {
        textView.text = NSLocalizedString(@"editImageDetails_descriptionPlaceholder", @"Description");
        textView.textColor = [UIColor piwigoRightLabelColor];
    }
    
    // Store actual description if cell exists
    self.commonParameters.comment = textView.text;
}


#pragma mark - EditImageThumbnailDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Update data source
    NSMutableArray *newImages = [[NSMutableArray alloc] initWithArray:self.images];
    for (ImageUpload *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            [newImages removeObject:imageData];
        }
    }
    self.images = newImages;
    [self.editImageThumbnailCollectionView reloadData];
}


#pragma mark - SelectPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
    // Update image parameter
    self.commonParameters.privacyLevel = privacy;
    
    // Update table view cell
    EditImagePrivacyTableViewCell *cell = (EditImagePrivacyTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderPrivacy inSection:0]];
    if (cell) [cell setPrivacyLevel:privacy];
    
    // Remember to update image info
    self.shouldUpdatePrivacyLevel = YES;
}


#pragma mark - TagsViewControllerDelegate Methods

-(void)didExitWithSelectedTags:(NSArray *)selectedTags
{
    // Update image parameter
    self.commonParameters.tags = selectedTags;
    
    // Update table view cell
    EditImageTagsTableViewCell *cell = (EditImageTagsTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderTags inSection:0]];
    if (cell) [cell setTagList:self.commonParameters.tags];
    
    // Remember to update image info
    self.shouldUpdateTags = YES;
}

@end
