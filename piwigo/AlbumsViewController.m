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
#import "AlbumPhotosViewController.h"
#import "AlbumImagesViewController.h"
#import "CategoriesData.h"

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
		
		[AlbumService getAlbumListOnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
			
			[self.albumsTableView reloadData];
		} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
			
			NSLog(@"Album list err: %@", error);
		}];
	}
	return self;
}


#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [CategoriesData sharedInstance].sortedKeys.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 180.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	NSString *albumIdForIndex = [[CategoriesData sharedInstance].sortedKeys objectForKey:[NSString stringWithFormat:@"%@", @(indexPath.row + 1)]];
	NSNumber *index = @([albumIdForIndex integerValue]);
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectForKey:index];
	
	[cell setupWithAlbumData:albumData];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSString *albumIdForIndex = [[CategoriesData sharedInstance].sortedKeys objectForKey:[NSString stringWithFormat:@"%@", @(indexPath.row + 1)]];
	NSNumber *index = @([albumIdForIndex integerValue]);
	PiwigoAlbumData *albumData = [[CategoriesData sharedInstance].categories objectForKey:index];
	
	AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumId:albumData.albumId];
	[self.navigationController pushViewController:album animated:YES];
}

@end
