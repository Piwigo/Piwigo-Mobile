//
//  AlbumPhotosViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumPhotosViewController.h"
#import "AlbumPhotoTableViewCell.h"
#import "ImageDetailViewController.h"
#import "PiwigoImageData.h"
#import "PiwigoAlbumData.h"
#import "AlbumService.h"

@interface AlbumPhotosViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) UITableView *photosTableView;
@property (nonatomic, strong) NSArray *photos;

@property (nonatomic, assign) BOOL isLoadingMoreImages;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end

@implementation AlbumPhotosViewController

-(instancetype)initWithAlbumData:(PiwigoAlbumData*)albumData
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		self.albumData = albumData;
		self.title = albumData.name;
		self.isLoadingMoreImages = NO;
		
		self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		self.spinner.color = [UIColor piwigoGray];
		self.spinner.frame = CGRectMake(0, 0, 320, 44);
		
		self.photosTableView = [UITableView new];
		self.photosTableView.backgroundColor = [UIColor clearColor];
		self.photosTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.photosTableView.delegate = self;
		self.photosTableView.dataSource = self;
		[self.photosTableView registerClass:[AlbumPhotoTableViewCell class] forCellReuseIdentifier:@"cell"];
		[self.view addSubview:self.photosTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.photosTableView]];
		
		[self loadMoreImages];
	}
	return self;
}

-(void)loadMoreImages
{
	self.isLoadingMoreImages = YES;
	[self.spinner startAnimating];
	self.photosTableView.tableFooterView = self.spinner;
	
	AFHTTPRequestOperation *request = [AlbumService getAlbumPhotosForAlbumId:self.albumData.albumId
							 photosPerPage:100
									onPage:0
								  forOrder:kGetImageOrderFileName
							  OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albumImages) {
						  
								  if(albumImages)
								  {
									  NSMutableArray *currentImages = [[NSMutableArray alloc] initWithArray:self.photos];
									  [currentImages addObjectsFromArray:albumImages];
									  self.photos = currentImages;
									  [self.photosTableView reloadData];
									  NSLog(@"Updated more images");
									  self.spinner.color = [UIColor piwigoOrange];
									  self.view.backgroundColor = [UIColor piwigoGray];
								  }
								  self.isLoadingMoreImages = NO;
								  self.photosTableView.tableFooterView = nil;
							  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
								  NSLog(@"Fail get album photos: %@", error);
								  self.isLoadingMoreImages = NO;
								  self.photosTableView.tableFooterView = nil;
							  }];

	[request setQueuePriority:NSOperationQueuePriorityVeryHigh];
}

#pragma mark -- UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.photos.count;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	AlbumPhotoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
	
	[cell setupWithImageData:[self.photos objectAtIndex:indexPath.row]];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	AlbumPhotoTableViewCell *cell = (AlbumPhotoTableViewCell*)[tableView cellForRowAtIndexPath:indexPath];
	
	ImageDetailViewController *imageDetail = [ImageDetailViewController new];
	[imageDetail setupWithImageData:[self.photos objectAtIndex:indexPath.row] andPlaceHolderImage:cell.thumbnail.image];
	[self.navigationController pushViewController:imageDetail animated:YES];
	
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.row >= [tableView numberOfRowsInSection:0] - 10 && !self.isLoadingMoreImages) {
		NSLog(@"load more rows");
		[self loadMoreImages];
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)aScrollView
				  willDecelerate:(BOOL)decelerate
{
	CGPoint offset = aScrollView.contentOffset;
	CGRect bounds = aScrollView.bounds;
	CGSize size = aScrollView.contentSize;
	UIEdgeInsets inset = aScrollView.contentInset;
	float y = offset.y + bounds.size.height - inset.bottom;
	float h = size.height;
	
	float reload_distance = 50;
	if(y > h + reload_distance && !self.isLoadingMoreImages) {
		NSLog(@"load more rows");
		[self loadMoreImages];
	}
}


@end
