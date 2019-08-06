//
//  TaggedImagesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "AlbumData.h"
#import "AlbumService.h"
#import "AppDelegate.h"
#import "CategoriesData.h"
#import "DiscoverImagesViewController.h"
#import "ImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "ImagesCollection.h"
#import "Model.h"
#import "NberImagesFooterCollectionReusableView.h"
#import "TaggedImagesViewController.h"
#import "TagSelectViewController.h"

@interface TaggedImagesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, ImageDetailDelegate>

@property (nonatomic, strong) UICollectionView *imagesCollection;
@property (nonatomic, assign) NSInteger tagId;
@property (nonatomic, strong) NSString *tagName;
@property (nonatomic, strong) AlbumData *albumData;
@property (nonatomic, strong) NSIndexPath *imageOfInterest;
@property (nonatomic, assign) BOOL displayImageTitles;

@property (nonatomic, strong) UIBarButtonItem *tagSelectBarButton;

@property (nonatomic, assign) kPiwigoSortCategory currentSortCategory;
@property (nonatomic, strong) ImageDetailViewController *imageDetailView;

@end

@implementation TaggedImagesViewController

-(instancetype)initWithTagId:(NSInteger)tagId andTagName:(NSString *)tagName
{
    self = [super init];
    if(self)
    {
        self.tagId = tagId;
        self.tagName = tagName;
        self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
        
        self.albumData = [[AlbumData alloc] initWithCategoryId:kPiwigoTagsCategoryId andQuery:@""];
        self.currentSortCategory = [Model sharedInstance].defaultSort;
        self.displayImageTitles = [Model sharedInstance].displayImageTitles;
        
        // Collection of images
        self.imagesCollection = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:[UICollectionViewFlowLayout new]];
        self.imagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
        self.imagesCollection.alwaysBounceVertical = YES;
        self.imagesCollection.showsVerticalScrollIndicator = YES;
        self.imagesCollection.dataSource = self;
        self.imagesCollection.delegate = self;
        
        [self.imagesCollection registerClass:[ImageCollectionViewCell class] forCellWithReuseIdentifier:@"ImageCollectionViewCell"];
        [self.imagesCollection registerClass:[NberImagesFooterCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection"];
        
        [self.view addSubview:self.imagesCollection];
        [self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.imagesCollection]];
        if (@available(iOS 11.0, *)) {
            [self.imagesCollection setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentAlways];
        } else {
            // Fallback on earlier versions
        }

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    self.imagesCollection.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ?UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;

    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;

    // Collection view
    self.imagesCollection.backgroundColor = [UIColor piwigoBackgroundColor];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self paletteChanged];
    
    // Title
    self.title = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"tag" , @"Tag"), self.tagName];

    // Hide toolbar
    [self.navigationController setToolbarHidden:YES animated:YES];

    // Initialise discover cache
    PiwigoAlbumData *discoverAlbum = [[PiwigoAlbumData alloc] initDiscoverAlbumForCategory:kPiwigoTagsCategoryId];
    [[CategoriesData sharedInstance] updateCategories:@[discoverAlbum]];

    // Load, sort images and reload collection
    discoverAlbum.query = [NSString stringWithFormat:@"%ld", (long)self.tagId];
    [self.albumData updateImageSort:self.currentSortCategory OnCompletion:^{
        
        [self.imagesCollection reloadData];
    }];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Should we scroll to image of interest?
//    NSLog(@"••• Discover|Starting with %ld images", (long)[self.imagesCollection numberOfItemsInSection:0]);
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        
        // Thumbnail of interest is not the first one
        // => Scroll and highlight cell of interest
//        NSLog(@"=> Discover|Try to scroll to item=%ld", (long)self.imageOfInterest.item);
        
        // Thumbnail of interest already visible?
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Thumbnail is already visible and highlighted
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
                }];
            } else {
               self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
            }
        }
        else {
            // First visible thumbnail
            NSIndexPath *indexPathOfFirstVisibleThumbnail = [indexPathsForVisibleItems firstObject];
            
            // Thumbnail of interest above visible items?
            if (self.imageOfInterest.item < indexPathOfFirstVisibleThumbnail.item) {
                // Scroll up collection and highlight cell
//                NSLog(@"=> Discover|Scroll up to item #%ld", (long)self.imageOfInterest.item);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
            }
            
            // Thumbnail is below visible items
            // Get number of already loaded items
            NSInteger nberOfItems = [self.imagesCollection numberOfItemsInSection:0];
            if (self.imageOfInterest.item < nberOfItems) {
                // Already loaded => scroll to it
//                NSLog(@"=> Discover|Scroll down to item #%ld", (long)self.imageOfInterest.item);
                [self.imagesCollection scrollToItemAtIndexPath:self.imageOfInterest atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
                
                // Calculate the number of thumbnails displayed per page
                NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:self.imagesCollection andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
                
                // Load more images if seems to be a good idea
                if ((self.imageOfInterest.item > (nberOfItems - roundf(imagesPerPage / 3.0))) &&
                    (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId] numberOfImages])) {
//                    NSLog(@"=> Discover|Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                    }];
                }
            } else {
                // No yet loaded => load more images
                // Should not happen as needToLoadMoreImages() should be called when previewing images
                if (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId] numberOfImages]) {
//                    NSLog(@"=> Discover|Load more images…");
                    [self.albumData loadMoreImagesOnCompletion:^{
                        [self.imagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
                    }];
                }
            }
        }
    }
}

-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    
    // When returning from imageDetailView, highlight image (which should now be visible)
    if (([self.albumData.images count] > 0) && (self.imageOfInterest.item != 0)) {
        // Visible cells
//        NSLog(@"=> Discover|Did end scrolling with %ld images", (long)[self.imagesCollection numberOfItemsInSection:0]);
        NSArray<NSIndexPath *> *indexPathsForVisibleItems = [self.imagesCollection indexPathsForVisibleItems];
        if ([indexPathsForVisibleItems containsObject:self.imageOfInterest]) {
            // Get cell
            UICollectionViewCell *cell = [self.imagesCollection cellForItemAtIndexPath:self.imageOfInterest];
            if ([cell isKindOfClass:[ImageCollectionViewCell class]]) {
                // Highlight cell
                ImageCollectionViewCell *imageCell = (ImageCollectionViewCell *)cell;
                [imageCell highlightOnCompletion:^{
                    // Apply effect when returning from image preview mode
                    self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
                }];
            } else {
               self.imageOfInterest = [NSIndexPath indexPathForItem:0 inSection:0];
            }
        }
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Do not show album title in backButtonItem of child view to provide enough space for image title
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if(self.view.bounds.size.width <= 414) {     // i.e. smaller than iPhones 6,7 Plus screen width
        self.title = @"";
    }
}


#pragma mark - UICollectionView Headers & Footer

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if(kind == UICollectionElementKindSectionFooter)
    {
        // Display number of images
        NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].numberOfImages;
        NberImagesFooterCollectionReusableView *footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"NberImagesFooterCollection" forIndexPath:indexPath];
        footer.noImagesLabel.textColor = [UIColor piwigoHeaderColor];
        
        if (totalImageCount == 0) {
            // Display "No images"
            footer.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
            }
        else {
            // Display number of images…
            footer.noImagesLabel.text = [NSString stringWithFormat:@"%ld %@", (long)totalImageCount, (totalImageCount > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
        }

        return footer;
    }
    
    UICollectionReusableView *view = [[UICollectionReusableView alloc] initWithFrame:CGRectZero];
    return view;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if ([elementKind isEqualToString:UICollectionElementKindSectionHeader]) {
        view.layer.zPosition = 0;       // Below scroll indicator
        view.backgroundColor = [[UIColor piwigoBackgroundColor] colorWithAlphaComponent:0.75];
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    // Display number of images
    NSInteger totalImageCount = [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].numberOfImages;
    NSString *footer = @"";

    if (totalImageCount == 0) {
        // Display "No images"
        footer = NSLocalizedString(@"noImages", @"No Images");
    }
    else {
        // Display number of images…
        footer = [NSString stringWithFormat:@"%ld %@", (long)totalImageCount, (totalImageCount > 1) ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
    }

    if ([footer length] > 0) {
        NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontLight]};
        NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
        context.minimumScaleFactor = 1.0;
        CGRect footerRect = [footer boundingRectWithSize:CGSizeMake(collectionView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:attributes
                                                 context:context];
        return CGSizeMake(collectionView.frame.size.width - 30.0, ceil(footerRect.size.height));
    }
    
    return CGSizeZero;
}


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images
//    NSLog(@"items: %ld", [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].imageList.count);
//    NSLog(@"items: %ld", self.albumData.images.count);
    return [[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId].imageList.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if (section == 0) {
        return UIEdgeInsetsMake(0, kImageMarginsSpacing, 0, kImageMarginsSpacing);
    } else {
        return UIEdgeInsetsMake(10, kImageMarginsSpacing, 10, kImageMarginsSpacing);
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (CGFloat)kImageCellSpacing4iPhone;
    } else {
        return (CGFloat)kImageCellVertSpacing4iPad;
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (CGFloat)kImageCellSpacing4iPhone;
    } else {
        return (CGFloat)kImageCellHorSpacing4iPad;
    }
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ImageCollectionViewCell" forIndexPath:indexPath];
    
    if (self.albumData.images.count > indexPath.row) {
        // Create cell from Piwigo data
        PiwigoImageData *imageData = [self.albumData.images objectAtIndex:indexPath.row];
        [cell setupWithImageData:imageData forCategoryId:kPiwigoTagsCategoryId];
    }
    
    // Calculate the number of thumbnails displayed per page
    NSInteger imagesPerPage = [ImagesCollection numberOfImagesPerPageForView:collectionView andNberOfImagesPerRowInPortrait:[Model sharedInstance].thumbnailsPerRowInPortrait];
    
    // Load image data in advance if possible (page after page…)
    if ((indexPath.row > fmaxf(roundf(2 * imagesPerPage / 3.0), [collectionView numberOfItemsInSection:0] - roundf(imagesPerPage / 3.0))) &&
        (self.albumData.images.count != [[[CategoriesData sharedInstance] getCategoryById:kPiwigoTagsCategoryId] numberOfImages]))
    {
        [self.albumData loadMoreImagesOnCompletion:^{
            [self.imagesCollection reloadData];
        }];
    }
    
    return cell;
}


#pragma mark - UICollectionViewDelegate Methods

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Avoid rare crashes…
    if ((indexPath.row < 0) || (indexPath.row >= [self.albumData.images count])) {
        // forget this call!
        return;
    }

    // Display full screen image
    self.imageDetailView = [[ImageDetailViewController alloc] initWithCategoryId:kPiwigoTagsCategoryId atImageIndex:indexPath.row withArray:[self.albumData.images copy]];
    self.imageDetailView.hidesBottomBarWhenPushed = YES;
    self.imageDetailView.imgDetailDelegate = self;
    [self.navigationController pushViewController:self.imageDetailView animated:YES];
}


#pragma mark - ImageDetailDelegate Methods

-(void)didFinishPreviewOfImageWithId:(NSInteger)imageId
{
    NSInteger index = 0;
    for (PiwigoImageData *image in self.albumData.images) {
        if (image.imageId == imageId) break;
        index++;
    }
    if (index < [self.albumData.images count])
        self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:0];
}

-(void)didDeleteImage:(PiwigoImageData *)image atIndex:(NSInteger)index
{
    [self.albumData removeImage:image];
    index = MAX(0, index-1);                                    // index must be > 0
    index = MIN(index, [self.albumData.images count] - 1);      // index must be < nber images
    self.imageOfInterest = [NSIndexPath indexPathForItem:index inSection:0];
    [self.imagesCollection reloadData];
}

-(void)needToLoadMoreImages
{
    [self.albumData loadMoreImagesOnCompletion:^{
        if(self.imageDetailView != nil)
        {
            self.imageDetailView.images = [self.albumData.images mutableCopy];
        }
        [self.imagesCollection reloadData];
    }];
}


@end
