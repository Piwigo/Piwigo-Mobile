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

@interface AlbumsViewController () <UITableViewDelegate, UITableViewDataSource, AlbumTableViewCellDelegate>

@property (nonatomic, strong) UITableView *albumsTableView;
@property (nonatomic, strong) NSArray *categories;

@end

@implementation AlbumsViewController

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
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoryDataUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
		[AlbumService getAlbumListOnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
			
		} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
			
			NSLog(@"Album list err: %@", error);
		}];
	}
	return self;
}

-(void)categoryDataUpdated
{
	self.categories = [[CategoriesData sharedInstance] getCategoriesForParentCategory:0];
	[self.albumsTableView reloadData];
}

-(void)viewDidLoad
{
	[super viewDidLoad];
	
	if([Model sharedInstance].hasAdminRights)
	{
		UIBarButtonItem *addCategory = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCategory)];
		self.navigationItem.rightBarButtonItem = addCategory;
	}
}

-(void)addCategory
{
	[UIAlertView showWithTitle:NSLocalizedString(@"createNewAlbum_title", @"Create New Album")
					   message:NSLocalizedString(@"createNewAlbum_message", @"Album name")
						 style:UIAlertViewStylePlainTextInput
			 cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
			 otherButtonTitles:@[NSLocalizedString(@"alertAddButton", @"Add")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  [AlbumService createCategoryWithName:[alertView textFieldAtIndex:0].text
													  OnCompletion:^(AFHTTPRequestOperation *operation, BOOL createdSuccessfully) {
														  if(createdSuccessfully)
														  {
															  [AlbumService getAlbumListOnCompletion:nil onFailure:nil];
														  }
														  else
														  {
															  [self showCreateCategoryError];
														  }
													  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
														  
														  [self showCreateCategoryError];
													  }];
						  }
					  }];
}

-(void)showCreateCategoryError
{
	[UIAlertView showWithTitle:NSLocalizedString(@"createAlbumError_title", @"Create Album Error")
					   message:NSLocalizedString(@"createAlbumError_message", @"Failed to create a new album")
			 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
			 otherButtonTitles:nil
					  tapBlock:nil];
}


#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
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
