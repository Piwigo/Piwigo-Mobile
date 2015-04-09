//
//  LocalAlbumsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LocalAlbumsViewController.h"
#import "CategoryTableViewCell.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "Model.h"
#import "PhotosFetch.h"
#import "UploadViewController.h"

@interface LocalAlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *localAlbumsTableView;
@property (nonatomic, assign) NSInteger categoryId;

@end

@implementation LocalAlbumsViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.categoryId = categoryId;
		
		self.title = NSLocalizedString(@"localAlbums", @"Local Albums");
		
		self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.localAlbumsTableView.delegate = self;
		self.localAlbumsTableView.dataSource = self;
		[self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.localAlbumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
		
	}
	return self;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusAuthorized) {
        [[PhotosFetch sharedInstance] updateLocalPhotosDictionary:^(id responseObject) {
            if (nil == responseObject) { // received nil object. Should not happen, but anyhow:
                [UIAlertView showWithTitle:NSLocalizedString(@"localAlbums_photosNiltitle", @"Problem reading photos")
                                   message:NSLocalizedString(@"localAlbums_photosNnil_msg", @"There is a problem reading your local photos.")
                         cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
                         otherButtonTitles:nil
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { // make view disappear
                                          [self.navigationController popViewControllerAnimated:YES];
                                   }];

            } else { // did receive library items, go ahead
                [self.localAlbumsTableView reloadData];
            }
        }];
    } else { // no access to photo library
        [UIAlertView showWithTitle:NSLocalizedString(@"localAlbums_photosNotAuthorized_title", @"Access not Authorized")
                           message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
                 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
                 otherButtonTitles:nil
                          tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { // make view disappear
                                  [self.navigationController popViewControllerAnimated:YES];
                          }];
    }
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [PhotosFetch sharedInstance].localImages.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	NSURL *groupURLString = [PhotosFetch sharedInstance].localImages.allKeys[indexPath.row];
	
	[[Model defaultAssetsLibrary] groupForURL:groupURLString resultBlock:^(ALAssetsGroup *group) {
		if(group)
		{
			NSString *name = [group valueForProperty:ALAssetsGroupPropertyName];
			[cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@ %@)", name, @(group.numberOfAssets), NSLocalizedString(@"deleteImage_iamgePlural", @"Images")]];
		}
		else
		{
			NSLog(@"fail to get album from URL string!");
			[cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"error", @"Error"), NSLocalizedString(@"groupURLError", @"Invalid group URL")]];
		}
	} failureBlock:^(NSError *error) {
		NSLog(@"fail %@", [error localizedDescription]);
		[cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"error", @"Error"), [error localizedDescription]]];
	}];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSURL *albumURL = [PhotosFetch sharedInstance].localImages.allKeys[indexPath.row];
	
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId andLocalAlbumURL:albumURL];
	[self.navigationController pushViewController:uploadVC animated:YES];
	
}

@end
