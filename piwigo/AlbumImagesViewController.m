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

@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImageDetailDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, assign) NSInteger categoryId;

@property (nonatomic, strong) UIBarButtonItem *selectBarButton;
@property (nonatomic, strong) UIBarButtonItem *deleteBarButton;
@property (nonatomic, strong) UIBarButtonItem *downloadBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, assign) BOOL isSelect;
@property (nonatomic, assign) NSInteger startDeleteTotalImages;
@property (nonatomic, assign) NSInteger totalImagesToDownload;
@property (nonatomic, strong) NSMutableArray *selectedImageIds;
@property (nonatomic, strong) ImageDownloadView *downloadView;

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
		
		self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.imagesCollection.backgroundColor = [UIColor clearColor];
		self.imagesCollection.dataSource = self;
		self.imagesCollection.delegate = self;
		[self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		self.imagesCollection.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		[self.view addSubview:self.imagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
		
		[[[CategoriesData sharedInstance] getCategoryById:albumId] loadCategoryImageDataChunkOnCompletion:^(BOOL completed) {
			[self.imagesCollection reloadData];
		}];
		
		self.selectBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"categoryImageList_selectButton", @"Select") style:UIBarButtonItemStylePlain target:self action:@selector(select)];
		self.deleteBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteImages)];
		self.downloadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"download"] style:UIBarButtonItemStylePlain target:self action:@selector(downloadImages)];
		self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.isSelect = NO;
		self.selectedImageIds = [NSMutableArray new];
		
		self.downloadView.hidden = YES;
		
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
	self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
	for(ImageCollectionViewCell *cell in self.imagesCollection.visibleCells) {
		if(cell.isSelected) cell.isSelected = NO;
	}
	self.downloadView.hidden = YES;
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
	
	self.navigationItem.rightBarButtonItems = @[self.cancelBarButton];
	[ImageService deleteImage:[[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject]
				 ListOnCompletion:^(AFHTTPRequestOperation *operation) {
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

-(ImageDownloadView*)downloadView
{
	if(_downloadView) return _downloadView;
	
	_downloadView = [ImageDownloadView new];
	_downloadView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_downloadView];
	[self.view addConstraints:[NSLayoutConstraint constraintFillSize:_downloadView]];
	return _downloadView;
}

#pragma mark -- UICollectionView Methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return [[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count;
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
	
	if([self.selectedImageIds containsObject:imageData.imageId])
	{
		cell.isSelected = YES;
	}
	
	if([[CategoriesData sharedInstance] getCategoryById:self.categoryId].imageList.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages] && indexPath.row >= [collectionView numberOfItemsInSection:0] - 21)
	{
		[[[CategoriesData sharedInstance] getCategoryById:self.categoryId] loadCategoryImageDataChunkOnCompletion:^(BOOL completed) {
			[self.imagesCollection reloadData];
		}];
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

#pragma mark -- ImageDetailDelegate Methods

-(void)didDeleteImage
{
	[self.imagesCollection reloadData];
}

@end
