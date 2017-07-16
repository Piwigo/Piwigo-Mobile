//
//  SettingsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SettingsViewController.h"
#import "SessionService.h"
#import "AppDelegate.h"
#import "Model.h"
#import "SelectPrivacyViewController.h"
#import "TextFieldTableViewCell.h"
#import "ButtonTableViewCell.h"
#import "LabelTableViewCell.h"
#import "AboutViewController.h"
#import "ClearCache.h"
#import "SliderTableViewCell.h"
#import "EditPopDownView.h"
#import "SwitchTableViewCell.h"
#import "AlbumService.h"
#import "CategorySortViewController.h"
#import "PiwigoImageData.h"
#import "DefaultImageSizeViewController.h"
#import "DefaultThumbnailSizeViewController.h"
#import "iRate.h"
#import "ReleaseNotesViewController.h"

typedef enum {
	SettingSectionServer,
	SettingSectionLogout,
	SettingSectionGeneral,
	SettingSectionImageUpload,
	SettingSectionCache,
	SettingSectionAbout,
	SettingSectionCount
} SettingSection;

typedef enum {
	kImageUploadSettingAuthor
} kImageUploadSetting;

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SelectPrivacyDelegate, CategorySortDelegate>

@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, strong) NSArray *rowsInSection;
@property (nonatomic, strong) NSArray *headerHeights;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewBottomConstraint;
@property (nonatomic, strong) UIView *darkenView;
@property (nonatomic, strong) EditPopDownView *currentPopDown;

@end

@implementation SettingsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		
		self.rowsInSection = @[
							   @2,
							   @1,
							   @5,
							   @6,
							   @2,
							   @4
							   ];
		self.headerHeights = @[
							   @40.0,
							   @0.01,
							   @30.0,
							   @30.0,
							   @30.0,
							   @30.0
							   ];
		
		self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.settingsTableView.backgroundColor = [UIColor piwigoGray];
		self.settingsTableView.delegate = self;
		self.settingsTableView.dataSource = self;
		[self.view addSubview:self.settingsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.settingsTableView]];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.settingsTableView amount:0]];
		self.tableViewBottomConstraint = [NSLayoutConstraint constraintViewFromBottom:self.settingsTableView amount:0];
		[self.view addConstraint:self.tableViewBottomConstraint];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];
		
		self.darkenView = [UIView new];
		self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
		self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.darkenView.hidden = YES;
		[self.darkenView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedDarkenView)]];
		[self.view addSubview:self.darkenView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.darkenView]];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self.settingsTableView reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	
	[super viewWillDisappear:animated];
}

-(void)keyboardWillChange:(NSNotification*)notification
{
	CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
	
	self.tableViewBottomConstraint.constant = -keyboardRect.size.height;
}

-(void)keyboardWillDismiss:(NSNotification*)notification
{
	self.tableViewBottomConstraint.constant = 0;
}

-(void)tappedDarkenView
{
	self.darkenView.hidden = YES;
	if(self.currentPopDown)
	{
		[self.currentPopDown hide];
	}
}

#pragma mark -- UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return SettingSectionCount;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == SettingSectionImageUpload) {
		if([Model sharedInstance].resizeImageOnUpload) {
			return [self.rowsInSection[section] integerValue];
		} else {
			return [self.rowsInSection[section] integerValue] - 2;
		}
	}
	return [self.rowsInSection[section] integerValue];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];
	switch(indexPath.section)
	{
		case SettingSectionServer:      // Piwigo Server
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
					cell.rightText = [Model sharedInstance].serverName;
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
		case SettingSectionLogout:      // Logout Button
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
		case SettingSectionGeneral:     // General Settings
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
							[AlbumService getAlbumListForCategory:-1 OnCompletion:nil onFailure:nil];
						}
						
						[Model sharedInstance].loadAllCategoryInfo = switchState;
						[[Model sharedInstance] saveToDisk];
					};
					
					tableViewCell = cell;
					break;
				}
				case 1:     // Default Sort
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sort"];
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
					cell.rightText = [[CategorySortViewController getNameForCategorySortType:[Model sharedInstance].defaultSort] stringByAppendingString:@"   >"];

                    tableViewCell = cell;
					break;
				}
				case 2:     // Default Size of Thumbnails
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultThumbnailSize"];
					if(!cell) {
						cell = [LabelTableViewCell new];
					}
					
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailSize>414px", @"Default Size of Thumbnails");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultThumbnailSize>320px", @"Thumbnails Size");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultThumbnailSize", @"Thumbnails");
                    }
					cell.rightText = [[PiwigoImageData nameForThumbnailSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize] stringByAppendingString:@"   >"];
					
					tableViewCell = cell;
					break;
				}
                case 3:     // Display titles on thumbnails
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"titles"];
                    if(!cell)
                    {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    cell.leftLabel.text = NSLocalizedString(@"settings_displayTitles", @"Display Titles on Thumbnails");
                    [cell.cellSwitch setOn:[Model sharedInstance].displayImageTitles];
                    cell.cellSwitchBlock = ^(BOOL switchState) {
                        [Model sharedInstance].displayImageTitles = switchState;
                        [[Model sharedInstance] saveToDisk];
                    };
                    
                    tableViewCell = cell;
                    break;
                }
                case 4:     // Default Size of Images
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"defaultImageSize"];
                    if(!cell) {
                        cell = [LabelTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSize>414px", @"Default Size of Images");
                    } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
                        cell.leftText = NSLocalizedString(@"defaultImageSize>320px", @"Images Size");
                    } else {
                        cell.leftText = NSLocalizedString(@"defaultImageSize", @"Images");
                    }
                    cell.rightText = [[PiwigoImageData nameForImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize] stringByAppendingString:@"   >"];
                    
                    tableViewCell = cell;
                    break;
                }
			}
			break;
		}
		case SettingSectionImageUpload:     // Default Upload Settings
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
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy>320px", @"Who Can See the Media?");
                    } else {
                        cell.leftText = NSLocalizedString(@"settings_defaultPrivacy", @"Privacy");
                    }
					cell.rightText = [[[Model sharedInstance] getNameForPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel] stringByAppendingString:@"   >"];
					
					tableViewCell = cell;
					break;
				}
                case 2:     // Strip GPS Metadata
                {
                    SwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"gps"];
                    if(!cell) {
                        cell = [SwitchTableViewCell new];
                    }
                    
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6,7 screen width
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata>375px", @"Strip GPS Metadata Before Upload");
                    } else {
                        cell.leftLabel.text = NSLocalizedString(@"settings_stripGPSdata", @"Strip GPS Metadata");
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
						[Model sharedInstance].resizeImageOnUpload = switchState;
						if(![Model sharedInstance].resizeImageOnUpload) {
							[Model sharedInstance].photoQuality = 95;
                            [Model sharedInstance].photoResize = 100;
						}
						[[Model sharedInstance] saveToDisk];
						[self.settingsTableView reloadSections:[NSIndexSet indexSetWithIndex:SettingSectionImageUpload] withRowAnimation:UITableViewRowAnimationAutomatic];
					};
					
					tableViewCell = cell;
					break;
				}
				case 4:     // Image Quality
				{
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
					cell.incrementSliderBy = 1;
					cell.sliderValue = [Model sharedInstance].photoQuality;
                    [cell.slider addTarget:self action:@selector(updateImageQuality:) forControlEvents:UIControlEventValueChanged];
					
					tableViewCell = cell;
					break;
				}
				case 5:     // Image Size
				{
					SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoSize"];
					if(!cell)
					{
						cell = [SliderTableViewCell new];
					}
                    cell.sliderName.text = NSLocalizedString(@"settings_photoSize", @"> Size");
					cell.slider.minimumValue = 1;
					cell.slider.maximumValue = 100;
                    cell.sliderCountPrefix = @"";
					cell.sliderCountSuffix = @"%";
					cell.incrementSliderBy = 1;
					cell.sliderValue = [Model sharedInstance].photoResize;
                    [cell.slider addTarget:self action:@selector(updateImageSize:) forControlEvents:UIControlEventValueChanged];
					
					tableViewCell = cell;
					break;
				}
			}
			break;
		}
		case SettingSectionCache:       // Cache Settings
		{
			switch(indexPath.row)
			{
				case 0:     // Disk
				{
                    NSInteger currentDiskSize = [[NSURLCache sharedURLCache] currentDiskUsage];
                    float currentDiskSizeInMB = currentDiskSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsDisk"];
					if(!cell)
					{
						cell = [SliderTableViewCell new];
					}
					cell.sliderName.text = NSLocalizedString(@"settings_cacheDisk", @"Disk");
                    cell.slider.minimumValue = 10;
                    cell.slider.maximumValue = 200;

                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentDiskSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentDiskSizeInMB)];
                    }
					cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
					cell.incrementSliderBy = 10;
					cell.sliderValue = [Model sharedInstance].diskCache;
                    [cell.slider addTarget:self action:@selector(updateDiskCacheSize:) forControlEvents:UIControlEventValueChanged];
					
					tableViewCell = cell;
					break;
				}
				case 1:     // Memory
				{
                    NSInteger currentMemSize = [[NSURLCache sharedURLCache] currentMemoryUsage];
                    float currentMemSizeInMB = currentMemSize / (1024.0f * 1024.0f);
                    SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsMem"];
					if(!cell)
					{
						cell = [SliderTableViewCell new];
					}
					cell.sliderName.text = NSLocalizedString(@"settings_cacheMemory", @"Memory");
                    cell.slider.minimumValue = 10;
                    cell.slider.maximumValue = 200;

                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhone 6,7 screen width
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%.1f/", currentMemSizeInMB];
                    } else {
                        cell.sliderCountPrefix = [NSString stringWithFormat:@"%ld/", lroundf(currentMemSizeInMB)];
                    }
					cell.sliderCountSuffix = NSLocalizedString(@"settings_cacheMegabytes", @"MB");
					cell.incrementSliderBy = 10;
					cell.sliderValue = [Model sharedInstance].memoryCache;
                    [cell.slider addTarget:self action:@selector(updateMemoryCacheSize:) forControlEvents:UIControlEventValueChanged];
					
					tableViewCell = cell;
					break;
				}
			}
			break;
		}
		case SettingSectionAbout:       // Information
		{
            switch(indexPath.row)
            {
                case 0:     // Support Forum
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"support"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_supportForum", @"Support Forum");
                    cell.leftLabel.textAlignment = NSTextAlignmentLeft;
                    cell.leftLabelWidth = 220;
                    cell.rightText = @">";
                    
                    tableViewCell = cell;
                    break;
                }
                case 1:     // Rating page
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rate"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"settings_rateInAppStore", @"Rate Piwigo Mobile"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
                    cell.leftLabel.textAlignment = NSTextAlignmentLeft;
                    cell.leftLabelWidth = 220;
                    cell.rightText = @">";
                    
                    tableViewCell = cell;
                    break;
                }
                case 2:     // Release Notes
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"release"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
                    cell.leftLabel.textAlignment = NSTextAlignmentLeft;
                    cell.leftLabelWidth = 220;
                    cell.rightText = @">";
                    
                    tableViewCell = cell;
                    break;
                }
                case 3:     // Acknowledgements
                {
                    LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thanks"];
                    if(!cell)
                    {
                        cell = [LabelTableViewCell new];
                    }
                    
                    cell.leftText = NSLocalizedString(@"settings_acknowledgements", @"Acknowledgements");
                    cell.leftLabel.textAlignment = NSTextAlignmentLeft;
                    cell.leftLabelWidth = 220;
                    cell.rightText = @">";
                    
                    tableViewCell = cell;
                    break;
                }
            }
		}
	}
	
	return tableViewCell;
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.settingsTableView reloadData];
    } completion:nil];
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return [self.headerHeights[section] floatValue];
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, [self.headerHeights[section] floatValue])];
	header.backgroundColor = [UIColor clearColor];
	
	CGRect labelFrame = header.frame;
	labelFrame.origin.x += 15;
	
	UILabel *headerLabel = [[UILabel alloc] initWithFrame:labelFrame];
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor piwigoWhiteCream];
	[header addSubview:headerLabel];
	
    switch(section)
	{
		case SettingSectionServer:
			headerLabel.text = NSLocalizedString(@"settingsHeader_server", @"Piwigo Server");
			break;
		case SettingSectionGeneral:
			headerLabel.text = NSLocalizedString(@"settingsHeader_general", @"General Settings");
			break;
		case SettingSectionImageUpload:
			headerLabel.text = NSLocalizedString(@"settingsHeader_upload", @"Default Upload Settings");
			break;
		case SettingSectionCache:
            headerLabel.text = NSLocalizedString(@"settingsHeader_cache", @"Cache Settings (Used/Total)");
			break;
		case SettingSectionAbout:
			headerLabel.text = NSLocalizedString(@"settingsHeader_about", @"Information");
			break;
	}
	
	return header;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	switch(indexPath.section)
	{
		case SettingSectionServer:      // Piwigo Server
			break;
		case SettingSectionLogout:      // Logout
			[self logout];
			break;
		case SettingSectionGeneral:     // General Settings
		{
			switch(indexPath.row)
			{
				case 1:
				{
					CategorySortViewController *categoryVC = [CategorySortViewController new];
					categoryVC.currentCategorySortType = [Model sharedInstance].defaultSort;
					categoryVC.sortDelegate = self;
					[self.navigationController pushViewController:categoryVC animated:YES];
					break;
				}
				case 2:
				{
					DefaultThumbnailSizeViewController *defaultThumbnailSizeVC = [DefaultThumbnailSizeViewController new];
					[self.navigationController pushViewController:defaultThumbnailSizeVC animated:YES];
					break;
				}
                case 4:
                {
                    DefaultImageSizeViewController *defaultImageSizeVC = [DefaultImageSizeViewController new];
                    [self.navigationController pushViewController:defaultImageSizeVC animated:YES];
                    break;
                }
			}
			break;
		}
		case SettingSectionImageUpload:     // Default Upload Settings
			switch(indexPath.row)
			{
				case 1:     // Privacy
				{
					SelectPrivacyViewController *selectPrivacy = [SelectPrivacyViewController new];
					selectPrivacy.delegate = self;
					[selectPrivacy setPrivacy:[Model sharedInstance].defaultPrivacyLevel];
					[self.navigationController pushViewController:selectPrivacy animated:YES];
					break;
				}
				case 4:     // Image Quality
				{
					if(self.currentPopDown)
					{
						[self.currentPopDown removeFromSuperview];
					}
					self.currentPopDown = [[EditPopDownView alloc] initWithPlaceHolderText:NSLocalizedString(@"settings_placeholderQuality", @"Enter an Image Quality")];
					self.darkenView.hidden = NO;
					[self.currentPopDown presentFromView:self.view onCompletion:^(NSString *textEntered) {
						self.darkenView.hidden = YES;
						if(textEntered.length > 0)
						{
							SliderTableViewCell *photoQualityCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:SettingSectionImageUpload]];
							
							NSInteger valueEntered = [textEntered integerValue];
							if(valueEntered < 50) valueEntered = 50;
							else if(valueEntered > 98) valueEntered = 98;
							
							photoQualityCell.sliderValue = valueEntered;
							if(!photoQualityCell)
							{
								[Model sharedInstance].photoQuality = valueEntered;
								[[Model sharedInstance] saveToDisk];
							}
						}
					}];
					break;
				}
				case 5:     // Image Size
				{
					if(self.currentPopDown)
					{
						[self.currentPopDown removeFromSuperview];
					}
					self.currentPopDown = [[EditPopDownView alloc] initWithPlaceHolderText:NSLocalizedString(@"settings_placeholderSize", @"Enter a Photo Size from 1 - 100")];
					self.darkenView.hidden = NO;
					[self.currentPopDown presentFromView:self.view onCompletion:^(NSString *textEntered) {
						self.darkenView.hidden = YES;
						if(textEntered.length > 0)
						{
							SliderTableViewCell *photoSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:5 inSection:SettingSectionImageUpload]];
							photoSizeCell.sliderValue = [textEntered integerValue];
							if(!photoSizeCell)
							{
								[Model sharedInstance].photoResize = [textEntered integerValue];
								[[Model sharedInstance] saveToDisk];
							}
						}
					}];
					break;
				}
			}
			
			break;
		case SettingSectionCache:       // Cache Settings
		{
			switch(indexPath.row)
			{
				case 0:
				{
					if(self.currentPopDown)
					{
						[self.currentPopDown removeFromSuperview];
					}
					self.currentPopDown = [[EditPopDownView alloc] initWithPlaceHolderText:NSLocalizedString(@"settings_placeholderDisk", @"Enter a Disk Cache from 10 - 200")];
					self.darkenView.hidden = NO;
					[self.currentPopDown presentFromView:self.view onCompletion:^(NSString *textEntered) {
						self.darkenView.hidden = YES;
						if(textEntered.length > 0)
						{
							SliderTableViewCell *diskCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingSectionCache]];
							diskCell.sliderValue = [textEntered integerValue];
							if(!diskCell)
							{
								[Model sharedInstance].diskCache = [textEntered integerValue];
								[[Model sharedInstance] saveToDisk];
							}
						}
					}];
					break;
				}
				case 1:
				{
					if(self.currentPopDown)
					{
						[self.currentPopDown removeFromSuperview];
					}
					self.currentPopDown = [[EditPopDownView alloc] initWithPlaceHolderText:NSLocalizedString(@"settings_placeholderMemory", @"Enter a Memory Cache from 10 - 200")];
					self.darkenView.hidden = NO;
					[self.currentPopDown presentFromView:self.view onCompletion:^(NSString *textEntered) {
						self.darkenView.hidden = YES;
						if(textEntered.length > 0)
						{
							SliderTableViewCell *memoryCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:SettingSectionCache]];
							memoryCell.sliderValue = [textEntered integerValue];
							if(!memoryCell)
							{
								[Model sharedInstance].memoryCache = [textEntered integerValue];
								[[Model sharedInstance] saveToDisk];
							}
						}
					}];
					break;
				}
			}
//			if(indexPath.row == 2)
//			{
//				[UIAlertView showWithTitle:@"DELETE IMAGE CACHE"
//								   message:@"Are you sure you want to clear your image cache?\nThis will make images take a while to load again."
//						 cancelButtonTitle:@"No"
//						 otherButtonTitles:@[@"Yes"]
//								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//									  if(buttonIndex == 1)
//									  {
//										  // set it to 0 to clear it
//										  NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0
//																							   diskCapacity:0
//																								   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//										  
//										  // set it back
//										  URLCache = [[NSURLCache alloc] initWithMemoryCapacity:500 * 1024 * 1024
//																				   diskCapacity:500 * 1024 * 1024
//																					   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//									  }
//								  }];
//			}
			break;
		}
		case SettingSectionAbout:       // About — Informations
		{
            switch(indexPath.row)
            {
                case 0:     // Open Piwigo support forum webpage with default browser
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://piwigo.org/forum"]];
                    break;
                }
                case 1:     // Open Piwigo App Store page for rating
                {
                    [[iRate sharedInstance] openRatingsPageInAppStore];
                    break;
                }
                case 2:     // Open Release Notes page
                {
                    ReleaseNotesViewController *releaseNotesVC = [ReleaseNotesViewController new];
                    [self.navigationController pushViewController:releaseNotesVC animated:YES];
                    break;
                }
                case 3:     // Open Acknowledgements page
                {
                    AboutViewController *aboutVC = [AboutViewController new];
                    [self.navigationController pushViewController:aboutVC animated:YES];
                    break;
                }
            }
		}
	}
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	[self.view endEditing:YES];
	if(self.currentPopDown)
	{
		[self.currentPopDown hide];
	}
}

#pragma mark -- Option Methods

-(void)logout
{
	if([Model sharedInstance].username.length > 0)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"logoutConfirmation_title", @"Logout")
						   message:NSLocalizedString(@"logoutConfirmation_message", @"Are you sure you want to logout?")
				 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
				 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
						  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
							  if(buttonIndex == 1)
							  {
								  [SessionService sessionLogoutOnCompletion:^(NSURLSessionTask *task, BOOL sucessfulLogout) {
									  if(sucessfulLogout)
									  {
										  [Model sharedInstance].hadOpenedSession = NO;
                                          [ClearCache clearAllCache];
										  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
										  [appDelegate loadLoginView];
									  }
									  else
									  {
										  [UIAlertView showWithTitle:NSLocalizedString(@"logoutFail_title", @"Logout Failed")
															 message:NSLocalizedString(@"logoutFail_message", @"Failed to logout\nTry again?")
												   cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
												   otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
															tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
																if(buttonIndex == 1)
																{
																	[self logout];
																}
															}];
									  }
								  } onFailure:^(NSURLSessionTask *task, NSError *error) {
									  
								  }];
							  }
						  }];
	}
	else
	{
		[ClearCache clearAllCache];
		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate loadLoginView];
	}
}

#pragma mark UITextFieldDelegate Methods

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

#pragma mark SelectedPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	[Model sharedInstance].defaultPrivacyLevel = privacy;
	[[Model sharedInstance] saveToDisk];
}

#pragma mark CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	[Model sharedInstance].defaultSort = sortType;
	[[Model sharedInstance] saveToDisk];
	[self.settingsTableView reloadData];
}

#pragma mark Sliders changed value Methods

- (IBAction)updateImageQuality:(id)sender
{
    SliderTableViewCell *photoQualityCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:SettingSectionImageUpload]];
    [Model sharedInstance].photoQuality = [photoQualityCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateImageSize:(id)sender
{
    SliderTableViewCell *photoSizeCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:5 inSection:SettingSectionImageUpload]];
    [Model sharedInstance].photoResize = [photoSizeCell getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
}

- (IBAction)updateDiskCacheSize:(id)sender
{
    SliderTableViewCell *sliderSettingsDisk = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingSectionCache]];
    [Model sharedInstance].diskCache = [sliderSettingsDisk getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];

    [NSURLCache sharedURLCache].diskCapacity = [Model sharedInstance].diskCache * 1024*1024;
}

- (IBAction)updateMemoryCacheSize:(id)sender
{
    SliderTableViewCell *sliderSettingsMem = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:SettingSectionCache]];
    [Model sharedInstance].memoryCache = [sliderSettingsMem getCurrentSliderValue];
    [[Model sharedInstance] saveToDisk];
    
    [NSURLCache sharedURLCache].memoryCapacity = [Model sharedInstance].memoryCache * 1024*1024;
}

@end


