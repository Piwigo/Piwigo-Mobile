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

@interface AlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *albumsTableView;

@end

@implementation AlbumsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		
		self.albumsTableView = [UITableView new];
		self.albumsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.albumsTableView.delegate = self;
		self.albumsTableView.dataSource = self;
		self.albumsTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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
	[UIAlertView showWithTitle:@"Create New Album"
					   message:@"Album name"
						 style:UIAlertViewStylePlainTextInput
			 cancelButtonTitle:@"Cancel"
			 otherButtonTitles:@[@"Add"]
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
	[UIAlertView showWithTitle:@"Create Album Error"
					   message:@"Failed to create a new album"
			 cancelButtonTitle:@"Okay"
			 otherButtonTitles:nil
					  tapBlock:nil];
}


#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [CategoriesData sharedInstance].categories.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 180.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectAtIndex:indexPath.row];
	
	[cell setupWithAlbumData:albumData];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectAtIndex:indexPath.row];
	
	AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumId:albumData.albumId];
	[self.navigationController pushViewController:album animated:YES];
}

@end
