//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageService.h"
#import "CategoriesData.h"
#import "Model.h"
#import "ImageDetailViewController.h"
#import "ImageDownloadView.h"
#import "PiwigoAlbumData.h"
#import "SortHeaderCollectionReusableView.h"
#import "CategorySortViewController.h"
#import "CategoryImageSort.h"
#import "LoadingView.h"
#import "UICountingLabel.h"
#import "CategoryCollectionViewCell.h"
#import "AlbumService.h"
#import "UploadViewController.h"

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImageDetailDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) NSArray *imageList;
@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;
@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger startDeleteTotalImages;
@property (nonatomic, assign) NSInteger totalImagesToDownload;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) ImageDownloadView *downloadView;
@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) LoadingView *loadingView;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSInteger)albumId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categoryId = albumId;
		self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
		self.currentSortCategory = 0;
		self.imageList = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		if(self.imageList.count <= 100) {
			[self loadMoreImages];
		}
		
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.backgroundColor = [UIColor clearColor];
		self.imagesCollection.alwaysBounceVertical = YES;
		self.imagesCollection.dataSource = self;
		self.imagesCollection.delegate = self;
		[self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		[self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"category"];
		[self.imagesCollection registerClass:[SortHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
		self.imagesCollection.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		[self.view addSubview:self.imagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
		
		self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImages)];
		self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImages)];
		self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"] style:UIBarButtonItemStylePlain target:self action:@selector(uploadToThisCategory)];
		self.isSelect = NO;
		self.selectedImageIds = [NSMutableArray new];
		
		self.downloadView.hidden = YES;
		
		[AlbumService getAlbumListForCategory:self.categoryId
								 OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
									 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
								 } onFailure:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self loadNavButtons];
	[self.imagesCollection reloadData];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	refreshControl.backgroundColor = [UIColor piwigoOrange];
	refreshControl.tintColor = [UIColor piwigoGray];
	refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Loading All Images")];
	[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
	[self.imagesCollection addSubview:refreshControl];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadAllCategoryImageDataForProgress:nil OnCompletion:^(BOOL completed) {
		self.imageList = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
		self.currentSortCategory = self.currentSortCategory;
		[self.imagesCollection reloadData];
		[refreshControl endRefreshing];
	}];
	
	[AlbumService getAlbumListForCategory:self.categoryId
							 OnCompletion:^(AFHTTPRequestOperation *operation, NSArray *albums) {
		[self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
	} onFailure:nil];
}

-(void)categoriesUpdated
{
	[self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
}

-(void)loadNavButtons
{
	if(!self.isSelect) {
		self.navigationItem.rightBarButtonItems = @[self.selectBarButton, self.uploadBarButton];
	} else {
		if([Model sharedInstance].hasAdminRights)
		{
			self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.downloadBarButton, self.deleteBarButton];
		}
		else
		{
			self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.downloadBarButton];
		}
	}
}

-(void)select
{
	self.isSelect = YES;
	[self loadNavButtons];
}
-(void)cancelSelect
{
	self.isSelect = NO;
	[self loadNavButtons];
	self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
	for(ImageCollectionViewCell *cell in self.imagesCollection.visibleCells) {
		if(cell.isSelected) cell.isSelected = NO;
	}
	self.downloadView.hidden = YES;
	self.selectedImageIds = [NSMutableArray new];
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}

-(void)uploadToThisCategory
{
	UploadViewController *uploadVC = [[UploadViewController alloc] initWithCategoryId:self.categoryId];
	[self.navigationController pushViewController:uploadVC animated:YES];
}

-(void)deleteImages
{
	if(self.selectedImageIds.count <= 0) return;
	
	NSString *titleString = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"deleteImage_delete", @"Delete"), self.selectedImageIds.count > 1 ? NSLocalizedString(@"deleteImage_iamgePlural", @"Images") : NSLocalizedString(@"deleteImage_iamgeSingular", @"Image")];
	NSString *messageString = [NSString stringWithFormat:NSLocalizedString(@"delteImage_message", @"Are you sure you want to delete the selected %@ %@ This cannot be undone!"), @(self.selectedImageIds.count), self.selectedImageIds.count > 1 ? NSLocalizedString(@"deleteImage_iamgePlural", @"Images") : NSLocalizedString(@"deleteImage_iamgeSingular", @"Image")];
	[UIAlertView showWithTitle:titleString
					   message:messageString
			 cancelButtonTitle:NSLocalizedString(@"deleteImage_cancelButton", @"Nevermind")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1) {
							  self.startDeleteTotalImages = self.selectedImageIds.count;
							  [self deleteSelected];
						  }
					  }];
}

-(void)deleteSelected
{
	if(self.selectedImageIds.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
	NSString *imageId = [NSString stringWithFormat:@"%@", @([self.selectedImageIds.lastObject integerValue])];
	self.navigationItem.rightBarButtonItems = @[self.cancelBarButton];
	[ImageService deleteImage:[[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:imageId]
				 ListOnCompletion:^(AFHTTPRequestOperation *operation) {
					 
					 NSIndexSet *set = [self.imageList indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
						 return [obj.imageId integerValue] != [self.selectedImageIds.lastObject integerValue];
					 }];
					 self.imageList = [self.imageList objectsAtIndexes:set];
					 
					 NSMutableArray *newList = [[NSMutableArray alloc] initWithArray:self.imageList];
					 [newList removeObject:self.selectedImageIds.lastObject];
					 self.imageList = newList;
					 
					 [self.selectedImageIds removeLastObject];
					 NSInteger percentDone = ((CGFloat)(self.startDeleteTotalImages - self.selectedImageIds.count) / self.startDeleteTotalImages) * 100;
					 self.title = [NSString stringWithFormat:NSLocalizedString(@"deleteImageProgress_title", @"Deleting %@%% Done"), @(percentDone)];
					 [self.imagesCollection reloadData];
					 [self deleteSelected];
				 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					 [UIAlertView showWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
										message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
							  cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
							  otherButtonTitles:@[NSLocalizedString(@"alertTryAgainButton", @"Try Again")]
									   tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
										   if(buttonIndex == 1)
										   {
											   [self deleteSelected];
										   }
									   }];
				 }];
}

-(void)downloadImages
{
	if(self.selectedImageIds.count <= 0) return;
	
	[UIAlertView showWithTitle:NSLocalizedString(@"downloadImage", @"Download Images")
					   message:[NSString stringWithFormat:NSLocalizedString(@"downloadImage_confirmation", @"Are you sure you want to downlaod the selected %@ %@?"), @(self.selectedImageIds.count), self.selectedImageIds.count > 1 ? NSLocalizedString(@"deleteImage_iamgePlural", @"Images") : NSLocalizedString(@"deleteImage_iamgeSingular", @"Image")]
			 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
			 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  self.totalImagesToDownload = self.selectedImageIds.count;
							  [self downloadImage];
						  }
					  }];
}

-(void)downloadImage
{
	if(self.selectedImageIds.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	self.downloadView.multiImage = YES;
	self.downloadView.totalImageDownloadCount = self.totalImagesToDownload;
	self.downloadView.imageDownloadCount = self.totalImagesToDownload - self.selectedImageIds.count + 1;
	
	self.downloadView.hidden = NO;
	self.navigationItem.rightBarButtonItems = @[self.cancelBarButton];
	
	PiwigoImageData *downloadingImage = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject];
	
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
	[dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:downloadingImage.thumbPath]]
					 placeholderImage:nil
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];
	if(!downloadingImage.isVideo)
	{
		[ImageService downloadImage:downloadingImage
						 onProgress:^(NSInteger current, NSInteger total) {
							 CGFloat progress = (CGFloat)current / total;
							 self.downloadView.percentDownloaded = progress;
						 } ListOnCompletion:^(AFHTTPRequestOperation *operation, UIImage *image) {
							 [self saveImageToCameraRoll:image];
						 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
							 NSLog(@"download fail");
						 }];
	}
	else
	{
		[ImageService downloadVideo:downloadingImage
						 onProgress:^(NSInteger current, NSInteger total) {
							 CGFloat progress = (CGFloat)current / total;
							 self.downloadView.percentDownloaded = progress;
						 } ListOnCompletion:^(AFHTTPRequestOperation *operation, id response) {
							 NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
							 NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:downloadingImage.fileName];
							 UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
						 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
							 NSLog(@"download fail");
						 }];
	}
}

-(void)saveImageToCameraRoll:(UIImage*)imageToSave
{
	UIImageWriteToSavedPhotosAlbum(imageToSave, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

// called when the image is done saving to disk
-(void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image")
						   message:[NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), [error localizedDescription]]
				 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
				 otherButtonTitles:nil
						  tapBlock:nil];
		[self cancelSelect];
	}
	else
	{
		[self.selectedImageIds removeLastObject];
		[self.imagesCollection reloadData];
		[self downloadImage];
	}
}
-(void)movie:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
	if(error)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"videoSaveError_title", @"Fail Saving Video")
						   message:[NSString stringWithFormat:NSLocalizedString(@"videoSaveError_message", @"Failed to save video. Error: %@"), [error localizedDescription]]
				 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
				 otherButtonTitles:nil
						  tapBlock:nil];
	}
	else
	{
		[self.selectedImageIds removeLastObject];
		[self.imagesCollection reloadData];
		[self downloadImage];
	}
}

-(ImageDownloadView*)downloadView
{
	if(_downloadView) return _downloadView;
	
	_downloadView = [ImageDownloadView new];
	_downloadView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_downloadView];
	[self.view addConstraints:[NSLayoutConstraint constraintFillSize:_downloadView]];
	return _downloadView;
}

-(void)loadMoreImages
{
	if(self.currentSortCategory != 0) return;
	
	[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadCategoryImageDataChunkForProgress:nil
																								OnCompletion:^(BOOL completed) {
																									if(!completed)
																									{
																										return;
																									}
																									
																									self.imageList = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
																									[self.imagesCollection reloadData];
																								}];
}

-(void)setCurrentSortCategory:(kPiwigoSortCategory)currentSortCategory
{
	if(_currentSortCategory == kPiwigoSortCategoryVideoOnly ||
	   _currentSortCategory == kPiwigoSortCategoryImageOnly)
	{
		self.imageList = [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList;
	}
	
	if(currentSortCategory == 0)
	{
		return;
	}
	
	_currentSortCategory = currentSortCategory;
	
	if(self.imageList.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
	{
		if(!self.loadingView.superview)
		{
			self.loadingView = [LoadingView new];
			self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
			NSString *progressLabelFormat = [NSString stringWithFormat:@"%@ / %@", @"%d", @([[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])];
			self.loadingView.progressLabel.format = progressLabelFormat;
			self.loadingView.progressLabel.method = UILabelCountingMethodLinear;
			[self.loadingView showLoadingWithLabel:NSLocalizedString(@"downloadingImageInfoForSort", @"Downloading Image Info for Sort") andProgressLabel:[NSString stringWithFormat:progressLabelFormat, 0]];
			[self.view addSubview:self.loadingView];
			[self.view addConstraints:[NSLayoutConstraint constraintCenterView:self.loadingView]];
			
			
			if(self.imageList.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
			{
				[self.loadingView.progressLabel countFrom:0 to:100 withDuration:1];
			}
		}
		// load all the images
		__block NSDate *lastTime = [NSDate date];
		[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadAllCategoryImageDataForProgress:^(NSInteger onPage, NSInteger outOf) {
			
			NSInteger lastImageCount = (onPage + 1) * [Model sharedInstance].imagesPerPage;
			NSInteger currentDownloaded = (onPage + 2) * [Model sharedInstance].imagesPerPage;
			
			NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:lastTime];
			
			if(currentDownloaded > [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
			{
				currentDownloaded = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages];
			}
			
			[self.loadingView.progressLabel countFrom:lastImageCount to:currentDownloaded withDuration:duration];
			
			lastTime = [NSDate date];
		} OnCompletion:^(BOOL completed) {

			self.imageList = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList forSortOrder:_currentSortCategory];
			[self.loadingView hideLoadingWithLabel:@"Done" showCheckMark:YES withDelay:0.5];
			[self.imagesCollection reloadData];
		}];
	}
	else
	{
		self.imageList = [CategoryImageSort sortImages:[[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList forSortOrder:_currentSortCategory];
		[self.imagesCollection reloadData];
	}
	
}

#pragma mark -- UICollectionView Methods

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)
	{
		SortHeaderCollectionReusableView *header = nil;
		
		if(kind == UICollectionElementKindSectionHeader)
		{
			header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header" forIndexPath:indexPath];
			header.currentSortLabel.text = [CategorySortViewController getNameForCategorySortType:self.currentSortCategory];
			[header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSelectCollectionViewHeader)]];
		}
		
		self.noImagesLabel = [UILabel new];
		self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.noImagesLabel.font = [UIFont piwigoFontNormal];
		self.noImagesLabel.font = [self.noImagesLabel.font fontWithSize:20];
		self.noImagesLabel.textColor = [UIColor piwigoWhiteCream];
		self.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
		self.noImagesLabel.hidden = self.imageList.count != 0;
		[header addSubview:self.noImagesLabel];
		[header addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.noImagesLabel amount:-40]];
		[header addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
		
		return header;
	}
	
	UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];

	return view;
}

-(void)didSelectCollectionViewHeader
{
	CategorySortViewController *categorySort = [CategorySortViewController new];
	categorySort.currentCategorySortType = self.currentSortCategory;
	categorySort.sortDelegate = self;
	[self.navigationController pushViewController:categorySort animated:YES];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
	if(section == 1)
	{
		return CGSizeMake(collectionView.frame.size.width, 44.0);
	}
	
	return CGSizeZero;
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return 2;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	self.noImagesLabel.hidden = self.imageList.count != 0;
	
	if(section == 1)
	{
		return self.imageList.count;
	}
	else
	{
		return [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
	}
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
	if(indexPath.section == 1)
	{
		return CGSizeMake(size, size);
	}
	else
	{
		return CGSizeMake(collectionView.frame.size.width - 20, 188);
	}
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)
	{
		ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
		
		PiwigoImageData *imageData = [self.imageList objectAtIndex:indexPath.row];
		[cell setupWithImageData:imageData];
		
		if([self.selectedImageIds containsObject:imageData.imageId])
		{
			cell.isSelected = YES;
		}
		
		if(indexPath.row >= [collectionView numberOfItemsInSection:1] - 21 && self.imageList.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages])
		{
			[self loadMoreImages];
		}
		
		return cell;
	}
	else
	{
		CategoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
		cell.categoryDelegate = self;
		
		PiwigoAlbumData *albumData = [[[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId] objectAtIndex:indexPath.row];
		
		[cell setupWithAlbumData:albumData];
		
		return cell;
	}
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 40, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)
	{
		ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
		if(!self.isSelect)
		{
			ImageDetailViewController *imageDetail = [[ImageDetailViewController alloc] initWithCategoryId:self.categoryId atImageIndex:indexPath.row isSorted:(self.currentSortCategory != 0) withArray:[self.imageList copy]];
			imageDetail.imgDetailDelegate = self;
			[self.navigationController pushViewController:imageDetail animated:YES];
		}
		else
		{
			if(![self.selectedImageIds containsObject:selectedCell.imageData.imageId]) {
				[self.selectedImageIds addObject:selectedCell.imageData.imageId];
				selectedCell.isSelected = YES;
			} else {
				selectedCell.isSelected = NO;
				[self.selectedImageIds removeObject:selectedCell.imageData.imageId];
			}
			[collectionView reloadItemsAtIndexPaths:@[indexPath]];
		}
	}
}

#pragma mark -- ImageDetailDelegate Methods

-(void)didDeleteImage:(PiwigoImageData *)image
{
	NSIndexSet *set = [self.imageList indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
		return [obj.imageId integerValue] != [image.imageId integerValue];
	}];
	self.imageList = [self.imageList objectsAtIndexes:set];
	
	NSMutableArray *newList = [[NSMutableArray alloc] initWithArray:self.imageList];
	[newList removeObject:self.selectedImageIds.lastObject];
	self.imageList = newList;
	
	[self.imagesCollection reloadData];
}

-(void)needToLoadMoreImages
{
	[self loadMoreImages];
}


#pragma mark CategorySortDelegate Methods

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType
{
	self.currentSortCategory = sortType;
}

#pragma mark CategoryCollectionViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
	[self.navigationController pushViewController:viewController animated:YES];
}

@end
