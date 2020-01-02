//
//  EditImageThumbTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

#import "EditImageThumbTableViewCell.h"
#import "EditImageThumbCollectionViewCell.h"
#import "ImagesCollection.h"

NSString * const kEditImageThumbTableCell_ID = @"EditImageThumbTableCell";

@interface EditImageThumbTableViewCell() <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, EditImageThumbnailDelegate>

@property (nonatomic, strong) NSArray<PiwigoImageData *> *images;
@property (nonatomic, strong) IBOutlet UICollectionView *editImageThumbCollectionView;
@property (nonatomic, assign) CGPoint startingScrollingOffset;

@end

@implementation EditImageThumbTableViewCell

-(void)awakeFromNib
{
    [super awakeFromNib];

    // Register thumbnail collection view cell
    [self.editImageThumbCollectionView registerNib:[UINib nibWithNibName:@"EditImageThumbCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:kEditImageThumbCollectionCell_ID];
}

-(void)setupWithImages:(NSArray<PiwigoImageData *> *)imageSelection
{
    // Data
    self.images = imageSelection;
    
    // Collection of images
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    if (self.editImageThumbCollectionView == nil) {
        self.editImageThumbCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
        [self.editImageThumbCollectionView reloadData];
    } else {
        [self.editImageThumbCollectionView.collectionViewLayout invalidateLayout];
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
    EditImageThumbCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kEditImageThumbCollectionCell_ID forIndexPath:indexPath];
    [cell setupWithImage:self.images[indexPath.row] removeOption:(self.images.count > 1)];
    cell.delegate = self;
    return cell;
}


#pragma mark - UICollectionViewDelegateFlowLayout Methods

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if (@available(iOS 13.0, *)) {
        return UIEdgeInsetsMake(0, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    } else {
        return UIEdgeInsetsMake(10, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageDetailsCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake([ImagesCollection imageDetailsSizeForView:self], 144);
}


#pragma mark - EditImageThumbnailDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Update data source
    NSMutableArray *newImages = [[NSMutableArray alloc] initWithArray:self.images];
    for (PiwigoImageData *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            [newImages removeObject:imageData];
        }
    }
    self.images = newImages;
    [self.editImageThumbCollectionView reloadData];

    // Deselect image in parent view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageWithId:)])
    {
        [self.delegate didDeselectImageWithId:imageId];
    }
}

-(void)didRenameFileOfImageWithId:(NSInteger)imageId andFilename:(NSString *)fileName
{
    // Update data source
    PiwigoImageData *updatedImage;
    NSMutableArray *updatedImages = [[NSMutableArray alloc] init];
    for (PiwigoImageData *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            if (fileName) imageData.fileName = fileName;
            updatedImage = imageData;
        }
        [updatedImages addObject:imageData];
    }
    self.images = updatedImages;
    
    // Update parent image view
    if ([self.delegate respondsToSelector:@selector(didRenameFileOfImage:)])
    {
        [self.delegate didRenameFileOfImage:updatedImage];
    }
}


#pragma mark - ScrollView Manager
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.startingScrollingOffset = scrollView.contentOffset;
}

-(void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    CGFloat cellWidth = [self collectionView:self.editImageThumbCollectionView layout:self.editImageThumbCollectionView.collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].width + kImageDetailsMarginsSpacing/2.0;
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
