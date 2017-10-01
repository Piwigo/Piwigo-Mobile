//
//  AlbumImagesViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>
#import <AFNetworking/AFImageDownloader.h>

#import "AlbumImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageService.h"
#import "CategoriesData.h"
#import "Model.h"
#import "ImageDetailViewController.h"
#import "ImageDownloadView.h"
#import "SortHeaderCollectionReusableView.h"
#import "CategorySortViewController.h"
#import "CategoryImageSort.h"
#import "LoadingView.h"
#import "UICountingLabel.h"
#import "CategoryCollectionViewCell.h"
#import "AlbumService.h"
#import "LocalAlbumsViewController.h"
#import "AlbumData.h"
#import "NetworkHandler.h"
#import "ImagesCollection.h"


@interface AlbumImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ImageDetailDelegate, CategorySortDelegate, CategoryCollectionViewCellDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSString *currentSort;

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

@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

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
		
		self.albumData = [[AlbumData alloc] initWithCategoryId:self.categoryId];
		self.currentSortCategory = [Model sharedInstance].defaultSort;
		
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
								 OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
									 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
								 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                        NSLog(@"getAlbumListForCategory error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                    }];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated) name:kPiwigoNotificationCategoryDataUpdated object:nil];
		
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self loadNavButtons];
	
	// Albums
    if([[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count > 0)
	{
		[self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
	}
    
    // Photos
    [self.albumData reloadAlbumOnCompletion:^{
        [self.imagesCollection reloadData];
    }];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	refreshControl.backgroundColor = [UIColor piwigoOrange];
	refreshControl.tintColor = [UIColor piwigoGray];
	refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pullToRefresh", @"Loading All Images")];
	[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.imagesCollection.refreshControl = refreshControl;
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.imagesCollection reloadData];
        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
    } completion:nil];
}

-(void)refresh:(UIRefreshControl*)refreshControl
{
    [self.albumData loadAllImagesOnCompletion:^{
        [refreshControl endRefreshing];
        [self.imagesCollection reloadData];
    }];

    [AlbumService getAlbumListForCategory:self.categoryId
                             OnCompletion:^(NSURLSessionTask *task, NSArray *albums) {
                                 [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                             } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                 NSLog(@"refresh fail");
#endif
                             }];
}

-(void)categoriesUpdated
{
	[self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
}

-(void)loadNavButtons
{
	if(!self.isSelect) {
        // Selection mode not active
        if([Model sharedInstance].hasAdminRights || [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] hasUploadRights]) {
            [self.navigationItem setRightBarButtonItems:@[self.selectBarButton, self.uploadBarButton] animated:YES];
        } else {
            [self.navigationItem setRightBarButtonItems:@[self.selectBarButton] animated:YES];
        }
	} else {
        // Selection mode active (only amdins have delete rights)
        if([Model sharedInstance].hasAdminRights)
		{
            if (self.selectedImageIds.count > 0) {
                [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton, self.downloadBarButton, self.deleteBarButton] animated:YES];
            } else {
                [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
            }
		}
		else
		{
            if (self.selectedImageIds.count > 0) {
                [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton, self.downloadBarButton] animated:YES];
            } else {
                [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
            }
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
	LocalAlbumsViewController *localAlbums = [[LocalAlbumsViewController alloc] initWithCategoryId:self.categoryId];
	[self.navigationController pushViewController:localAlbums animated:YES];
}

-(void)deleteImages
{
	if(self.selectedImageIds.count <= 0) return;
	
    // Do we really want to delete these images?
    NSString *titleString, *messageString;
    if (self.selectedImageIds.count > 1) {
        titleString = NSLocalizedString(@"deleteSeveralImages_title", @"Delete Images");
        messageString = [NSString stringWithFormat:NSLocalizedString(@"deleteSeveralImages_message", @"Are you sure you want to delete the selected %@ images?"), @(self.selectedImageIds.count)];
    } else {
        titleString = NSLocalizedString(@"deleteSingleImage_title", @"Delete Image");
        messageString = NSLocalizedString(@"deleteSingleImage_message", @"Are you sure you want to delete this image?");
    }
    
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:titleString
                                message:messageString
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                   style:UIAlertActionStyleDestructive
                                   handler:^(UIAlertAction * action) {
                                       self.startDeleteTotalImages = self.selectedImageIds.count;
                                       [self deleteSelected];
                                   }];
    
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)deleteSelected
{
	if(self.selectedImageIds.count <= 0)
	{
		[self cancelSelect];
		return;
	}
	
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
    
    // Image data are not always available —> Load them
    [ImageService getImageInfoById:[self.selectedImageIds.lastObject integerValue]
     
              ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {

                  // Let's delete the image
                  [ImageService deleteImage:imageData ListOnCompletion:^(NSURLSessionTask *task) {
                      
                      [self.albumData removeImageWithId:[self.selectedImageIds.lastObject integerValue]];
                      
                      [self.selectedImageIds removeLastObject];
                      NSInteger percentDone = ((CGFloat)(self.startDeleteTotalImages - self.selectedImageIds.count) / self.startDeleteTotalImages) * 100;
                      self.title = [NSString stringWithFormat:NSLocalizedString(@"deleteImageProgress_title", @"Deleting %@%% Done"), @(percentDone)];
                      [self.imagesCollection reloadData];
                      [self deleteSelected];
                  } onFailure:^(NSURLSessionTask *task, NSError *error) {
                      // Error — Try again ?
                      UIAlertController* alert = [UIAlertController
                                  alertControllerWithTitle:NSLocalizedString(@"deleteImageFail_title", @"Delete Failed")
                                  message:[NSString stringWithFormat:NSLocalizedString(@"deleteImageFail_message", @"Image could not be deleted\n%@"), [error localizedDescription]]
                                  preferredStyle:UIAlertControllerStyleAlert];
                      
                      UIAlertAction* dismissAction = [UIAlertAction
                                  actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * action) {}];
                      
                      UIAlertAction* retryAction = [UIAlertAction
                                  actionWithTitle:NSLocalizedString(@"alertTryAgainButton", @"Try Again")
                                  style:UIAlertActionStyleDestructive
                                  handler:^(UIAlertAction * action) {
                                      [self deleteSelected];
                                  }];
                      
                      [alert addAction:dismissAction];
                      [alert addAction:retryAction];
                      [self presentViewController:alert animated:YES completion:nil];
                  }];

              } onFailure:^(NSURLSessionTask *task, NSError *error) {
                  // Error encountered when retrieving image infos
                  UIAlertController* alert = [UIAlertController
                              alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
                              message:NSLocalizedString(@"imageDetailsFetchError_continueMessage", @"Fetching the image data failed\nNContinue?")
                              preferredStyle:UIAlertControllerStyleAlert];
                  
                  UIAlertAction* cancelAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                              style:UIAlertActionStyleCancel
                              handler:^(UIAlertAction * action) {}];
                  
                  UIAlertAction* continueAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                              style:UIAlertActionStyleDestructive
                              handler:^(UIAlertAction * action) {
                                  [self deleteSelected];
                              }];
                  
                  [alert addAction:cancelAction];
                  [alert addAction:continueAction];
                  [self presentViewController:alert animated:YES completion:nil];
              }
     ];
}

-(void)downloadImages
{
	if(self.selectedImageIds.count <= 0) return;
	
    // Check access to Photos — Required as system does not always ask
    if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
        // Request authorization to access photos
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            // Nothing to do…
        }];
    }
    else if(([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) ||
            ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted)) {
        // Inform user that he/she denied or restricted access to photos
        UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"localAlbums_photosNotAuthorized_title", @"No Access")
                                    message:NSLocalizedString(@"localAlbums_photosNotAuthorized_msg", @"tell user to change settings, how")
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* dismissAction = [UIAlertAction
                                        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss") style:UIAlertActionStyleCancel
                                        handler:^(UIAlertAction * action) {}];
        
        [alert addAction:dismissAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Do we really want to download these images?
    NSString *titleString, *messageString;
    if (self.selectedImageIds.count > 1) {
        titleString = NSLocalizedString(@"downloadSeveralImages_title", @"Download Images");
        messageString = [NSString stringWithFormat:NSLocalizedString(@"downloadSeveralImage_confirmation", @"Are you sure you want to download the selected %@ images?"), @(self.selectedImageIds.count)];
    } else {
        titleString = NSLocalizedString(@"downloadSingleImage_title", @"Download Image");
        messageString = NSLocalizedString(@"downloadSingleImage_confirmation", @"Are you sure you want to download the selected image?");
    }
    
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:titleString
                                message:messageString
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* deleteAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                                       self.totalImagesToDownload = self.selectedImageIds.count;
                                       [self downloadImage];
                                   }];
    
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    [self presentViewController:alert animated:YES completion:nil];
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
    [self.navigationItem setRightBarButtonItems:@[self.cancelBarButton] animated:YES];
	
	PiwigoImageData *downloadingImage = [[CategoriesData sharedInstance] getImageForCategory:self.categoryId andId:self.selectedImageIds.lastObject];
	
	UIImageView *dummyView = [UIImageView new];
	__weak typeof(self) weakSelf = self;
    NSString *URLRequest = [NetworkHandler getURLWithPath:downloadingImage.ThumbPath asPiwigoRequest:NO withURLParams:nil];

    // Ensure that SSL certificates won't be rejected
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    
    AFImageDownloader *dow = [AFImageDownloader defaultInstance];
    [dow.sessionManager setSecurityPolicy:policy];

    [dummyView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]]
					 placeholderImage:[UIImage imageNamed:@"placeholderImage"]
							  success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								  weakSelf.downloadView.downloadImage = image;
							  } failure:nil];
	
    if(!downloadingImage.isVideo)
	{
		[ImageService downloadImage:downloadingImage
                         onProgress:^(NSProgress *progress) {
                              dispatch_async(dispatch_get_main_queue(),
                                             ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;});
						 } ListOnCompletion:^(NSURLSessionTask *task, UIImage *image) {
							 [self saveImageToCameraRoll:image];
						 } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
							 NSLog(@"downloadVideo fail");
#endif
                         }];
	}
	else
	{
        [ImageService downloadVideo:downloadingImage
                         onProgress:^(NSProgress *progress) {
                             dispatch_async(dispatch_get_main_queue(),
                                            ^(void){self.downloadView.percentDownloaded = progress.fractionCompleted;}
                                            );
                         }
                  completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                      // Any error ?
                      if (!error.code) {
#if defined(DEBUG)
                          NSLog(@"AlbumImagesViewController: downloadImage fail");
#endif
                      } else {
                          // Try to move video in Photos.app
#if defined(DEBUG)
                          NSLog(@"path= %@", filePath.path);
#endif
                          if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath.path)) {
                              UISaveVideoAtPathToSavedPhotosAlbum(filePath.path, self, @selector(movie:didFinishSavingWithError:contextInfo:), nil);
                          } else {
                              UIAlertController* alert = [UIAlertController
                                      alertControllerWithTitle:NSLocalizedString(@"downloadImageFail_title", @"Download Fail")
                                      message:[NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), NSLocalizedString(@"downloadVideoFail_Photos", @"Video format not accepted by Photos!")]
                                      preferredStyle:UIAlertControllerStyleAlert];
                              
                              UIAlertAction* dismissAction = [UIAlertAction
                                      actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                      style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * action) {}];
                              
                              [alert addAction:dismissAction];
                              [self presentViewController:alert animated:YES completion:nil];
                          }
                      }
                  }
         ];
        
        self.downloadView.hidden = NO;

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
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image")
                    message:[NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), [error localizedDescription]]
                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* dismissAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [self cancelSelect];
                    }];
        
        [alert addAction:dismissAction];
        [self presentViewController:alert animated:YES completion:nil];
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
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:NSLocalizedString(@"videoSaveError_title", @"Fail Saving Video")
                    message:[NSString stringWithFormat:NSLocalizedString(@"videoSaveError_message", @"Failed to save video. Error: %@"), [error localizedDescription]]
                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* dismissAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [self cancelSelect];
                    }];
        
        [alert addAction:dismissAction];
        [self presentViewController:alert animated:YES completion:nil];
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

-(void)setCurrentSortCategory:(kPiwigoSortCategory)currentSortCategory
{
	_currentSortCategory = currentSortCategory;
	[self.albumData updateImageSort:currentSortCategory OnCompletion:^{
		[self.imagesCollection reloadData];
	}];
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

            if (!self.albumData.images.count) {
                self.noImagesLabel = [UILabel new];
                self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
                self.noImagesLabel.font = [UIFont piwigoFontNormal];
                self.noImagesLabel.font = [self.noImagesLabel.font fontWithSize:20];
                self.noImagesLabel.textColor = [UIColor piwigoWhiteCream];
                self.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");

                [header addSubview:self.noImagesLabel];
                [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.noImagesLabel amount:-40]];
                [header addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
            }

            return header;
		}
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
		return CGSizeMake(collectionView.frame.size.width, 34.0);
	}
	
	return CGSizeZero;
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
	return 2;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	self.noImagesLabel.hidden = self.albumData.images.count != 0;
	
	if(section == 1)
	{
		return self.albumData.images.count;
	}
	else
	{
		return [[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId].count;
	}
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10, kMarginsSpacing, 40, kMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 1)
	{
        // Calculate the optimum image size
        CGFloat size = (CGFloat)[ImagesCollection imageSizeForCollectionView:collectionView];
        return CGSizeMake(size, size);                                      // Thumbnails
	}
	else
	{
		return CGSizeMake(collectionView.frame.size.width - 20, 188);       // Albums
	}
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)      // Image thumbnails
	{
		ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
		
		if(self.albumData.images.count >= indexPath.row) {
			PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
			[cell setupWithImageData:imageData];
			
			if([self.selectedImageIds containsObject:imageData.imageId])
			{
				cell.isSelected = YES;
			}
		}
		
        // Calculate the number of thumbnails displayed on screen
        NSInteger imagesPerScreen = [ImagesCollection numberOfImagesPerScreenForCollectionView:collectionView];

        // Load images in advance if possible
        if((indexPath.row >= [collectionView numberOfItemsInSection:1] - imagesPerScreen) && (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] numberOfImages]))
		{
			[self.albumData loadMoreImagesOnCompletion:^{
				[self.imagesCollection reloadData];
			}];
		}
		
		return cell;
	}
	else        // Albums
	{
		CategoryCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
		cell.categoryDelegate = self;
		
		PiwigoAlbumData *albumData = [[[CategoriesData sharedInstance] getCategoriesForParentCategory:self.categoryId] objectAtIndex:indexPath.row];
		
		[cell setupWithAlbumData:albumData];
		
		return cell;
	}
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 1)
	{
		ImageCollectionViewCell *selectedCell = (ImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
        
        // Avoid rare crashes…
        if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) {
            // forget this call!
            return;
        }
		
        // Action depends on mode
        if(!self.isSelect)
		{
			// Selection mode not active => display full screen image
            self.imageDetailView = [[ImageDetailViewController alloc] initWithCategoryId:self.categoryId atImageIndex:indexPath.row withArray:[self.albumData.images copy]];
			self.imageDetailView.hidesBottomBarWhenPushed = YES;
			self.imageDetailView.imgDetailDelegate = self;
			[self.navigationController pushViewController:self.imageDetailView animated:YES];
		}
		else
		{
			// Selection mode active => add image to selection
            if(![self.selectedImageIds containsObject:selectedCell.imageData.imageId]) {
				[self.selectedImageIds addObject:selectedCell.imageData.imageId];
				selectedCell.isSelected = YES;
			} else {
				selectedCell.isSelected = NO;
				[self.selectedImageIds removeObject:selectedCell.imageData.imageId];
			}
			[collectionView reloadItemsAtIndexPaths:@[indexPath]];

            // and display nav buttons
            [self select];
        }
	}
}

#pragma mark -- ImageDetailDelegate Methods

-(void)didDeleteImage:(PiwigoImageData *)image
{
	[self.albumData removeImage:image];
	[self.imagesCollection reloadData];
}

-(void)needToLoadMoreImages
{
	[self.albumData loadMoreImagesOnCompletion:^{
		if(self.imageDetailView != nil)
		{
			self.imageDetailView.images = self.albumData.images;
		}
		[self.imagesCollection reloadData];
	}];
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
