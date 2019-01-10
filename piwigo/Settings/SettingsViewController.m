//
//  SettingsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
#import <MessageUI/MessageUI.h>
#import <sys/utsname.h>

#import "AboutViewController.h"
#import "AlbumService.h"
#import "AppDelegate.h"
#import "ButtonTableViewCell.h"
#import "CategoriesData.h"
#import "CategorySortViewController.h"
#import "ClearCache.h"
#import "DefaultCategoryViewController.h"
#import "DefaultImageSizeViewController.h"
#import "DefaultThumbnailSizeViewController.h"
#import "ImagesCollection.h"
#import "LabelTableViewCell.h"
#import "Model.h"
#import "PiwigoImageData.h"
#import "PrivacyPolicyViewController.h"
#import "ReleaseNotesViewController.h"
#import "SelectPrivacyViewController.h"
#import "SessionService.h"
#import "SettingsViewController.h"
#import "SliderTableViewCell.h"
#import "SwitchTableViewCell.h"
#import "TextFieldTableViewCell.h"

typedef enum {
	SettingsSectionServer,
	SettingsSectionLogout,
    SettingsSectionAlbums,
    SettingsSectionImages,
	SettingsSectionImageUpload,
    SettingsSectionColor,
    SettingsSectionCache,
    SettingsSectionClear,
	SettingsSectionAbout,
	SettingsSectionCount
} SettingsSection;

typedef enum {
	kImageUploadSettingAuthor
} kImageUploadSetting;

NSString * const kHelpUsTitle = @"Help Us!";
NSString * const kHelpUsTranslatePiwigo = @"Piwigo is only partially translated in your language. Could you please help us complete the translation?";

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SelectPrivacyDelegate, CategorySortDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, strong) NSLayoutConstraint *tableViewBottomConstraint;
@property (nonatomic, strong) UIBarButtonItem *doneBarButton;
@property (nonatomic, strong) NSString *nberCategories;
@property (nonatomic, strong) NSString *nberImages;
@property (nonatomic, strong) NSString *nberTags;
@property (nonatomic, strong) NSString *nberUsers;
@property (nonatomic, strong) NSString *nberGroups;
@property (nonatomic, strong) NSString *nberComments;

@end

@implementation SettingsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
        // Table view
        self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.settingsTableView.backgroundColor = [UIColor clearColor];
		self.settingsTableView.delegate = self;
		self.settingsTableView.dataSource = self;
        [self.settingsTableView setAccessibilityIdentifier:@"preferences"];
		[self.view addSubview:self.settingsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.settingsTableView]];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.settingsTableView amount:0]];
		self.tableViewBottomConstraint = [NSLayoutConstraint constraintViewFromBottom:self.settingsTableView amount:0];
		[self.view addConstraint:self.tableViewBottomConstraint];

        // Button for returning to albums/images
        self.doneBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(quitSettings)];
        [self.doneBarButton setAccessibilityIdentifier:@"Done"];
        
        // Keyboard management
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];

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
        NSDictionary *attributesLarge = @{
                                          NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                          NSFontAttributeName: [UIFont piwigoFontLargeTitle],
                                          };
        self.navigationController.navigationBar.largeTitleTextAttributes = attributesLarge;
        self.navigationController.navigationBar.prefersLargeTitles = YES;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    
    // Table view
    self.settingsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.settingsTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.settingsTableView reloadData];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Get Server Infos if possible
    if ([Model sharedInstance].hasAdminRights)
        [self getInfos];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self paletteChanged];
    
    // Set navigation buttons
    [self.navigationItem setRightBarButtonItems:@[self.doneBarButton] animated:YES];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (@available(iOS 10, *)) {
        NSString *langCode = [[NSLocale currentLocale] languageCode];
//    NSLog(@"=> langCode: %@", langCode);
//    NSLog(@"=> now:%.0f > last:%.0f + %.0f", [[NSDate date] timeIntervalSinceReferenceDate], [Model sharedInstance].dateOfLastTranslationRequest, kTwentyDays);
        if (([[NSDate date] timeIntervalSinceReferenceDate] > [Model sharedInstance].dateOfLastTranslationRequest + k2WeeksInDays) &&
            ([langCode isEqualToString:@"ar"] ||
             [langCode isEqualToString:@"fa"] ||
             [langCode isEqualToString:@"pl"] ||
             [langCode isEqualToString:@"sk"] ))
        {
            // Store date of last translation request
            [Model sharedInstance].dateOfLastTranslationRequest = [[NSDate date] timeIntervalSinceReferenceDate];
            [[Model sharedInstance] saveToDisk];
            
            // Request a translation
            UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:kHelpUsTitle
                    message:kHelpUsTranslatePiwigo
                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* cancelAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                    style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction * action) {}];

            UIAlertAction* defaultAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://crowdin.com/project/piwigo-mobile"]];
                    }];
            
            [alert addAction:cancelAction];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // On iPad, the Settings section is presented in a centered popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            [self.popoverPresentationController setSourceRect:CGRectMake(CGRectGetMidX(mainScreenBounds), CGRectGetMidY(mainScreenBounds), 0, 0)];
            self.preferredContentSize = CGSizeMake(ceil(CGRectGetWidth(mainScreenBounds)*2/3), ceil(CGRectGetHeight(mainScreenBounds)*2/3));
        }
        
        // Reload table view
        [self.settingsTableView reloadData];
    } completion:nil];
}

-(void)quitSettings
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    // Header strings
    NSString *titleString, *textString = @"";
    switch(section)
    {
        case SettingsSectionServer:
            if ([[Model sharedInstance].serverProtocol isEqualToString:@"https://"]) {
                titleString = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"settingsHeader_server", @"Piwigo Server"), [Model sharedInstance].version];
            } else {
                titleString = [NSString stringWithFormat:@"%@ %@\n", NSLocalizedString(@"settingsHeader_server", @"Piwigo Server"), [Model sharedInstance].version];
                textString = NSLocalizedString(@"settingsHeader_notSecure", @"Website Not Secure!");
            }
            break;
        case SettingsSectionLogout:
        case SettingsSectionClear:
            return 14;
        case SettingsSectionAlbums:
            titleString = NSLocalizedString(@"tabBar_albums", @"Albums");
            break;
        case SettingsSectionImages:
            titleString = NSLocalizedString(@"settingsHeader_images", @"Images");
            break;
        case SettingsSectionImageUpload:
            titleString = NSLocalizedString(@"settingsHeader_upload", @"Default Upload Settings");
            break;
        case SettingsSectionColor:
            titleString = NSLocalizedString(@"settingsHeader_colors", @"Colors");
            break;
        case SettingsSectionCache:
            titleString = NSLocalizedString(@"settingsHeader_cache", @"Cache Settings (Used/Total)");
            break;
        case SettingsSectionAbout:
            titleString = NSLocalizedString(@"settingsHeader_about", @"Information");
            break;
    }

    // Header height
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];

    // Header height
    NSInteger headerHeight;
    if ([textString length] > 0) {
        NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
        CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:textAttributes
                                                   context:context];
        headerHeight = fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
    } else {
        headerHeight = fmax(44.0, ceil(titleRect.size.height));
    }

    return headerHeight;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    // Header strings
    NSString *titleString, *textString = @"";
    switch(section)
    {
        case SettingsSectionServer:
            if ([[Model sharedInstance].serverProtocol isEqualToString:@"https://"]) {
                titleString = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"settingsHeader_server", @"Piwigo Server"), [Model sharedInstance].version];
            } else {
                titleString = [NSString stringWithFormat:@"%@ %@\n", NSLocalizedString(@"settingsHeader_server", @"Piwigo Server"), [Model sharedInstance].version];
                textString = NSLocalizedString(@"settingsHeader_notSecure", @"Website Not Secure!");
            }
            break;
        case SettingsSectionLogout:
        case SettingsSectionClear:
            return nil;
        case SettingsSectionAlbums:
            titleString = NSLocalizedString(@"tabBar_albums", @"Albums");
            break;
        case SettingsSectionImages:
            titleString = NSLocalizedString(@"settingsHeader_images", @"Images");
            break;
        case SettingsSectionImageUpload:
            titleString = NSLocalizedString(@"settingsHeader_upload", @"Default Upload Settings");
            break;
        case SettingsSectionColor:
            titleString = NSLocalizedString(@"settingsHeader_colors", @"Colors");
            break;
        case SettingsSectionCache:
            titleString = NSLocalizedString(@"settingsHeader_cache", @"Cache Settings (Used/Total)");
            break;
        case SettingsSectionAbout:
            titleString = NSLocalizedString(@"settingsHeader_about", @"Information");
            break;
    }
    
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    if ([textString length] > 0) {
        NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
        [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                     range:NSMakeRange(0, [textString length])];
        [headerAttributedString appendAttributedString:textAttributedString];
    }
    
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
    header.backgroundColor = [UIColor clearColor];
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
    return SettingsSectionCount - (!([Model sharedInstance].hasAdminRights ||
                                     [Model sharedInstance].usesCommunityPluginV29) ||
                                   ![Model sharedInstance].hadOpenedSession);
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    NSInteger nberOfRows = 0;
    switch(section)
    {
        case SettingsSectionServer:
            nberOfRows = 2;
            break;
        case SettingsSectionLogout:
            nberOfRows = 1;
            break;
        case SettingsSectionAlbums:
            nberOfRows = 5;
            break;
        case SettingsSectionImages:
            nberOfRows = 1;
            break;
        case SettingsSectionImageUpload:
            nberOfRows = 6 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0) +
                                ([Model sharedInstance].compressImageOnUpload ? 1 : 0);
            break;
        case SettingsSectionColor:
            nberOfRows = 1 + ([Model sharedInstance].isDarkPaletteModeActive ? 1 + ([Model sharedInstance].switchPaletteAutomatically ? 1 : 0) : 0);
            break;
        case SettingsSectionCache:
            nberOfRows = 3;
            break;
        case SettingsSectionClear:
            nberOfRows = 1;
            break;
        case SettingsSectionAbout:
            nberOfRows = 8;
            break;
    }
    return nberOfRows;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    NSInteger section = indexPath.section;
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }
    
    UITableViewCell *tableViewCell = [UITableViewCell new];
	switch(section)
	{
#pragma mark Server
		case SettingsSectionServer:      // Piwigo Server
		{
			LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server"];
			if(!cell)
			{
				cell = [LabelTableViewCell new];
			}
            switch(indexPath.row)
			{
				case 0:
                    cell.leftText = NSLocalizedString(@"settings_server", @"Address");
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
                        cell.rightText = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
                    } else {
                        cell.rightText = [Model sharedInstance].serverName;
                    }
                    [cell setAccessibilityIdentifier:@"server"];
					break;
				case 1:
					cell.leftText = NSLocalizedString(@"settings_username", @"Username");
					if([Model sharedInstance].username.length > 0)
					{
						cell.rightText = [Model sharedInstance].username;
					}
					else
					{
						cell.rightText = NSLocalizedString(@"settings_notLoggedIn", @" - Not Logged In - ");
					}
					break;
			}
			tableViewCell = cell;
			break;
		}
		case SettingsSectionLogout:      // Logout Button
		{
			ButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
			if(!cell)
			{
				cell = [ButtonTableViewCell new];
			}
			if([Model sharedInstance].username.length > 0)
			{
				cell.buttonText = NSLocalizedString(@"settings_logout", @"Logout");
			}
			else
			{
				cell.buttonText = NSLocalizedString(@"login", @"Login");
			}
			tableViewCell = cell;
			break;
		}

#pragma mark Albums
        case SettingsSectionAlbums:         // Albums
		{
			switch(indexPath.row)
			{
                case 0:     // Default album
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultAlbum"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"setDefaultCategory_title", @"Default Album";);
                    if ([Model sharedInstance].defaultCategory == 0) {
                        cell.rightText = NSLocalizedString(@"categorySelection_root", @"Root Album");
                    } else {
                        cell.rightText = [[[CategoriesData sharedInstance] getCategoryById:[Model sharedInstance].defaultCategory] name];
                    }
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    [cell setAccessibilityIdentifier:@"defaultAlbum"];
                    
                    tableViewCell = cell;
                    break;
                }
				case 1:     // Default Sort
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultSort"];
					if(!cell)
					{
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 Plus screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSort>414px", @"Default Sort of Images");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSort>320px", @"Default Sort");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultImageSort", @"Sort");
                    }
					cell.rightText = [CategorySortViewController getNameForCategorySortType:[Model sharedInstance].defaultSort];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    [cell setAccessibilityIdentifier:@"defaultSort"];

                    tableViewCell = cell;
					break;
				}
				case 2:     // Default Thumbnail File
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultThumbnailFile"];
					if(!cell) {
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile>414px", @"Thumbnail Image File");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile>320px", @"Thumbnail File");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultThumbnailFile", @"File");
                    }
					cell.rightText = [PiwigoImageData nameForThumbnailSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    [cell setAccessibilityIdentifier:@"defaultThumbnailFile"];

					tableViewCell = cell;
					break;
				}
                case 3:     // Default Thumbnail Size
                {
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultThumbnailSize"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize>414px", @"Default Size of Thumbnails");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize>320px", @"Thumbnails Size");
                    } else {
                        cell.sliderName.text = NSLocalizedString(@"defaultThumbnailSize", @"Size");
                    }
                    
                    NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:kThumbnailFileSize];
                    cell.slider.minimumValue = 1;
                    cell.slider.maximumValue = 1 + minNberOfImages; // Allows to double the number of thumbnails
                    cell.incrementSliderBy = 1;
                    cell.sliderCountPrefix = @"";
                    cell.sliderCountSuffix = [NSString stringWithFormat:@"/%d", (int)cell.slider.maximumValue];
                    cell.sliderValue = 2 * minNberOfImages - [Model sharedInstance].thumbnailsPerRowInPortrait + 1;
                    [cell.slider addTarget:self action:@selector(updateThumbnailSize:) forControlEvents:UIControlEventValueChanged];
                    [cell setAccessibilityIdentifier:@"defaultThumbnailSize"];

                    tableViewCell = cell;
                    break;
                }
                case 4:     // Display titles on thumbnails
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"titles"];
                    if(!cell)
                    {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 320) {
                        cell.leftLabel.text = NSLocalizedString(@"settings_displayTitles>320px", @"Display Titles on Thumbnails");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_displayTitles", @"Titles on Thumbnails");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].displayImageTitles];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].displayImageTitles = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    [cell setAccessibilityIdentifier:@"titles"];

                    tableViewCell = cell;
                    break;
                }
			}
			break;
		}

#pragma mark Images
        case SettingsSectionImages:     // Images
        {
            switch(indexPath.row)
            {
                case 0:     // Default Size of Previewed Images
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultPreviewFile"];
                    if(!cell) {
                        cell = [LabelTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile>414px", @"Preview Image File");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile>320px", @"Preview File");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultPreviewFile", @"Preview");
                    }
                    cell.rightText = [PiwigoImageData nameForImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize withAdvice:NO];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

#pragma mark Default Upload Settings
        case SettingsSectionImageUpload:     // Default Upload Settings
		{
			switch(indexPath.row)
			{
				case 0:     // Author Name
				{
					TextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadSettingsField"];
					if(!cell)
					{
						cell = [TextFieldTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.labelText = NSLocalizedString(@"settings_defaultAuthor>320px", @"Author Name");
                    } else {
                        cell.labelText = NSLocalizedString(@"settings_defaultAuthor", @"Author");
                    }
					cell.rightTextField.text = [Model sharedInstance].defaultAuthor;
					cell.rightTextField.placeholder = NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name");
					cell.rightTextField.delegate = self;
					cell.rightTextField.tag = kImageUploadSettingAuthor;
					
					tableViewCell = cell;
					break;
				}
				case 1:     // Privacy Level
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy"];
					if(!cell)
					{
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 Plus screen width
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Who Can See the Media?");
                    } else {
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy", @"Privacy");
                    }
					cell.rightText = [[Model sharedInstance] getNameForPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

					tableViewCell = cell;
					break;
				}
                case 2:     // Strip private Metadata
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"gps"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata>375px", @"Strip Private Metadata Before Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata", @"Strip Private Metadata");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].stripGPSdataOnUpload];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].stripGPSdataOnUpload = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                   
                    tableViewCell = cell;
                    break;
                }
				case 3:     // Resize Before Upload
				{
					SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resize"];
					if(!cell) {
						cell = [SwitchTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_photoResize>375px", @"Resize Image Before Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_photoResize", @"Resize Before Upload");
                    }
					[cell.cellSwitch setOn:[Model sharedInstance].resizeImageOnUpload];
					cell.cellSwitchBlock = ^(BOOL switchState) {
                        // Number of rows will change accordingly
                        [Model sharedInstance].resizeImageOnUpload = switchState;
                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];
                        // Position of the row that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:4
                                                                         inSection:SettingsSectionImageUpload];
                        if(switchState) {
                            // Insert row in existing table
                            [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                           // Remove row in existing table
                            [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
					};
					
					tableViewCell = cell;
					break;
				}
                case 4:     // Image Size slider or Compress Before Upload switch
                {
                    if ([Model sharedInstance].resizeImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoSize"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoSize", @"> Size");
                        cell.slider.minimumValue = 5;
                        cell.slider.maximumValue = 100;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 5;
                        cell.sliderValue = [Model sharedInstance].photoResize;
                        [cell.slider addTarget:self action:@selector(updateImageSize:) forControlEvents:UIControlEventValueChanged];

                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"compress"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress>375px", @"Compress Image Before Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress", @"Compress Before Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].compressImageOnUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            // Number of rows will change accordingly
                            [Model sharedInstance].compressImageOnUpload = switchState;
                            // Store modified setting
                            [[Model sharedInstance] saveToDisk];
                            // Position of the row that should be added/removed (depends on resize option)
                            NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0))
                                                                             inSection:SettingsSectionImageUpload];
                            if(switchState) {
                                // Insert row in existing table
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            } else {
                                // Remove row in existing table
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            }
                        };
                        
                        tableViewCell = cell;
                    }
                    break;
                }
                case 5:     // Compress Before Upload switch or Image Quality slider or Delete Image switch
                {
                    if ([Model sharedInstance].resizeImageOnUpload) {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"compress"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress>375px", @"Compress Image Before Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_photoCompress", @"Compress Before Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].compressImageOnUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            // Number of rows will change accordingly
                            [Model sharedInstance].compressImageOnUpload = switchState;
                            // Store modified setting
                            [[Model sharedInstance] saveToDisk];
                            // Position of the row that should be added/removed
                            NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:(5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0))
                                                                             inSection:SettingsSectionImageUpload];
                            if(switchState) {
                                // Insert row in existing table
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            } else {
                                // Remove row in existing table
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            }
                        };
                        
                        tableViewCell = cell;
                    } else if ([Model sharedInstance].compressImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoQuality"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoQuality", @"> Quality");
                        cell.slider.minimumValue = 50;
                        cell.slider.maximumValue = 98;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 2;
                        cell.sliderValue = [Model sharedInstance].photoQuality;
                        [cell.slider addTarget:self action:@selector(updateImageQuality:) forControlEvents:UIControlEventValueChanged];
                        
                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            [Model sharedInstance].deleteImageAfterUpload = switchState;
                            [[Model sharedInstance] saveToDisk];
                        };
                        
                        tableViewCell = cell;
                    }
                    break;
                }
				case 6:     // Image Quality slider or Delete Image switch
				{
                    if ([Model sharedInstance].resizeImageOnUpload && [Model sharedInstance].compressImageOnUpload) {
                        SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoQuality"];
                        if(!cell)
                        {
                            cell = [SliderTableViewCell new];
                        }
                        cell.sliderName.text = NSLocalizedString(@"settings_photoQuality", @"> Quality");
                        cell.slider.minimumValue = 50;
                        cell.slider.maximumValue = 98;
                        cell.sliderCountPrefix = @"";
                        cell.sliderCountSuffix = @"%";
                        cell.incrementSliderBy = 2;
                        cell.sliderValue = [Model sharedInstance].photoQuality;
                        [cell.slider addTarget:self action:@selector(updateImageQuality:) forControlEvents:UIControlEventValueChanged];
                        
                        tableViewCell = cell;
                    } else {
                        SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                        if(!cell) {
                            cell = [SwitchTableViewCell new];
                        }
                        
                        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                        if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                        } else {
                            cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                        }
                        [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                        cell.cellSwitchBlock = ^(BOOL switchState) {
                            [Model sharedInstance].deleteImageAfterUpload = switchState;
                            [[Model sharedInstance] saveToDisk];
                        };
                        
                        tableViewCell = cell;
                    }
					break;
				}
                case 7:     // Delete image after upload
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"delete"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage>375px", @"Delete Image After Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_deleteImage", @"Delete After Upload");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].deleteImageAfterUpload];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].deleteImageAfterUpload = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
			}
			break;
		}

#pragma mark Colors
        case SettingsSectionColor:      // Colors
        {
            NSInteger sectionOffset = !([Model sharedInstance].hasAdminRights ||
                                        [Model sharedInstance].usesCommunityPluginV29) ||
                                      ![Model sharedInstance].hadOpenedSession;
            switch (indexPath.row)
            {
                case 0:     // Dark Palette Mode
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"darkPalette"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    cell.leftLabel.text = NSLocalizedString(@"settings_darkPalette", @"Dark Palette");
                    [cell.cellSwitch setOn:[Model sharedInstance].isDarkPaletteModeActive];
                    cell.cellSwitchBlock = ^(BOOL switchState) {

                        // Number of rows will change accordingly
                        [Model sharedInstance].isDarkPaletteModeActive = switchState;

                        // Position of the row(s) that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:1
                                                            inSection:SettingsSectionColor - sectionOffset];
                        NSIndexPath *row2AtIndexPath = [NSIndexPath indexPathForRow:2
                                                            inSection:SettingsSectionColor - sectionOffset];
                        if(switchState) {
                            // Insert row in existing table
                            if ([Model sharedInstance].switchPaletteAutomatically)
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath,row2AtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            else
                                [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                            // Remove row in existing table
                            if ([Model sharedInstance].switchPaletteAutomatically)
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath,row2AtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                            else
                                [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        // Switch off auto mode if dark palette mode disabled
                        if (!switchState) [Model sharedInstance].switchPaletteAutomatically = NO;

                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];
 
                        // Notify palette change
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate screenBrightnessChanged:nil];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Switch automatically ?
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switchPalette"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    cell.leftLabel.text = NSLocalizedString(@"settings_switchPalette", @"Switch Automatically");
                    [cell.cellSwitch setOn:[Model sharedInstance].switchPaletteAutomatically];
                    cell.cellSwitchBlock = ^(BOOL switchState) {

                        // Number of rows will change accordingly
                        [Model sharedInstance].switchPaletteAutomatically = switchState;

                        // Store modified setting
                        [[Model sharedInstance] saveToDisk];

                        // Position of the row that should be added/removed
                        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:2
                                                            inSection:SettingsSectionColor - sectionOffset];
                        if(switchState) {
                            // Insert row in existing table
                            [self.settingsTableView insertRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        } else {
                            // Remove row in existing table
                            [self.settingsTableView deleteRowsAtIndexPaths:@[rowAtIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        
                        // Notify palette change
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        [appDelegate screenBrightnessChanged:nil];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Switch at Brightness ?
                {
                    CGFloat currentBrightness = [[UIScreen mainScreen] brightness] * 100;
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderPalette"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_brightness", @"Brightness");
                    cell.slider.minimumValue = 0;
                    cell.slider.maximumValue = 100;
                    cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentBrightness)];
                    cell.sliderCountSuffix = @"";
                    cell.incrementSliderBy = 1;
                    cell.sliderValue = [Model sharedInstance].switchPaletteThreshold;
                    [cell.slider addTarget:self action:@selector(updatePaletteBrightnessThreshold:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

#pragma mark Cache Settings
        case SettingsSectionCache:       // Cache Settings
        {
            switch(indexPath.row)
            {
                case 0:     // Download all Albums at Start
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switchCell"];
                    if(!cell)
                    {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_loadAllCategories>320px", @"Download all Albums at Start (uncheck if troubles)");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_loadAllCategories", @"Download all Albums at Start");
                    }
                    [cell.cellSwitch setOn:[Model sharedInstance].loadAllCategoryInfo];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        if(![Model sharedInstance].loadAllCategoryInfo && switchState)
                        {
//                            NSLog(@"settingsResetCa => getAlbumListForCategory(%ld,NO,YES)", (long)0);
                            [AlbumService getAlbumListForCategory:0
                                                       usingCache:NO
                                                  inRecursiveMode:YES
                                                     OnCompletion:nil onFailure:nil];
                        }
                        
                        [Model sharedInstance].loadAllCategoryInfo = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Disk
                {
                    NSInteger currentDiskSize = [[NSURLCache sharedURLCache] currentDiskUsage];
                    float currentDiskSizeInMB = currentDiskSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsDisk"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_cacheDisk", @"Disk");
                    cell.slider.minimumValue = 16;
                    cell.slider.maximumValue = 2048;
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentDiskSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentDiskSizeInMB)];
                    }
                    cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
                    cell.incrementSliderBy = 16;
                    cell.sliderValue = [Model sharedInstance].diskCache;
                    [cell.slider addTarget:self action:@selector(updateDiskCacheSize:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Memory
                {
                    NSInteger currentMemSize = [[NSURLCache sharedURLCache] currentMemoryUsage];
                    float currentMemSizeInMB = currentMemSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsMem"];
                    if(!cell)
                    {
                        cell = [SliderTableViewCell new];
                    }
                    cell.sliderName.text = NSLocalizedString(@"settings_cacheMemory", @"Memory");
                    cell.slider.minimumValue = 16;
                    cell.slider.maximumValue = 512;
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhone 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentMemSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentMemSizeInMB)];
                    }
                    cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
                    cell.incrementSliderBy = 16;
                    cell.sliderValue = [Model sharedInstance].memoryCache;
                    [cell.slider addTarget:self action:@selector(updateMemoryCacheSize:) forControlEvents:UIControlEventValueChanged];
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }

        case SettingsSectionClear:       // Cache Settings
        {
            switch(indexPath.row)
            {
                case 0:     // Clear
                {
                    ButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clearCache"];
                    if(!cell)
                    {
                        cell = [ButtonTableViewCell new];
                    }

                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
                        cell.buttonText = NSLocalizedString(@"settings_cacheClearAll", @"Clear image caches");
                    } else {
                        cell.buttonText = NSLocalizedString(@"settings_cacheClear", @"Clear caches");
                    }
                    
                    tableViewCell = cell;
                    break;
                }
            }
            break;
        }
            
#pragma mark Information
        case SettingsSectionAbout:      // Information
		{
            switch(indexPath.row)
            {
                case 0:     // @piwigo
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"twitter"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_twitter", @"@piwigo");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    //                    if ([Model sharedInstance].isAppLanguageRTL) {
                    //                        cell.rightText = @"<";
                    //                    } else {
                    //                        cell.rightText = @">";
                    //                    }
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Contact Us
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contact"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_contactUs", @"iOS@piwigo.org");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    if (![MFMailComposeViewController canSendMail]) {
                        cell.leftLabel.textColor = [UIColor piwigoRightLabelColor];
                    }
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Support Forum
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"support"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_supportForum", @"Support Forum");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }
                    
                    tableViewCell = cell;
                    break;
                }
                case 3:     // Rate Piwigo Mobile
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rate"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"settings_rateInAppStore", @"Rate Piwigo Mobile"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 4:     // Translate Piwigo Mobile
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"translate"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_translateWithCrowdin", @"Translate Piwigo Mobile");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 5:     // Release Notes
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"release"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 6:     // Acknowledgements
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thanks"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
//                    if ([Model sharedInstance].isAppLanguageRTL) {
//                        cell.rightText = @"<";
//                    } else {
//                        cell.rightText = @">";
//                    }

                    tableViewCell = cell;
                    break;
                }
                case 7:     // Privacy Policy
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_privacy", @"Privacy Policy");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    //                    if ([Model sharedInstance].isAppLanguageRTL) {
                    //                        cell.rightText = @"<";
                    //                    } else {
                    //                        cell.rightText = @">";
                    //                    }
                    
                    tableViewCell = cell;
                    break;
                }
            }
		}
	}
	
    tableViewCell.isAccessibilityElement = YES;
	return tableViewCell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    NSInteger section = indexPath.section;
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }
    
    BOOL result = YES;
    switch(section)
    {
#pragma mark Server
        case SettingsSectionServer:         // Piwigo Server
        {
            result = NO;
            break;
        }
        case SettingsSectionLogout:         // Logout Button
        {
            result = YES;
            break;
        }
#pragma mark Albums
        case SettingsSectionAlbums:         // Albums
        {
            switch(indexPath.row)
            {
                case 0:     // Default album
                case 1:     // Default Sort
                case 2:     // Default Thumbnail File
                    result = YES;
                    break;
                case 3:     // Default Thumbnail Size
                case 4:     // Display titles on thumbnails
                    result = NO;
                    break;
            }
            break;
        }
#pragma mark Images
        case SettingsSectionImages:     // Images
        {
            switch(indexPath.row)
            {
                case 0:     // Default Size of Previewed Images
                {
                    result = YES;
                    break;
                }
                case 1:     // Share private Metadata
                {
                    result = NO;
                    break;
                }
            }
            break;
        }
#pragma mark Default Upload Settings
        case SettingsSectionImageUpload:     // Default Upload Settings
        {
            switch(indexPath.row)
            {
                case 0:     // Author Name
                case 2:     // Strip private Metadata
                case 3:     // Resize Before Upload
                case 4:     // Image Size slider or Compress Before Upload switch
                case 5:     // Compress Before Upload switch or Image Quality slider or Delete Image switch
                case 6:     // Image Quality slider or Delete Image switch
                case 7:     // Delete image after upload
                {
                    result = NO;
                    break;
                }
                case 1:     // Privacy Level
                {
                    result = YES;
                    break;
                }
            }
            break;
        }
#pragma mark Colors
        case SettingsSectionColor:      // Colors
        {
            result = NO;
            break;
        }
#pragma mark Cache Settings
        case SettingsSectionCache:       // Cache Settings
        {
            result = NO;
            break;
        }
        case SettingsSectionClear:       // Cache Settings
        {
            result = YES;
            break;
        }
#pragma mark Information
        case SettingsSectionAbout:      // Information
        {
            switch(indexPath.row)
            {
                case 1:     // Contact Us
                {
                    result = [MFMailComposeViewController canSendMail] ? YES : NO;
                    break;
                }
                case 0:     // Twitter
                case 2:     // Support Forum
                case 3:     // Rate Piwigo Mobile
                case 4:     // Translate Piwigo Mobile
                case 5:     // Release Notes
                case 6:     // Acknowledgements
                case 7:     // Privacy Policy
                {
                    result = YES;
                    break;
                }
            }
            break;
        }
    }
    return result;
}

#pragma mark - UITableView - Footer

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // No footer by default (nil => 0 point)
    NSString *footer;
    
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    // Any footer text?
    switch(section)
    {
        case SettingsSectionLogout:
        {
            if (([Model sharedInstance].uploadFileTypes != nil) && ([[Model sharedInstance].uploadFileTypes length] > 0)) {
                footer = [NSString stringWithFormat:@"%@: %@.", NSLocalizedString(@"settingsFooter_formats", @"The server accepts the following file formats"), [[Model sharedInstance].uploadFileTypes stringByReplacingOccurrencesOfString:@"," withString:@", "]];
            }
            break;
        }
        case SettingsSectionAbout:
        {
            if ([self.nberImages length] > 0) {
                footer = [NSString stringWithFormat:@"%@ %@, %@ %@, %@ %@, %@ %@, %@ %@, %@ %@", self.nberImages, NSLocalizedString(@"severalImages", @"Images"), self.nberCategories, NSLocalizedString(@"tabBar_albums", @"Albums"), self.nberTags, NSLocalizedString(@"tags", @"Tags"), self.nberUsers, NSLocalizedString(@"settings_users", @"Users"), self.nberGroups, NSLocalizedString(@"settings_groups", @"Groups"), self.nberComments, NSLocalizedString(@"editImageDetails_comments", @"Comments")];
            }
            break;
        }
    }
    
    // Footer height?
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    
    return ceil(footerRect.size.height + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    // Footer label
    UILabel *footerLabel = [UILabel new];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.font = [UIFont piwigoFontSmall];
    footerLabel.textColor = [UIColor piwigoHeaderColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    footerLabel.numberOfLines = 0;
    footerLabel.adjustsFontSizeToFitWidth = NO;
    footerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    // Footer text
    switch(section)
    {
        case SettingsSectionLogout:
        {
            if (([Model sharedInstance].uploadFileTypes != nil) && ([[Model sharedInstance].uploadFileTypes length] > 0)) {
                footerLabel.text = [NSString stringWithFormat:@"%@: %@.", NSLocalizedString(@"settingsFooter_formats", @"The server accepts the following file formats"), [[Model sharedInstance].uploadFileTypes stringByReplacingOccurrencesOfString:@"," withString:@", "]];
            }
            break;
        }
        case SettingsSectionAbout:
        {
            if ([self.nberImages length] > 0) {
                footerLabel.text = [NSString stringWithFormat:@"%@ %@, %@ %@, %@ %@, %@ %@, %@ %@, %@ %@", self.nberImages, NSLocalizedString(@"severalImages", @"Images"), self.nberCategories, NSLocalizedString(@"tabBar_albums", @"Albums"), self.nberTags, NSLocalizedString(@"tags", @"Tags"), self.nberUsers, NSLocalizedString(@"settings_users", @"Users"), self.nberGroups, NSLocalizedString(@"settings_groups", @"Groups"), self.nberComments, NSLocalizedString(@"editImageDetails_comments", @"Comments")];
            }
            break;
        }
    }
    
    // Footer view
    UIView *footer = [[UIView alloc] init];
    footer.backgroundColor = [UIColor clearColor];
    [footer addSubview:footerLabel];
    [footer addConstraint:[NSLayoutConstraint constraintViewFromTop:footerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[footer]-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    } else {
        [footer addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[footer]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"footer" : footerLabel}]];
    }
    
    return footer;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    NSInteger section = indexPath.section;
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }
    
	switch(section)
	{
		case SettingsSectionServer:         // Piwigo Server
			break;
		case SettingsSectionLogout:         // Logout
			[self logout];
			break;
        case SettingsSectionAlbums:         // Albums
		{
			switch(indexPath.row)
			{
				case 0:                     // Default album
                {
                    DefaultCategoryViewController *categoryVC = [[DefaultCategoryViewController alloc] initWithSelectedCategory:[[CategoriesData sharedInstance] getCategoryById:[Model sharedInstance].defaultCategory]];
                    [self.navigationController pushViewController:categoryVC animated:YES];
                    break;
                   break;
                }
                case 1:                     // Sort method selection
				{
					CategorySortViewController *categoryVC = [CategorySortViewController new];
					categoryVC.currentCategorySortType = [Model sharedInstance].defaultSort;
					categoryVC.sortDelegate = self;
					[self.navigationController pushViewController:categoryVC animated:YES];
					break;
				}
				case 2:                     // Thumbnail file selection
				{
					DefaultThumbnailSizeViewController *defaultThumbnailSizeVC = [DefaultThumbnailSizeViewController new];
					[self.navigationController pushViewController:defaultThumbnailSizeVC animated:YES];
					break;
				}
			}
			break;
		}
        case SettingsSectionImages:         // Images
        {
            switch(indexPath.row)
            {
                case 0:                     // Image file selection
                {
                    DefaultImageSizeViewController *defaultImageSizeVC = [DefaultImageSizeViewController new];
                    [self.navigationController pushViewController:defaultImageSizeVC animated:YES];
                    break;
                }
            }
            break;
        }
		case SettingsSectionImageUpload:     // Default upload Settings
        {
			switch(indexPath.row)
			{
				case 1:                      // Default privacy selection
				{
					SelectPrivacyViewController *selectPrivacy = [SelectPrivacyViewController new];
					selectPrivacy.delegate = self;
					[selectPrivacy setPrivacy:[Model sharedInstance].defaultPrivacyLevel];
					[self.navigationController pushViewController:selectPrivacy animated:YES];
					break;
				}
			}
			break;
        }
        case SettingsSectionClear:          // Cache Clear
        {
            switch(indexPath.row)
            {
                case 0:                      // Clear cache
                {
                    UIAlertController* alert = [UIAlertController
                        alertControllerWithTitle:NSLocalizedString(@"settings_cacheClear", @"Clear Image Cache")
                        message:NSLocalizedString(@"settings_cacheClearMsg", @"Are you sure you want to clear the image cache? This will make albums and images take a while to load again.")
                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction* dismissAction = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                        style:UIAlertActionStyleCancel
                        handler:nil ];
                    
                    UIAlertAction* clearAction = [UIAlertAction
                          actionWithTitle:NSLocalizedString(@"alertClearButton", @"Clear")
                          style:UIAlertActionStyleDestructive
                          handler:^(UIAlertAction * action) {
                              [[NSURLCache sharedURLCache] removeAllCachedResponses];
                              [self.settingsTableView reloadData];
                          }];

                    // Add actions
                    [alert addAction:dismissAction];
                    [alert addAction:clearAction];
                    
                    // Present list of actions
                    [self presentViewController:alert animated:YES completion:nil];
                    break;
                }
            }
            break;
        }
		case SettingsSectionAbout:       // About — Informations
		{
            switch(indexPath.row)
            {
                case 0:     // Open @piwigo on Twitter
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"settings_twitterURL", @"https://twitter.com/piwigo")]];
                    break;
                }
                case 1:     // Prepare draft email
                {
                    if ([MFMailComposeViewController canSendMail]) {
                        MFMailComposeViewController* composeVC = [[MFMailComposeViewController alloc] init];
                        composeVC.mailComposeDelegate = self;
                        
                        // Configure the fields of the interface.
                        [composeVC setToRecipients:@[NSLocalizedStringFromTableInBundle(@"contact_email", @"PrivacyPolicy", [NSBundle mainBundle], @"Contact email")]];
                        
                        // Collect version and build numbers
                        NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                        NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
                        
                        // Compile ticket number from current date
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        [dateFormatter setDateFormat:@"yyyyMMddHHmm"];
                        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[Model sharedInstance].language]];
                        NSDate *date = [NSDate date];
                        NSString *ticketDate = [dateFormatter stringFromDate:date];

                        // Set subject
                        [composeVC setSubject:[NSString stringWithFormat:@"[Ticket#%@]: %@ %@", ticketDate, NSLocalizedString(@"settings_appName", @"Piwigo Mobile"), NSLocalizedString(@"settings_feedback", @"Feedback")]];
                        
                        // Collect system and device data
                        struct utsname systemInfo;
                        uname(&systemInfo);
                        NSString* deviceModel = [self deviceNameFromCode:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding]];
                        NSString *deviceOS = [[UIDevice currentDevice] systemName];
                        NSString *deviceOSversion = [[UIDevice currentDevice] systemVersion];
                        
                        // Set message body
                        [composeVC setMessageBody:[NSString stringWithFormat:@"%@ %@ (%@)\n%@ — %@ %@\n==============>>\n\n", NSLocalizedString(@"settings_appName", @"Piwigo Mobile"), appVersionString, appBuildString, deviceModel, deviceOS, deviceOSversion] isHTML:NO];
                        
                        // Present the view controller modally.
                        [self presentViewController:composeVC animated:YES completion:nil];
                    }
                    break;
                }
                case 2:     // Open Piwigo support forum webpage with default browser
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"settings_pwgForumURL", @"http://piwigo.org/forum")]];
                    break;
                }
                case 3:     // Open Piwigo App Store page for rating
                {
                    // See https://itunes.apple.com/us/app/piwigo/id472225196?ls=1&mt=8
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/piwigo/id472225196?action=write-review"]];
                    break;
                }
                case 4:     // Open Piwigo Crowdin page for translating
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://crowdin.com/project/piwigo-mobile"]];
                    break;
                }
                case 5:     // Open Release Notes page
                {
                    ReleaseNotesViewController *releaseNotesVC = [ReleaseNotesViewController new];
                    [self.navigationController pushViewController:releaseNotesVC animated:YES];
                    break;
                }
                case 6:     // Open Acknowledgements page
                {
                    AboutViewController *aboutVC = [AboutViewController new];
                    [self.navigationController pushViewController:aboutVC animated:YES];
                    break;
                }
                case 7:     // Open Privacy Policy page
                {
                    PrivacyPolicyViewController *aboutVC = [PrivacyPolicyViewController new];
                    [self.navigationController pushViewController:aboutVC animated:YES];
                    break;
                }
            }
		}
	}
}


#pragma mark - Option Methods

-(void)logout
{
	if([Model sharedInstance].username.length > 0)
	{
        // Ask user for confirmation
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:@""
                    message:NSLocalizedString(@"logoutConfirmation_message", @"Are you sure you want to logout?")
                    preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction* cancelAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {}];
        
        UIAlertAction* logoutAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"logoutConfirmation_title", @"Logout")
                    style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction * action) {
                       [SessionService sessionLogoutOnCompletion:^(NSURLSessionTask *task, BOOL sucessfulLogout) {
                           if(sucessfulLogout)
                           {
                               // Session closed
                               [[Model sharedInstance].sessionManager invalidateSessionCancelingTasks:YES];
                               [Model sharedInstance].imageDownloader = nil;
                               [[Model sharedInstance].imagesSessionManager invalidateSessionCancelingTasks:YES];
                               [Model sharedInstance].hadOpenedSession = NO;
                               
                               // Back to default values
                               [Model sharedInstance].defaultCategory = 0;
                               [Model sharedInstance].usesCommunityPluginV29 = NO;
                               [Model sharedInstance].hasAdminRights = NO;
                               [[Model sharedInstance] saveToDisk];
                               
                               // Erase cache
                               [ClearCache clearAllCache];
                               AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                               [appDelegate loadLoginView];
                           }
                           else
                           {
                               // Failed, retry ?
                               UIAlertController* alert = [UIAlertController
                                       alertControllerWithTitle:NSLocalizedString(@"logoutFail_title", @"Logout Failed")
                                       message:NSLocalizedString(@"logoutFail_message", @"Failed to logout\nTry again?")
                                       preferredStyle:UIAlertControllerStyleAlert];
                               
                               UIAlertAction* dismissAction = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {}];
                           
                               UIAlertAction* retryAction = [UIAlertAction
                                           actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                           style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * action) {
                                               [self logout];
                                           }];
                               
                               // Add actions
                               [alert addAction:dismissAction];
                               [alert addAction:retryAction];
                               [self presentViewController:alert animated:YES completion:nil];
                           }
                       } onFailure:^(NSURLSessionTask *task, NSError *error) {
                           // Error message already presented
                       }];
                    }];
        
        // Add actions
        [alert addAction:cancelAction];
        [alert addAction:logoutAction];
        
        // Determine position of cell in table view
        NSIndexPath *rowAtIndexPath = [NSIndexPath indexPathForRow:0 inSection:SettingsSectionLogout];
        CGRect rectOfCellInTableView = [self.settingsTableView rectForRowAtIndexPath:rowAtIndexPath];
        
        // Present list of actions
        alert.popoverPresentationController.sourceView = self.settingsTableView;
        alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
        alert.popoverPresentationController.sourceRect = rectOfCellInTableView;
        [self presentViewController:alert animated:YES completion:nil];
	}
	else
	{
		[ClearCache clearAllCache];
		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate loadLoginView];
	}
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    // Check the result or perform other tasks.
    
    // Dismiss the mail compose view controller.
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)deviceNameFromCode:(NSString *)deviceCode
{
    // iPhone
    if ([deviceCode isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([deviceCode isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([deviceCode isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([deviceCode isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([deviceCode isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([deviceCode isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([deviceCode isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([deviceCode isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM)";
    if ([deviceCode isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM)";
    if ([deviceCode isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPhone7,1"])    return @"iPhone 6";
    if ([deviceCode isEqualToString:@"iPhone7,2"])    return @"iPhone 6 Plus";
    if ([deviceCode isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([deviceCode isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([deviceCode isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    if ([deviceCode isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([deviceCode isEqualToString:@"iPhone9,2"])    return @"iPhone 7 Plus";
    if ([deviceCode isEqualToString:@"iPhone9,3"])    return @"iPhone 7";
    if ([deviceCode isEqualToString:@"iPhone9,4"])    return @"iPhone 7 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,1"])   return @"iPhone 8";
    if ([deviceCode isEqualToString:@"iPhone10,2"])   return @"iPhone 8 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,3"])   return @"iPhone X";
    if ([deviceCode isEqualToString:@"iPhone10,4"])   return @"iPhone 8";
    if ([deviceCode isEqualToString:@"iPhone10,5"])   return @"iPhone 8 Plus";
    if ([deviceCode isEqualToString:@"iPhone10,6"])   return @"iPhone X";
    if ([deviceCode isEqualToString:@"iPhone11,2"])   return @"iPhone Xs";
    if ([deviceCode isEqualToString:@"iPhone11,4"])   return @"iPhone Xs Max";
    if ([deviceCode isEqualToString:@"iPhone11,6"])   return @"iPhone Xs Max";
    if ([deviceCode isEqualToString:@"iPhone11,8"])   return @"iPhone Xr";

    // iPad
    if ([deviceCode isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([deviceCode isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([deviceCode isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([deviceCode isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad3,2"])      return @"iPad 3 (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPad3,3"])      return @"iPad 3 (GSM)";
    if ([deviceCode isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([deviceCode isEqualToString:@"iPad3,6"])      return @"iPad 4 (GSM+CDMA)";
    
    // iPad Air
    if ([deviceCode isEqualToString:@"iPad4,1"])      return @"iPad Air (WiFi)";
    if ([deviceCode isEqualToString:@"iPad4,2"])      return @"iPad Air (Cellular)";
    if ([deviceCode isEqualToString:@"iPad5,3"])      return @"iPad Air 2 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad5,4"])      return @"iPad Air 2 (Cellular)";

    // iPad Pro
    if ([deviceCode isEqualToString:@"iPad6,3"])      return @"iPad Pro 9.7 inch (WiFi)";
    if ([deviceCode isEqualToString:@"iPad6,4"])      return @"iPad Pro 9.7 inch (Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,3"])      return @"iPad Pro 10.5 inch (WiFi)";
    if ([deviceCode isEqualToString:@"iPad7,4"])      return @"iPad Pro 10.5 inch (Cellular)";
    if ([deviceCode isEqualToString:@"iPad6,7"])      return @"iPad Pro 12.9 inch (WiFi)";
    if ([deviceCode isEqualToString:@"iPad6,8"])      return @"iPad Pro 12.9 inch (Cellular)";
    if ([deviceCode isEqualToString:@"iPad7,1"])      return @"iPad Pro 2 12.9 inch (WiFi)";
    if ([deviceCode isEqualToString:@"iPad7,2"])      return @"iPad Pro 2 12.9 inch (Cellular)";

    // iPad mini
    if ([deviceCode isEqualToString:@"iPad2,5"])      return @"iPad Mini (WiFi)";
    if ([deviceCode isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([deviceCode isEqualToString:@"iPad2,7"])      return @"iPad Mini (GSM+CDMA)";
    if ([deviceCode isEqualToString:@"iPad4,4"])      return @"iPad mini 2G (WiFi)";
    if ([deviceCode isEqualToString:@"iPad4,5"])      return @"iPad mini 2G (Cellular)";
    if ([deviceCode isEqualToString:@"iPad5,1"])      return @"iPad mini 4 (WiFi)";
    if ([deviceCode isEqualToString:@"iPad5,2"])      return @"iPad mini 4 (Cellular)";

    // iPod
    if ([deviceCode isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([deviceCode isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([deviceCode isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([deviceCode isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([deviceCode isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([deviceCode isEqualToString:@"iPod7,1"])      return @"iPod Touch 6G";
    
    // Simulator
    if ([deviceCode isEqualToString:@"i386"])         return @"Simulator";
    if ([deviceCode isEqualToString:@"x86_64"])       return @"Simulator";
    
    return deviceCode;
}

#pragma mark - UITextFieldDelegate Methods

-(void)keyboardWillChange:(NSNotification*)notification
{
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    self.tableViewBottomConstraint.constant = -keyboardSize.height;
}

-(void)keyboardWillDismiss:(NSNotification*)notification
{
    self.tableViewBottomConstraint.constant = 0;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.settingsTableView endEditing:YES];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    switch(textField.tag)
    {
        case kImageUploadSettingAuthor:
        {
            [Model sharedInstance].defaultAuthor = textField.text;
            [[Model sharedInstance] saveToDisk];
            break;
        }
    }
}


#pragma mark - SelectedPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	[Model sharedInstance].defaultPrivacyLevel = privacy;
	[[Model sharedInstance] saveToDisk];
}


#pragma mark - CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	[Model sharedInstance].defaultSort = sortType;
	[[Model sharedInstance] saveToDisk];
	[self.settingsTableView reloadData];
}


#pragma mark - Sliders changed value Methods

- (IBAction)updateThumbnailSize:(id)sender
{
    SliderTableViewCell *thumbnailsSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:SettingsSectionAlbums]];
    NSInteger minNberOfImages = [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:kThumbnailFileSize];
    [Model sharedInstance].thumbnailsPerRowInPortrait = 2 * minNberOfImages - ([thumbnailsSizeCell getCurrentSliderValue] - 1);
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateImageSize:(id)sender
{
    SliderTableViewCell *photoSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:SettingsSectionImageUpload]];
    [Model sharedInstance].photoResize = [photoSizeCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateImageQuality:(id)sender
{
    NSInteger row = 5 + ([Model sharedInstance].resizeImageOnUpload ? 1 : 0);
    SliderTableViewCell *photoQualityCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionImageUpload]];
    [Model sharedInstance].photoQuality = [photoQualityCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updatePaletteBrightnessThreshold:(id)sender
{
    SliderTableViewCell *sliderSettingPalette = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:SettingsSectionColor]];
    [Model sharedInstance].switchPaletteThreshold = [sliderSettingPalette getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];

    // Update palette if needed
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate screenBrightnessChanged:nil];
}

- (IBAction)updateDiskCacheSize:(id)sender
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    NSInteger section = SettingsSectionCache;
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }

    SliderTableViewCell *sliderSettingsDisk = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:section]];
    [Model sharedInstance].diskCache = [sliderSettingsDisk getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
    
    [NSURLCache sharedURLCache].diskCapacity = [Model sharedInstance].diskCache * 1024*1024;
}

- (IBAction)updateMemoryCacheSize:(id)sender
{
    // User can upload images/videos if he/she is logged in and has:
    // — admin rights
    // — upload access to some categories with Community
    NSInteger section = SettingsSectionCache;
    if (!([Model sharedInstance].hasAdminRights || [Model sharedInstance].usesCommunityPluginV29) ||
        ![Model sharedInstance].hadOpenedSession)
    {
        // Bypass the Upload section
        if (section > SettingsSectionImages) section++;
    }
    
    SliderTableViewCell *sliderSettingsMem = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:section]];
    [Model sharedInstance].memoryCache = [sliderSettingsMem getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
    
    [NSURLCache sharedURLCache].memoryCapacity = [Model sharedInstance].memoryCache * 1024*1024;
}

#pragma mark - Get Server Infos

-(void)getInfos
{
    [AlbumService getInfosOnCompletion:^(NSURLSessionTask *task, NSArray *infos) {
        
        // Check returned infos
        if (infos == nil) {
            self.nberCategories = @"";
            self.nberImages = @"";
            return;
        }
        
        // Update infos
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setPositiveFormat:@"#,##0"];
        for(NSDictionary *info in infos)
        {
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_elements"]) {
                self.nberImages = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_categories"]) {
                self.nberCategories = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_tags"]) {
                self.nberTags = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_users"]) {
                self.nberUsers = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_groups"]) {
                self.nberGroups = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
            if ([[info objectForKey:@"name"] isEqualToString:@"nb_comments"]) {
                self.nberComments = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[info objectForKey:@"value"] integerValue]]];
            }
        }
        
        // Refresh table with infos
        [self.settingsTableView reloadData];
    }
                             onFailure:^(NSURLSessionTask *task, NSError *error) {
                                 self.nberCategories = @"";
                                 self.nberImages = @"";
                             }];
}
@end
