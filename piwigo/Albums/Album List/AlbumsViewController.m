//
//  AlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumsViewController.h"

#import "PiwigoImageData.h"
#import "AlbumTableViewCell.h"
#import "AlbumService.h"
#import "AlbumImagesViewController.h"
#import "CategoriesData.h"
#import "Model.h"
#import "iRate.h"
#import "MBProgressHUD.h"

@interface AlbumsViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, AlbumTableViewCellDelegate>

@property (nonatomic, strong) UITableView *albumsTableView;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIAlertAction *createAlbumAction;

@end

@implementation AlbumsViewController

static SEL extracted() {
    return @selector(categoryDataUpdated);
}

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categories = [NSArray new];
		
		self.albumsTableView = [UITableView new];
		self.albumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.albumsTableView.backgroundColor = [UIColor clearColor];
		self.albumsTableView.delegate = self;
		self.albumsTableView.dataSource = self;
		self.albumsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		self.albumsTableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		[self.albumsTableView registerClass:[AlbumTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.albumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.albumsTableView]];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:extracted() name:kPiwigoNotificationCategoryDataUpdated object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getAlbumData) name:UIApplicationDidBecomeActiveNotification object:nil];
	}
	return self;
}

-(void)getAlbumData
{
	[AlbumService getAlbumListForCategory:0
							 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
								 
							 } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
								 NSLog(@"getAlbumData error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                             }];
}

-(void)categoryDataUpdated
{
	self.categories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:0];
	[self.albumsTableView reloadData];
}

-(void)viewDidLoad
{
	[super viewDidLoad];
	
    // Only admins and Community users can upload images/videos in selected albums
    if ([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:0] hasUploadRights])
    {
		UIBarButtonItem *addCategory = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showCreateCategoryDialog)];
		self.navigationItem.rightBarButtonItem = addCategory;
	}
    self.albumsTableView.allowsMultipleSelectionDuringEditing = NO;

    [[iRate sharedInstance] promptIfAllCriteriaMet];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	refreshControl.backgroundColor = [UIColor piwigoOrange];
	refreshControl.tintColor = [UIColor piwigoGray];
	[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
	[self.albumsTableView addSubview:refreshControl];
	
    [self getAlbumData];
	[self refreshShowingCells];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
	[AlbumService getAlbumListForCategory:0
							 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [refreshControl endRefreshing];
                             }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                                 [refreshControl endRefreshing];
                             }
     ];
}

-(void)refreshShowingCells
{
	for(AlbumTableViewCell *cell in self.albumsTableView.visibleCells)
	{
		PiwigoAlbumData *albumData = [self.categories objectAtIndex:[self.albumsTableView indexPathForCell:cell].row];
		[cell setupWithAlbumData:albumData];
	}
}

#pragma mark -- Add album in root

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
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
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
                                  [self addCategoryWithName:alert.textFields.firstObject.text];
                              }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.createAlbumAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)addCategoryWithName:(NSString *)albumName
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCreateCategoryHUD];
    });
    
    // Create album
    [AlbumService createCategoryWithName:albumName
                            withStatus:@"public"
                          OnCompletion:^(NSURLSessionTask *task, BOOL createdSuccessfully) {
                              if(createdSuccessfully)
                              {
                                  [AlbumService getAlbumListForCategory:0
                                       OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                           [self hideCreateCategoryHUDwithSuccess:YES completion:^{
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   [self.albumsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.categories.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                                               });
                                           }];
                                       }
                                          onFailure:nil
                                   ];
                              }
                              else
                              {
                                  [self hideCreateCategoryHUDwithSuccess:NO completion:^{
                                      [self showCreateCategoryErrorWithMessage:nil];
                                  }];
                              }
                          } onFailure:^(NSURLSessionTask *task, NSError *error) {
                              [self hideCreateCategoryHUDwithSuccess:NO completion:^{
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
    
    [alert addAction:dismissAction];
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark -- HUD methods

-(void)showCreateCategoryHUD
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.contentColor = [UIColor piwigoWhiteCream];
    hud.bezelView.color = [UIColor colorWithWhite:0.f alpha:1.0];
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    
    // Define the text
    hud.label.text = NSLocalizedString(@"createNewAlbumHUD_label", @"Creating Album…");
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideCreateCategoryHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
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
                hud.label.text = NSLocalizedString(@"Complete", nil);
                [hud hideAnimated:YES afterDelay:3.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark -- UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add Category action
    [self.createAlbumAction setEnabled:NO];
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add Category action if album name is non null
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self.createAlbumAction setEnabled:(finalString.length >= 1)];
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Add Category action
    [self.createAlbumAction setEnabled:NO];
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


#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(self.categories.count <= 0)
	{
		self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
		
		self.emptyLabel.text = NSLocalizedString(@"categoryMainEmtpy", @"No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.");
		self.emptyLabel.textColor = [UIColor piwigoWhiteCream];
		self.emptyLabel.numberOfLines = 0;
		self.emptyLabel.textAlignment = NSTextAlignmentCenter;
		self.emptyLabel.font = [UIFont piwigoFontNormal];
		[self.emptyLabel sizeToFit];
		
		self.albumsTableView.backgroundView = self.emptyLabel;
	}
	else if(self.emptyLabel)
	{
		self.emptyLabel.hidden = YES;
	}
	return self.categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 180.0 + 8.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	cell.cellDelegate = self;
	
	PiwigoAlbumData *albumData = [self.categories objectAtIndex:indexPath.row];
	
	[cell setupWithAlbumData:albumData];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData = [self.categories objectAtIndex:indexPath.row];
	
	AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumId:albumData.albumId];
	[self.navigationController pushViewController:album animated:YES];
}


#pragma mark AlbumTableViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
	[self.navigationController pushViewController:viewController animated:YES];
}

@end
