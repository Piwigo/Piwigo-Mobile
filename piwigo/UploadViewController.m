//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadViewController.h"
#import "UploadService.h"
#import "PhotosFetch.h"
#import "LocalImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, strong) NSDictionary *localImages;

@end

@implementation UploadViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		
		self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.localImagesCollection.backgroundColor = [UIColor clearColor];
		self.localImagesCollection.dataSource = self;
		self.localImagesCollection.delegate = self;
		[self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		self.localImagesCollection.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		[self.view addSubview:self.localImagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
		
		PhotosFetch *photoFetch = [PhotosFetch new];
		[photoFetch getLocalPhotosDictionary:^(id responseObject) {
			self.localImages = responseObject;
			[self.localImagesCollection reloadData];
		}];
		
//		UIImage *uploadMe = [UIImage imageNamed:@"uploadMe.jpg"];
//		[UploadService uploadImage:uploadMe
//						  withName:@"multi"
//						  forAlbum:1
//						onProgress:^(NSInteger current, NSInteger total) {
//							NSLog(@"%@/%@ (%.4f)", @(current), @(total), (CGFloat)current / total);
//						}
//					  OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
//						  NSLog(@"DONE: %@", response);
//					  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
//						  NSLog(@"FAIL! : %@", error);
//					  }];
	}
	return self;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.localImages.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = collectionView.frame.size.width / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	NSString *imageAssetKey = self.localImages.allKeys[indexPath.row];
	[cell setupWithImageAsset:[self.localImages objectForKey:imageAssetKey]];
	
	return cell;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 10, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *imageAssetKey = self.localImages.allKeys[indexPath.row];
	ALAsset *imageAsset = [self.localImages objectForKey:imageAssetKey];
	[UploadService uploadImage:[UIImage imageWithCGImage:[[imageAsset defaultRepresentation] fullResolutionImage]]
					  withName:[[imageAsset defaultRepresentation] filename]
					  forAlbum:6
					onProgress:^(NSInteger current, NSInteger total) {
						NSLog(@"%@/%@ (%.4f)", @(current), @(total), (CGFloat)current / total);
					} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						NSLog(@"DONE UPLOAD");
					} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						NSLog(@"ERROR: %@", error);
					}];
	
//	ImageDetailViewController *imageDetail = [ImageDetailViewController new];
//	ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
//	[imageDetail setupWithImageData:selectedCell.imageData andPlaceHolderImage:selectedCell.cellImage.image];
//	[self.navigationController pushViewController:imageDetail animated:YES];
}


@end
