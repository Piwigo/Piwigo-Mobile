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
#import "SortHeaderCollectionReusableView.h"
#import "SortSelectViewController.h"
#import "LoadingView.h"
#import "UICountingLabel.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ImageUploadProgressDelegate, SortSelectViewControllerDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *imageNamesList;
@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, strong) UIBarButtonItem *selectAllBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, strong) NSMutableArray *selectedImageKeys;

@property (nonatomic, assign) kPiwigoSortBy sortType;
@property (nonatomic, strong) LoadingView *loadingView;

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
		[self.localImagesCollection registerClass:[SortHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
		self.localImagesCollection.indicatorStyle = UIScrollViewIndicatorStyleDefault;
		[self.view addSubview:self.localImagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
		
		self.noImagesLabel = [UILabel new];
		self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.noImagesLabel.font = [UIFont piwigoFontNormal];
		self.noImagesLabel.font = [self.noImagesLabel.font fontWithSize:20];
		self.noImagesLabel.textColor = [UIColor piwigoGrayLight];
		self.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
		self.noImagesLabel.hidden = YES;
		[self.view addSubview:self.noImagesLabel];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.noImagesLabel amount:60]];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
		
		self.selectedImageKeys = [NSMutableArray new];
		
		self.selectAllBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"selectAll", @"Select All") style:UIBarButtonItemStylePlain target:self action:@selector(selectAll)];
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
	
	if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
	{
		[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
	}
	
	self.sortType = self.sortType;
}

-(void)loadNavButtons
{
	if(self.selectedImageKeys.count > 0)
	{
		self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.uploadBarButton];
	}
	else
	{
		self.navigationItem.rightBarButtonItems = @[self.selectAllBarButton];
	}
}

-(void)setSortType:(kPiwigoSortBy)sortType
{
	_sortType = sortType;
	
	PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];

	if(sortType == kPiwigoSortByNotUploaded)
	{
		if(!self.loadingView.superview)
		{
			self.loadingView = [LoadingView new];
			self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
			NSString *progressLabelFormat = [NSString stringWithFormat:@"%@ / %@", @"%d", @(downloadingCategory.numberOfImages)];
			self.loadingView.progressLabel.format = progressLabelFormat;
			self.loadingView.progressLabel.method = UILabelCountingMethodLinear;
			[self.loadingView showLoadingWithLabel:NSLocalizedString(@"downloadingImageInfo", @"Downloading Image Info") andProgressLabel:[NSString stringWithFormat:progressLabelFormat, 0]];
			[self.view addSubview:self.loadingView];
			[self.view addConstraints:[NSLayoutConstraint constraintCenterView:self.loadingView]];
			
			
			if(downloadingCategory.numberOfImages != downloadingCategory.imageList.count)
			{
				[self.loadingView.progressLabel countFrom:0 to:100 withDuration:1];
			}
		}
	}
	
	self.imageNamesList = [NSArray new];
	[self.localImagesCollection reloadData];
	
	__block NSDate *lastTime = [NSDate date];
	
	[SortSelectViewController getSortedImageNameArrayFromSortType:sortType
													  forCategory:self.categoryId
													  forProgress:^(NSInteger onPage, NSInteger outOf) {

														  NSInteger lastImageCount = (onPage + 1) * [Model sharedInstance].imagesPerPage;
														  NSInteger currentDownloaded = (onPage + 2) * [Model sharedInstance].imagesPerPage;
														  
														  NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:lastTime];
														  
														  if(currentDownloaded > downloadingCategory.numberOfImages)
														  {
															  currentDownloaded = downloadingCategory.numberOfImages;
														  }
														  
														  [self.loadingView.progressLabel countFrom:lastImageCount to:currentDownloaded withDuration:duration];
														  
														  lastTime = [NSDate date];
													  }
													 onCompletion:^(NSArray *imageNames) {
														 
														 if(sortType == kPiwigoSortByNotUploaded)
														 {
															 [self.loadingView hideLoadingWithLabel:@"Done" showCheckMark:YES withDelay:0.5];
														 }
														 self.imageNamesList = imageNames;
														 [self.localImagesCollection reloadData];
													 }];
}

-(void)selectAll
{
	self.selectedImageKeys = [self.imageNamesList mutableCopy];
	[self loadNavButtons];
	[self.localImagesCollection reloadData];
}

-(void)cancelSelect
{
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
	NSInteger row = [self.imageNamesList indexOfObject:imageKey];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellSelected = NO;
}

-(void)deselectUploadingCellForKey:(NSString*)key
{
	NSInteger row = [self.imageNamesList indexOfObject:key];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellUploading = NO;
}

#pragma mark UICollectionView Methods

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	SortHeaderCollectionReusableView *header = nil;
	
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
	self.noImagesLabel.hidden = self.imageNamesList.count != 0;

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
	
	if(![[ImageUploadManager sharedInstance].imageNamesUploadQueue objectForKey:imageAssetKey])
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
	
	[self loadNavButtons];
}

#pragma mark ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	NSInteger row = [self.imageNamesList indexOfObject:image.image];
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
	if(self.sortType == kPiwigoSortByNotUploaded)
	{
		NSMutableArray *newList = [self.imageNamesList mutableCopy];
		[newList removeObject:image.image];
		self.imageNamesList = newList;
		[self.localImagesCollection reloadData];
	}
}


#pragma mark SortSelectViewControllerDelegate Methods

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType
{
	self.sortType = sortType;
}


@end
