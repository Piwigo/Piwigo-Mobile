//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "AlbumService.h"
#import "PiwigoAlbumData.h"
#import "PiwigoImageData.h"
#import "Model.h"
#import "ImageDetailViewController.h"

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) NSArray *images;

@property (nonatomic, assign) NSInteger lastImageBulkCount;
@property (nonatomic, assign) NSInteger onPage;
@property (nonatomic, assign) BOOL isLoadingMoreImages;
@property (nonatomic, assign) BOOL didLoadAllImages;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumData:(PiwigoAlbumData*)albumData
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.albumData = albumData;
		self.title = self.albumData.name;
		self.lastImageBulkCount = [Model sharedInstance].imagesPerPage;
		self.onPage = 0;
		
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.backgroundColor = [UIColor clearColor];
		self.imagesCollection.dataSource = self;
		self.imagesCollection.delegate = self;
		[self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		self.imagesCollection.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		[self.view addSubview:self.imagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
		
		[self loadImageChunk];
	}
	return self;
}

-(void)loadImageChunk
{
	if(self.lastImageBulkCount != [Model sharedInstance].imagesPerPage || self.isLoadingMoreImages) return;
	
	NSLog(@"load more images");
	self.isLoadingMoreImages = YES;
	
	AFHTTPRequestOperation *request = [AlbumService getAlbumPhotosForAlbumId:self.albumData.albumId
																	  onPage:self.onPage
																	forOrder:kGetImageOrderFileName
																OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albumImages) {
																	
																	if(albumImages)
																	{
																		if(albumImages.count != [Model sharedInstance].imagesPerPage) {
																			self.didLoadAllImages = YES;
																		}
																		NSMutableArray *currentImages = [[NSMutableArray alloc] initWithArray:self.images];
																		[currentImages addObjectsFromArray:albumImages];
																		self.images = currentImages;
																		[self.imagesCollection reloadData];
																		NSLog(@"Updated more images");
																	} else {
																		self.didLoadAllImages = YES;
																	}
																	self.isLoadingMoreImages = NO;
																	self.onPage++;
																	self.lastImageBulkCount = albumImages.count;
																} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
																	NSLog(@"Fail get album photos: %@", error);
																	self.isLoadingMoreImages = NO;
																}];
	
	[request setQueuePriority:NSOperationQueuePriorityVeryHigh];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.images.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = collectionView.frame.size.width / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	PiwigoImageData *imageData = [self.images objectAtIndex:indexPath.row];
	
	[cell setupWithImageData:imageData];
	
	return cell;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 10, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	ImageDetailViewController *imageDetail = [ImageDetailViewController new];
	ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	[imageDetail setupWithImageData:selectedCell.imageData andPlaceHolderImage:selectedCell.cellImage.image];
	[self.navigationController pushViewController:imageDetail animated:YES];
}

-(void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.row >= [collectionView numberOfItemsInSection:0] - 21)
	{
		[self loadImageChunk];
	}
}

@end
