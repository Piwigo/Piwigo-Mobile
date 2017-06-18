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
@property (nonatomic, strong) NSArray *groups;

@end

@implementation LocalAlbumsViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categoryId = categoryId;
		
		self.title = NSLocalizedString(@"localAlbums", @"Local Albums");
		
		self.groups = [NSArray new];
		[[PhotosFetch sharedInstance] getLocalGroupsOnCompletion:^(id responseObject) {
			if([responseObject isKindOfClass:[NSNumber class]])
			{	// make view disappear
				[self.navigationController popToRootViewControllerAnimated:YES];
			}
			else if(responseObject == nil)
			{
				[UIAlertView showWithTitle:NSLocalizedString(@"localAlbums_photosNiltitle", @"Problem Reading Photos")
								   message:NSLocalizedString(@"localAlbums_photosNnil_msg", @"There is a problem reading your local photo library.")
						 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
						 otherButtonTitles:nil
								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) { // make view disappear
									  [self.navigationController popViewControllerAnimated:YES];
								  }];
			}
			else
			{
				self.groups = responseObject;
				[self.localAlbumsTableView reloadData];
			}
		}];
		
		self.localAlbumsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.localAlbumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.localAlbumsTableView.backgroundColor = [UIColor piwigoGray];
		self.localAlbumsTableView.delegate = self;
		self.localAlbumsTableView.dataSource = self;
		[self.localAlbumsTableView registerClass:[CategoryTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.localAlbumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localAlbumsTableView]];
		
	}
	return self;
}


#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.groups.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	CategoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	ALAssetsGroup *groupAsset = [self.groups objectAtIndex:indexPath.row];
	NSString *name = [groupAsset valueForProperty:ALAssetsGroupPropertyName];
	[cell setCellLeftLabel:[NSString stringWithFormat:@"%@ (%@ %@)", name, @(groupAsset.numberOfAssets), NSLocalizedString(@"deleteImage_imagePlural", @"Images")]];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId andGroupAsset:[self.groups objectAtIndex:indexPath.row]];
	[self.navigationController pushViewController:uploadVC animated:YES];
	
}

@end
