//
//  ImageUploadThumbTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

#import "ImageUploadThumbTableViewCell.h"
#import "ImageUploadThumbCollectionViewCell.h"
#import "ImagesCollection.h"

NSString * const kImageUploadThumbTableCell_ID = @"ImageUploadThumbTableCell";

@interface ImageUploadThumbTableViewCell() <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, ImageUploadThumbnailDelegate>

@property (nonatomic, strong) NSArray<ImageUpload *> *images;
@property (nonatomic, strong) IBOutlet UICollectionView *imageUploadThumbCollectionView;
@property (nonatomic, assign) CGPoint startingScrollingOffset;

@end

@implementation ImageUploadThumbTableViewCell

-(void)awakeFromNib
{
    [super awakeFromNib];

    // Register thumbnail collection view cell
    [self.imageUploadThumbCollectionView registerNib:[UINib nibWithNibName:@"ImageUploadThumbCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:kImageUploadThumbCollectionCell_ID];
}

-(void)setupWithImages:(NSArray<ImageUpload *> *)imageSelection
{
    // Data
    self.images = imageSelection;
    
    // Collection of images
    self.backgroundColor = [UIColor piwigoColorCellBackground];
    if (self.imageUploadThumbCollectionView == nil) {
        self.imageUploadThumbCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
        [self.imageUploadThumbCollectionView reloadData];
    } else {
        [self.imageUploadThumbCollectionView.collectionViewLayout invalidateLayout];
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
}


#pragma mark - UICollectionViewDataSource Methods

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images or albums
    return self.images.count;
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ImageUploadThumbCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kImageUploadThumbCollectionCell_ID forIndexPath:indexPath];
    [cell setupWithImage:self.images[indexPath.row] andRemoveOption:(self.images.count > 1)];
    cell.delegate = self;
    return cell;
}


#pragma mark - UICollectionViewDelegateFlowLayout Methods

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    return UIEdgeInsetsMake(0, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageDetailsCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake([ImagesCollection imageDetailsSizeForView:self], 152);
}


#pragma mark - ImageUploadThumbnailDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Update data source
    NSMutableArray *newImages = [[NSMutableArray alloc] initWithArray:self.images];
    for (ImageUpload *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            [newImages removeObject:imageData];
        }
    }
    self.images = newImages;
    [self.imageUploadThumbCollectionView reloadData];

    // Deselect image in parent view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageWithId:)])
    {
        [self.delegate didDeselectImageWithId:imageId];
    }
}


#pragma mark - ScrollView Manager

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.startingScrollingOffset = scrollView.contentOffset;
}

-(void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    CGFloat cellWidth = [self collectionView:self.imageUploadThumbCollectionView layout:self.imageUploadThumbCollectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].width + kImageDetailsMarginsSpacing/2.0;
    double offset = scrollView.contentOffset.x + scrollView.contentInset.left;
    double proposedPage = offset / fmax(1.0, cellWidth);
    CGFloat snapPoint = 0.1;
    CGFloat snapDelta = offset > self.startingScrollingOffset.x ? (1 - snapPoint) : snapPoint;

    double page;
    if (floor(proposedPage + snapDelta) == floor(proposedPage)) {
        page = floor(proposedPage);
    }
    else {
        page = floor(proposedPage + 1);
    }

    *targetContentOffset = CGPointMake(cellWidth * page, (*targetContentOffset).y);
}

@end
