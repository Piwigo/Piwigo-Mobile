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
#import "ImageUploadViewController.h"
#import "UploadHeaderCollectionReusableView.h"
#import "SortSelectViewController.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ImageUploadProgressDelegate, SortSelectViewControllerDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) NSArray *imageNamesList;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, assign) BOOL selectable;
@property (nonatomic, strong) NSMutableArray *selectedImageKeys;
@property (nonatomic, strong) NSMutableArray *uploadingImageKeys;

@property (nonatomic, assign) kPiwigoSortBy sortType;

@end

@implementation UploadViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.categoryId = categoryId;
		self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
		
		self.imageNamesList = [NSArray new];
		self.sortType = kPiwigoSortByName;
		
		self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.localImagesCollection.backgroundColor = [UIColor clearColor];
		self.localImagesCollection.dataSource = self;
		self.localImagesCollection.delegate = self;
		[self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		[self.localImagesCollection registerClass:[UploadHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
		self.localImagesCollection.indicatorStyle = UIScrollViewIndicatorStyleDefault;
		[self.view addSubview:self.localImagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
		
		self.selectable = NO;
		self.selectedImageKeys = [NSMutableArray new];
		self.uploadingImageKeys = [NSMutableArray new];
		
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

-(void)viewDidLoad
{
	[super viewDidLoad];
	
	if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
	{
		[self setEdgesForExtendedLayout:UIRectEdgeNone];
	}
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self loadNavButtons];
	[ImageUploadProgressView sharedInstance].delegate = self;
	for(ImageUpload *image in [ImageUploadManager sharedInstance].imageUploadQueue)
	{
		[self.uploadingImageKeys addObject:image.image];
	}
	self.sortType = self.sortType;
	
	if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
	{
		[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
	}
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

-(void)setSortType:(kPiwigoSortBy)sortType
{
	_sortType = sortType;
	
	self.imageNamesList = [NSArray new];
	[self.localImagesCollection reloadData];
	
	[SortSelectViewController getSortedImageNameArrayFromSortType:sortType
													  forCategory:self.categoryId
													 onCompletion:^(NSArray *imageNames) {
														 self.imageNamesList = imageNames;
														 [self.localImagesCollection reloadData];
													 }];
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
	[self showImageUpload];
}

-(void)showImageUpload
{
	ImageUploadViewController *vc = [ImageUploadViewController new];
	vc.selectedCategory = self.categoryId;
	vc.imagesSelected = self.selectedImageKeys;
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[self.navigationController presentViewController:nav animated:YES completion:nil];
	self.selectedImageKeys = [NSMutableArray new];
}

-(void)deselectCellForKey:(NSString*)imageKey
{
	NSInteger row = [[PhotosFetch sharedInstance].sortedImageKeys indexOfObject:imageKey];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellSelected = NO;
}

-(void)deselectUploadingCellForKey:(NSString*)key
{
	NSInteger row = [[PhotosFetch sharedInstance].sortedImageKeys indexOfObject:key];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellUploading = NO;
}

#pragma mark UICollectionView Methods

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	UploadHeaderCollectionReusableView *header = nil;
	
	if(kind == UICollectionElementKindSectionHeader)
	{
		header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header" forIndexPath:indexPath];
		header.currentSortLabel.text = [SortSelectViewController getNameForSortType:self.sortType];
		[header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSelectCollectionViewHeader)]];
	}
	
	return header;
}

-(void)didSelectCollectionViewHeader
{
	SortSelectViewController *sortSelectVC = [SortSelectViewController new];
	sortSelectVC.delegate = self;
	sortSelectVC.currentSortType = self.sortType;
	[self.navigationController pushViewController:sortSelectVC animated:YES];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
	return CGSizeMake(collectionView.frame.size.width, 44.0);
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.imageNamesList.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	NSString *imageAssetKey = self.imageNamesList[indexPath.row];
	[cell setupWithImageAsset:[[PhotosFetch sharedInstance].localImages objectForKey:imageAssetKey]];
	
	if([self.selectedImageKeys containsObject:imageAssetKey])
	{
		cell.cellSelected = YES;
	}
	else if([[ImageUploadManager sharedInstance].imageNamesUploadQueue objectForKey:imageAssetKey])
	{
		cell.cellUploading = YES;
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
	
	NSString *imageAssetKey = self.imageNamesList[indexPath.row];
	
	if(self.selectable && ![[ImageUploadManager sharedInstance].imageNamesUploadQueue objectForKey:imageAssetKey])
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
		
	}
}

#pragma mark ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	NSInteger row = [[PhotosFetch sharedInstance].sortedImageKeys indexOfObject:image.image];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	
	CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
	CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
	CGFloat peiceProgress = (CGFloat)current / total;
	CGFloat totalProgress = onChunkPercent + (chunkPercent * peiceProgress);
	if(totalProgress > 1)
	{
		totalProgress = 1;
	}
	cell.progress = totalProgress;
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
	[self deselectUploadingCellForKey:image.image];
	NSInteger index = 0;
	for(NSString *key in self.uploadingImageKeys)
	{
		if([key isEqualToString:image.image])
		{
			[self.uploadingImageKeys removeObjectAtIndex:index];
			
			if(self.sortType == kPiwigoSortByNotUploaded)
			{
				NSMutableArray *newList = [self.imageNamesList mutableCopy];
				[newList removeObject:key];
				self.imageNamesList = newList;
				[self.localImagesCollection reloadData];
			}
			
			break;
		}
		index++;
	}
	
}


#pragma mark SortSelectViewControllerDelegate Methods

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType
{
	self.sortType = sortType;
}


@end
