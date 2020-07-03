//
//  TagsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "LabelImageTableViewCell.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "PiwigoTagData.h"
#import "TagsData.h"
#import "TagsViewController.h"
#import "TagsService.h"

@interface TagsViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tagsTableView;
@property (nonatomic, strong) NSArray *letterIndex;
@property (nonatomic, strong) NSMutableArray *notSelectedTags;

@property (nonatomic, strong) UIBarButtonItem *addBarButton;
@property (nonatomic, strong) UIAlertAction *addAction;

@end

@implementation TagsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoColorBackground];
		self.title = NSLocalizedString(@"tags", @"Tags");
				
		self.tagsTableView = [UITableView new];
		self.tagsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.tagsTableView.backgroundColor = [UIColor clearColor];
        self.tagsTableView.sectionIndexColor = [UIColor piwigoColorOrange];
        self.tagsTableView.alwaysBounceVertical = YES;
        self.tagsTableView.showsVerticalScrollIndicator = YES;
		self.tagsTableView.delegate = self;
		self.tagsTableView.dataSource = self;
        [self.tagsTableView registerNib:[UINib nibWithNibName:@"LabelImageTableViewCell" bundle:nil] forCellReuseIdentifier:@"LabelImageTableViewCell"];
		[self.view addSubview:self.tagsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.tagsTableView]];
		
        // ABC index
        [[TagsData sharedInstance] getTagsForAdmin:[Model sharedInstance].hasAdminRights
                                      onCompletion:^(NSArray *tags) {
            
            // Build list of not selected tags
            [self updateListOfNotSelectedTags];

            // Build ABC index
            NSMutableSet *firstCharacters = [NSMutableSet setWithCapacity:0];
            for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] )
                [firstCharacters addObject:[[string substringToIndex:1] uppercaseString]];
            
            self.letterIndex = [[firstCharacters allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			[self.tagsTableView reloadData];
		}];

        // Button
        self.addBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTag)];

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

    // Navigation bar
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
    self.tagsTableView.separatorColor = [UIColor piwigoColorSeparator];
    self.tagsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.tagsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
    
    // Add button for Admins
    if ([Model sharedInstance].hasAdminRights) {
        [self.navigationItem setRightBarButtonItem:self.addBarButton animated:NO];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
    if([self.delegate respondsToSelector:@selector(didExitWithSelectedTags:)])
	{
		[self.delegate didExitWithSelectedTags:self.alreadySelectedTags];
	}
}


#pragma mark - ABC index

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.letterIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    
    NSInteger newRow = [self indexForFirstChar:title inArray:[[TagsData sharedInstance].tagList valueForKey:@"tagName"]];
    NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:newRow inSection:1];
    [tableView scrollToRowAtIndexPath:newIndexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
    
    return index;
}

// Return the index of the first occurence of an item that begins with the supplied character
- (NSInteger)indexForFirstChar:(NSString *)character inArray:(NSArray *)array
{
    NSUInteger count = 0;
    for (NSString *aString in array) {
        if ([aString hasPrefix:character]) {
            return count;
        }
        count++;
    }
    return 0;
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header;
    if (section == 0) {
        header = NSLocalizedString(@"tagsHeader_selected", @"Selected");
    } else {
        header = NSLocalizedString(@"tagsHeader_all", @"All");
    }
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    return fmax(44.0, ceil(headerRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontBold];
    headerLabel.textColor = [UIColor piwigoColorHeader];
    if (section == 0) {
        headerLabel.text = NSLocalizedString(@"tagsHeader_selected", @"Selected");
    } else {
        headerLabel.text = NSLocalizedString(@"tagsHeader_all", @"All");
    }
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Header view
    UIView *header = [[UIView alloc] init];
    header.backgroundColor = [UIColor clearColor];
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
    return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.alreadySelectedTags.count;
    } else {
        return self.notSelectedTags.count;
    }
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LabelImageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LabelImageTableViewCell" forIndexPath:indexPath];
    if(!cell) {
        cell = [LabelImageTableViewCell new];
    }
    
    PiwigoTagData *currentTag;
    if (indexPath.section == 0) {
        // Selected tags
        currentTag = self.alreadySelectedTags[indexPath.row];
        
        // Number of images not known if getAdminList called
        if (currentTag.numberOfImagesUnderTag == NSNotFound) {
            [cell setupWithActivityName:currentTag.tagName andEditOption:kPiwigoActionCellEditRemove];
        } else {
            [cell setupWithActivityName:[NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag] andEditOption:kPiwigoActionCellEditRemove];
        }
    }
    else {
        // Not selected tags
        currentTag = self.notSelectedTags[indexPath.row];
        
        // Number of images not known if getAdminList called
        if (currentTag.numberOfImagesUnderTag == NSNotFound) {
            [cell setupWithActivityName:currentTag.tagName andEditOption:kPiwigoActionCellEditAdd];
        } else {
            [cell setupWithActivityName:[NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag] andEditOption:kPiwigoActionCellEditAdd];
        }
    }
    
    return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

    PiwigoTagData *currentTag;
    if (indexPath.section == 0) {
        // Tapped selected tag
        currentTag = self.alreadySelectedTags[indexPath.row];
        
        // Delete tag tapped in tag list
        [self.alreadySelectedTags removeObject:currentTag];
        
        // Add deselected tag to list of not selected tags
        [self updateListOfNotSelectedTags];
        
        // Determine index of added tag
        NSUInteger indexOfTag = [self.notSelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == currentTag.tagId);
        }];
        NSIndexPath *insertPath = [NSIndexPath indexPathForRow:indexOfTag inSection:1];
        
        // Move cell from top to bottom section
        [tableView moveRowAtIndexPath:indexPath toIndexPath:insertPath];
        
        // Update icon of cell
        LabelImageTableViewCell *cell = [tableView cellForRowAtIndexPath:insertPath];
        if (currentTag.numberOfImagesUnderTag == NSNotFound) {
            [cell setupWithActivityName:currentTag.tagName andEditOption:kPiwigoActionCellEditAdd];
        } else {
            [cell setupWithActivityName:[NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag] andEditOption:kPiwigoActionCellEditAdd];
        }
    }
    else {
        // Tapped not selected tag
        currentTag = self.notSelectedTags[indexPath.row];
        
        // Delete tag tapped in list of not selected tag
        [self.notSelectedTags removeObject:currentTag];
        
        // Add tag to list of selected tags
        [self.alreadySelectedTags addObject:currentTag];
        [self.alreadySelectedTags sortUsingDescriptors:
         [NSArray arrayWithObjects:
          [NSSortDescriptor sortDescriptorWithKey:@"tagName" ascending:YES], nil]];

        // Determine index of added tag
        NSUInteger indexOfTag = [self.alreadySelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == currentTag.tagId);
        }];
        NSIndexPath *insertPath = [NSIndexPath indexPathForRow:indexOfTag inSection:0];
        
        // Move cell from bottom to top section
        [tableView moveRowAtIndexPath:indexPath toIndexPath:insertPath];
        
        // Update icon of cell
        LabelImageTableViewCell *cell = [tableView cellForRowAtIndexPath:insertPath];
        if (currentTag.numberOfImagesUnderTag == NSNotFound) {
            [cell setupWithActivityName:currentTag.tagName andEditOption:kPiwigoActionCellEditRemove];
        } else {
            [cell setupWithActivityName:[NSString stringWithFormat:@"%@ (%ld)", currentTag.tagName, (long)currentTag.numberOfImagesUnderTag] andEditOption:kPiwigoActionCellEditRemove];
        }
    }
}

#pragma mark - Add tag (for admins only)

-(void)addTag
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"tagsAdd_title", @"Add Tag")
        message:NSLocalizedString(@"tagsAdd_message", @"Enter a name for this new tag")
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"tagsAdd_placeholder", @"New tag");
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
    
    self.addAction = [UIAlertAction
           actionWithTitle:NSLocalizedString(@"alertAddButton", @"Add")
           style:UIAlertActionStyleDefault
           handler:^(UIAlertAction * action) {
               // Rename album if possible
               if(alert.textFields.firstObject.text.length > 0) {
                   [self addTagWithName:alert.textFields.firstObject.text andViewController:topViewController];
               }
           }];

    [alert addAction:cancelAction];
    [alert addAction:self.addAction];
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
}

-(void)addTagWithName:(NSString *)tagName andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithLabel:NSLocalizedString(@"tagsAddHUD_label", @"Creating Tag…") inView:topViewController.view];
    });
    
    // Rename album
    [TagsService addTagWithName:tagName
               onCompletion:^(NSURLSessionTask *task, NSInteger tagId) {
                        
                   if (tagId != NSNotFound)
                        {
                            [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    
                                    // Add tag to cached list
                                    PiwigoTagData *newTag = [PiwigoTagData new];
                                    newTag.tagId = tagId;
                                    newTag.tagName = tagName;
                                    newTag.numberOfImagesUnderTag = NSNotFound;
                                    [[TagsData sharedInstance] addTagToList:@[newTag]];
                                    
                                    // Add tag to list of selected tags
                                    [self.alreadySelectedTags addObject:newTag];
                                    [self.alreadySelectedTags sortUsingDescriptors:
                                     [NSArray arrayWithObjects:
                                      [NSSortDescriptor sortDescriptorWithKey:@"tagName" ascending:YES], nil]];
                                    
                                    // Determine index of added tag
                                    NSUInteger indexOfTag = [self.alreadySelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
                                        return (someTag.tagId == newTag.tagId);
                                    }];
                                    NSIndexPath *insertPath = [NSIndexPath indexPathForRow:indexOfTag inSection:0];
                                    [self.tagsTableView insertRowsAtIndexPaths:@[insertPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                                });
                            }];
                        }
                        else
                        {
                            [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                                [self showAddErrorWithMessage:nil andViewController:topViewController];
                            }];
                        }
                } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                            [self showAddErrorWithMessage:[error localizedDescription] andViewController:topViewController];
                        }];
                    }];
}

-(void)showAddErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
{
    NSString *errorMessage = NSLocalizedString(@"tagsAddError_message", @"Failed to create new tag");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"tagsAddError_title", @"Create Fail")
        message:errorMessage
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];
    
    // Present list of actions
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.barButtonItem = self.addBarButton;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - Utilities

-(void)updateListOfNotSelectedTags
{
    // Build list of not selected tags
    self.notSelectedTags = [[NSMutableArray alloc] initWithArray:[TagsData sharedInstance].tagList];
    for (PiwigoTagData *selectedTag in self.alreadySelectedTags) {
        
        // Index of selected tag in full list
        NSUInteger indexOfSelection = [self.notSelectedTags indexOfObjectPassingTest:^BOOL(PiwigoTagData *someTag, NSUInteger idx, BOOL *stop) {
            return (someTag.tagId == selectedTag.tagId);
        }];
        
        // Remove selected tag from full list
        [self.notSelectedTags removeObjectAtIndex:indexOfSelection];
    }
}

-(BOOL)existTagWithName:(NSString *)tagName
{
    // Loop over existing tags (admin list)
    for( NSString *string in [[TagsData sharedInstance].tagList valueForKey:@"tagName"] ) {
        if ([string isEqualToString:tagName]) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - HUD methods

-(void)showHUDwithLabel:(NSString *)label inView:(UIView *)topView
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:topView animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    hud.contentColor = [UIColor piwigoColorText];
    hud.bezelView.color = [UIColor piwigoColorText];
    hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.bezelView.backgroundColor = [UIColor piwigoColorCellBackground];

    // Define the text
    hud.label.text = label;
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideHUDwithSuccess:(BOOL)success inView:(UIView *)topView completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:0.5f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark - UITextField Delegate Methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add/Delete Category action
    [self.addAction setEnabled:NO];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add/Delete Category action if text field not empty
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self.addAction setEnabled:((finalString.length >= 1) && ![self existTagWithName:finalString])];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Add/Delete Category action
    [self.addAction setEnabled:NO];
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

@end
