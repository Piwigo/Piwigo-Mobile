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
#import "CategoriesData.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, strong) NSDictionary *localImages;
@property (nonatomic, strong) NSArray *sortedImageKeys;
@property (nonatomic, strong) NSString *categoryId;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, retain) NSMutableArray *selectedImageKeys;

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
		
		PhotosFetch *photoFetch = [PhotosFetch new];
		[photoFetch getLocalPhotosDictionary:^(id responseObject) {
			self.localImages = responseObject;
			self.sortedImageKeys = [self.localImages.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
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
	[self uploadNextImage];
}

-(void)uploadNextImage
{
	if(self.selectedImageKeys.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
	NSString *imageKey = [self.selectedImageKeys lastObject];
	ALAsset *imageAsset = [self.localImages objectForKey:imageKey];
	
	ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
	Byte *buffer = (Byte*)malloc(rep.size);
	NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
	NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
	
	[UploadService uploadImage:imageData
					  withName:[[imageAsset defaultRepresentation] filename]
					  forAlbum:[self.categoryId integerValue]
					onProgress:^(NSInteger current, NSInteger total) {
						NSLog(@"%@/%@ (%.4f)", @(current), @(total), (CGFloat)current / total);
					} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						NSLog(@"DONE UPLOAD");
						[self deselectCellForKey:imageKey];
						[self.selectedImageKeys removeObject:imageKey];
						[self uploadNextImage];
					} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						NSLog(@"ERROR: %@", error);
					}];
}

-(void)deselectCellForKey:(NSString*)imageKey
{
	NSInteger row = [self.sortedImageKeys indexOfObject:imageKey];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellSelected = NO;
}

#pragma mark -- UICollectionView Methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.localImages.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	NSString *imageAssetKey = self.sortedImageKeys[indexPath.row];
	[cell setupWithImageAsset:[self.localImages objectForKey:imageAssetKey]];
	
	return cell;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 10, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	
	NSString *imageAssetKey = self.sortedImageKeys[indexPath.row];
	ALAsset *imageAsset = [self.localImages objectForKey:imageAssetKey];
	
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
		
		ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
		Byte *buffer = (Byte*)malloc(rep.size);
		NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
		NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
		
		[UploadService uploadImage:imageData
						  withName:[[imageAsset defaultRepresentation] filename]
						  forAlbum:[self.categoryId integerValue]
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
}


@end
