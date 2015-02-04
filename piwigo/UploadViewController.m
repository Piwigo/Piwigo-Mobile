//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadViewController.h"
#import "ImageUploadManager.h"
#import "PhotosFetch.h"
#import "LocalImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "CategoriesData.h"
#import "ImageUpload.h"
#import "ImageUploadProgressView.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ImageUploadDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, strong) NSString *categoryId;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, retain) NSMutableArray *selectedImageKeys;

@property (nonatomic, strong) ImageUploadProgressView *uploadProgressView;

@end

@implementation UploadViewController

-(instancetype)initWithCategoryId:(NSString*)categoryId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.categoryId = categoryId;
		self.title = [[[CategoriesData sharedInstance].categories objectForKey:self.categoryId] name];
		
		self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.localImagesCollection.backgroundColor = [UIColor clearColor];
		self.localImagesCollection.dataSource = self;
		self.localImagesCollection.delegate = self;
		[self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		self.localImagesCollection.indicatorStyle = UIScrollViewIndicatorStyleDefault;
		[self.view addSubview:self.localImagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
		
		[[PhotosFetch sharedInstance] updateLocalPhotosDictionary:^(id responseObject) {
			[self.localImagesCollection reloadData];
		}];
		
		self.selectable = NO;
		self.selectedImageKeys = [NSMutableArray new];
		
		self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select")
																style:UIBarButtonItemStylePlain
															   target:self
															   action:@selector(selectCells)];
		self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"]
																style:UIBarButtonItemStylePlain
															   target:self
															   action:@selector(uploadSelected)];

		self.uploadProgressView = [ImageUploadProgressView new];
		self.uploadProgressView.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addSubview:self.uploadProgressView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.uploadProgressView]];
		[self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.uploadProgressView
															  attribute:NSLayoutAttributeBottom
															  relatedBy:NSLayoutRelationEqual
																 toItem:self.bottomLayoutGuide
															  attribute:NSLayoutAttributeTop
															 multiplier:1.0
															   constant:0]];
		[self.view addConstraint:[NSLayoutConstraint constrainViewToHeight:self.uploadProgressView height:50]];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self loadNavButtons];
}

-(void)loadNavButtons
{
	if(!self.selectable)
	{
		self.navigationItem.rightBarButtonItems = @[self.selectBarButton];
	}
	else
	{
		self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.uploadBarButton];
	}
}

-(void)selectCells
{
	self.selectable = YES;
	[self loadNavButtons];
}

-(void)cancelSelect
{
	self.selectable = NO;
	for(NSString *cellKey in self.selectedImageKeys)
	{
		[self deselectCellForKey:cellKey];
	}
	self.selectedImageKeys = [NSMutableArray new];
	[self loadNavButtons];
}

-(void)uploadSelected
{
	[[ImageUploadManager sharedInstance] addImages:self.selectedImageKeys forCategory:[self.categoryId integerValue] andPrivacy:0];
//	[ImageUploadManager sharedInstance].delegate = self;
	self.selectedImageKeys = [NSMutableArray new];
}

-(void)deselectCellForKey:(NSString*)imageKey
{
	NSInteger row = [[PhotosFetch sharedInstance].sortedImageKeys indexOfObject:imageKey];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellSelected = NO;
}

#pragma mark UICollectionView Methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [PhotosFetch sharedInstance].localImages.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	NSString *imageAssetKey = [PhotosFetch sharedInstance].sortedImageKeys[indexPath.row];
	[cell setupWithImageAsset:[[PhotosFetch sharedInstance].localImages objectForKey:imageAssetKey]];
	
	if([self.selectedImageKeys containsObject:imageAssetKey]) {
		cell.cellSelected = YES;
	}
	
	return cell;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 10, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	
	NSString *imageAssetKey = [PhotosFetch sharedInstance].sortedImageKeys[indexPath.row];
	
	if(self.selectable)
	{
		BOOL isCellAlreadySelected = [self.selectedImageKeys containsObject:imageAssetKey];
		if(!isCellAlreadySelected)
		{
			[self.selectedImageKeys addObject:imageAssetKey];
		}
		else
		{
			[self.selectedImageKeys removeObject:imageAssetKey];
		}
		selectedCell.cellSelected = !isCellAlreadySelected;
	}
	else
	{
//		ALAsset *imageAsset = [[PhotosFetch sharedInstance].localImages objectForKey:imageAssetKey];
//		
//		ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
//		Byte *buffer = (Byte*)malloc(rep.size);
//		NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
//		NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
//		
//		[UploadService uploadImage:imageData
//						  withName:[[imageAsset defaultRepresentation] filename]
//						  forAlbum:[self.categoryId integerValue]
//				   andPrivacyLevel:0
//						onProgress:^(NSInteger current, NSInteger total) {
//							NSLog(@"%@/%@ (%.4f)", @(current), @(total), (CGFloat)current / total);
//						} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
//							NSLog(@"DONE UPLOAD");
//						} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
//							NSLog(@"ERROR: %@", error);
//						}];
//		
//		ImageDetailViewController *imageDetail = [ImageDetailViewController new];
//		ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
//		[imageDetail setupWithImageData:selectedCell.imageData andPlaceHolderImage:selectedCell.cellImage.image];
//		[self.navigationController pushViewController:imageDetail animated:YES];
	}
}


#pragma mark ImageUploadManagerDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue
{
	[self deselectCellForKey:image.imageUploadName];
}


@end
