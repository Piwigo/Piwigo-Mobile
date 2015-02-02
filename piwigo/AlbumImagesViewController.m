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

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImageDetailDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) NSString *categoryId;

@property (nonatomic, assign) NSInteger lastImageBulkCount;
@property (nonatomic, assign) NSInteger onPage;
@property (nonatomic, assign) BOOL isLoadingMoreImages;
@property (nonatomic, assign) BOOL didLoadAllImages;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) BOOL isDeleting;
@property (nonatomic, assign) NSInteger startDeleteTotalImages;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;

@end

@implementation AlbumImagesViewController

-(instancetype)initWithAlbumId:(NSString*)albumId
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categoryId = albumId;
		self.title = [[[CategoriesData sharedInstance].categories objectForKey:self.categoryId] name];
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
		
		self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImages)];
		self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImages)];
		self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.isSelect = NO;
		self.isDeleting = NO;
		self.startDeleteTotalImages = -1;
		self.selectedImageIds = [NSMutableArray new];
		
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
	if(!self.isSelect) {
		self.navigationItem.rightBarButtonItems = @[self.selectBarButton];
	} else {
		self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.downloadBarButton, self.deleteBarButton];
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
	self.title = [[[CategoriesData sharedInstance].categories objectForKey:self.categoryId] name];
	for(ImageCollectionViewCell *cell in self.imagesCollection.visibleCells) {
		if(cell.isSelected) cell.isSelected = NO;
	}
	self.selectedImageIds = [NSMutableArray new];
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
							  [self deleteSelected];
						  }
					  }];
}

-(void)deleteSelected
{
	if(self.selectedImageIds.count <= 0)
	{
		self.isDeleting = NO;
		self.startDeleteTotalImages = -1;
		[self cancelSelect];
		return;
	}
	
	if(self.startDeleteTotalImages == -1) self.startDeleteTotalImages = self.selectedImageIds.count;
	
	self.isDeleting = YES;
	self.navigationItem.rightBarButtonItems = @[self.cancelBarButton];
	[ImageService deleteImage:[[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject]
				 ListOnCompletion:^(AFHTTPRequestOperation *operation) {
					 [self.selectedImageIds removeLastObject];
					 NSInteger percentDone = ((CGFloat)(self.startDeleteTotalImages - self.selectedImageIds.count) / self.startDeleteTotalImages) * 100;
					 self.title = [NSString stringWithFormat:NSLocalizedString(@"deleteImageProgress_title", @"Deleting %@%% Done"), @(percentDone)];
					 [self.imagesCollection reloadData];
					 [self deleteSelected];
				 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					 self.isDeleting = NO;
					 [UIAlertView showWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
										message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), error.description]
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
	[self downloadImage];
	
}

-(void)downloadImage
{
	if(self.selectedImageIds.count <= 0)
	{
		//		self.isDeleting = NO;
		//		self.startDeleteTotalImages = -1;
		[self cancelSelect];
		return;
	}
	
	self.navigationItem.rightBarButtonItems = @[self.cancelBarButton];
	[ImageService downloadImage:[[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject]
					 onProgress:^(NSInteger current, NSInteger total) {
						 //
					 } ListOnCompletion:^(AFHTTPRequestOperation *operation, UIImage *image) {
						 [self.selectedImageIds removeLastObject];
//						 NSInteger percentDone = ((CGFloat)(self.startDeleteTotalImages - self.selectedImageIds.count) / self.startDeleteTotalImages) * 100;
//						 self.title = [NSString stringWithFormat:NSLocalizedString(@"deleteImageProgress_title", @"Deleting %@%% Done"), @(percentDone)];
						 [self.imagesCollection reloadData];
						 [self downloadImage];
						 NSLog(@"downlaod complete");
					 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						 NSLog(@"download fail");
					 }];
}

-(void)loadImageChunk
{
	if(self.isLoadingMoreImages) return;
	
	self.isLoadingMoreImages = YES;
	
	[ImageService loadImageChunkForLastChunkCount:self.lastImageBulkCount
									  forCategory:self.categoryId
										   onPage:self.onPage
								 ListOnCompletion:^(AFHTTPRequestOperation *operation, NSInteger count) {
									 
									 self.lastImageBulkCount = count;
									 self.onPage++;
									 self.isLoadingMoreImages = NO;
									 [self.imagesCollection reloadData];
								 } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
									 
									 
									 self.isLoadingMoreImages = NO;
								 }];
}

#pragma mark -- UICollectionView Methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [[[CategoriesData sharedInstance].categories objectForKey:self.categoryId] imageList].count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CGFloat size = MIN(collectionView.frame.size.width, collectionView.frame.size.height) / 3 - 14;
	return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	PiwigoImageData *imageData = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andIndex:indexPath.row];
	[cell setupWithImageData:imageData];
	
	if([self.selectedImageIds containsObject:imageData.imageId]) {
		cell.isSelected = YES;
	}
	
	return cell;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
	return UIEdgeInsetsMake(10, 10, 10, 10);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	if(!self.isSelect)
	{
		ImageDetailViewController *imageDetail = [[ImageDetailViewController alloc] initWithCategoryId:self.categoryId andImageIndex:indexPath.row];
		imageDetail.delegate = self;
		[imageDetail setupWithImageData:selectedCell.imageData andPlaceHolderImage:selectedCell.cellImage.image];
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

-(void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.row >= [collectionView numberOfItemsInSection:0] - 21)
	{
		[self loadImageChunk];
	}
}

#pragma mark -- ImageDetailDelegate Methods

-(void)didDeleteImage
{
	[self.imagesCollection reloadData];
}

@end
