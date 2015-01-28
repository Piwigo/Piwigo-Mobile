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

@interface AlbumsViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *albumsTableView;
@property (nonatomic, strong) NSArray *albumsArray;

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
		[self.albumsTableView registerClass:[AlbumTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.albumsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.albumsTableView]];
		
		[AlbumService getAlbumListOnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
			
			self.albumsArray = albums;
			[self.albumsTableView reloadData];
		} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
			
			NSLog(@"Album list err: %@", error);
		}];
	}
	return self;
}


-(void)parseJSON:(NSDictionary*)json
{
	NSDictionary *imagesInfo = [[json objectForKey:@"result"] objectForKey:@"images"];
	
	NSMutableArray *namesList = [NSMutableArray new];
	for(NSDictionary *image in imagesInfo)
	{
		PiwigoImageData *imgData = [PiwigoImageData new];
		imgData.name = [image objectForKey:@"file"];
		imgData.fullResPath = [image objectForKey:@"element_url"];
		
		NSDictionary *imageSizes = [image objectForKey:@"derivatives"];
		imgData.squarePath = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
		imgData.mediumPath = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
		
		NSArray *categories = [image objectForKey:@"categories"];
		NSMutableArray *categoryIds = [NSMutableArray new];
		for(NSDictionary *category in categories)
		{
			[categoryIds addObject:[category objectForKey:@"id"]];
		}
		
		imgData.categoryIds = categoryIds;
		
		[namesList addObject:imgData];
	}
	self.albumsArray = namesList;
	[self.albumsTableView reloadData];
}


#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.albumsArray.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	[cell setupWithAlbumData:[self.albumsArray objectAtIndex:indexPath.row]];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
//	AlbumPhotosViewController *album = [[AlbumPhotosViewController alloc] initWithAlbumData:[self.albumsArray objectAtIndex:indexPath.row]];
	AlbumImagesViewController *album = [[AlbumImagesViewController alloc] initWithAlbumData:[self.albumsArray objectAtIndex:indexPath.row]];
	[self.navigationController pushViewController:album animated:YES];
}

@end
