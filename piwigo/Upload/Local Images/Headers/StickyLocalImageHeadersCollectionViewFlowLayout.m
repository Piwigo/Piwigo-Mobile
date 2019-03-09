//
//  StickyLocalImageHeadersCollectionViewFlowLayout.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 08/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
// See https://cocoacasts.com/how-to-add-sticky-section-headers-to-a-collection-view/
// See https://gist.github.com/toblerpwn/5393460

static NSString *kDecorationReuseIdentifier = @"sectionBackground";

#import "StickyLocalImageHeadersCollectionViewFlowLayout.h"

@implementation StickyLocalImageHeadersCollectionViewFlowLayout

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *layoutAttributes = [[super layoutAttributesForElementsInRect:rect] mutableCopy];
    if (layoutAttributes == nil) return nil;
    
    NSMutableIndexSet *sectionsToAdd = [NSMutableIndexSet indexSet];
    NSMutableArray<UICollectionViewLayoutAttributes *> *newLayoutAttributes = [NSMutableArray<UICollectionViewLayoutAttributes *> new];
    
    for (UICollectionViewLayoutAttributes *layoutAttributesSet in layoutAttributes)
    {
        if (layoutAttributesSet.representedElementCategory == UICollectionElementCategoryCell)
        {
            // Add layout attributes
            [newLayoutAttributes addObject:layoutAttributesSet];
            
            // Update sections to add
            [sectionsToAdd addIndex:layoutAttributesSet.indexPath.section];
        }
        else if (layoutAttributesSet.representedElementCategory == UICollectionElementCategorySupplementaryView)
        {
            // Update sections to add
            [sectionsToAdd addIndex:layoutAttributesSet.indexPath.section];
        }
    }
    
    [sectionsToAdd enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:section];
        
        UICollectionViewLayoutAttributes *sectionAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        if (sectionAttributes != nil) {
            [newLayoutAttributes addObject:sectionAttributes];
        }
    }];
    
    return newLayoutAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *layoutAttributes = [super layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];
    if (layoutAttributes == nil) return nil;
    
    CGPoint boundaries = [self heightBoundariesForSection:indexPath.section];
    if ((boundaries.x == 0) && (boundaries.y == 0)) return nil;
    
    UICollectionView *collectionView = self.collectionView;
    if (collectionView == nil) return nil;
    
    NSInteger contentOffsetY = collectionView.contentOffset.y;
    CGRect frameForSupplementaryView = layoutAttributes.frame;
    
    NSInteger minimum = boundaries.x - frameForSupplementaryView.size.height;
    NSInteger maximum = boundaries.y - frameForSupplementaryView.size.height;

    if (contentOffsetY < minimum) {
        frameForSupplementaryView.origin.y = minimum;
        UICollectionReusableView *header = [collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        if (header) {
            header.backgroundColor = [UIColor clearColor];
        }
    } else if (contentOffsetY > maximum) {
        frameForSupplementaryView.origin.y = maximum;
        UICollectionReusableView *header = [collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        if (header) {
            header.backgroundColor = [[UIColor piwigoBackgroundColor] colorWithAlphaComponent:0.75];
        }
    } else {
        frameForSupplementaryView.origin.y = contentOffsetY;
        UICollectionReusableView *header = [collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        if (header) {
            header.backgroundColor = [[UIColor piwigoBackgroundColor] colorWithAlphaComponent:0.75];
        }
    }
    
    layoutAttributes.frame = frameForSupplementaryView;

    return layoutAttributes;
}

- (CGPoint)heightBoundariesForSection:(NSInteger)section
{
    CGPoint result = CGPointMake(0.0, 0.0);
    
    // Exit early
    UICollectionView *collectionView = self.collectionView;
    if (collectionView == nil) return result;
    
    // Fetch number of items for section
    NSInteger numberOfItems = [collectionView numberOfItemsInSection:section];
    if (numberOfItems == 0) return result;
    
    // First item
    UICollectionViewLayoutAttributes *firstItem = [self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]];

    // Last item
    UICollectionViewLayoutAttributes *lastItem = [self layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:(numberOfItems - 1) inSection:section]];

    if (firstItem && lastItem)
    {
        // Item min and max Y ccordinates
        result.x = firstItem.frame.origin.y;
        result.y = lastItem.frame.origin.y + lastItem.frame.size.height;
            
        // Take header size into account
        result.x -= [self headerReferenceSize].height;
        result.y -= [self headerReferenceSize].height;
            
        // Take section inset into account
        result.x -= [self sectionInset].top;
        result.y += [self sectionInset].top + [self sectionInset].bottom;
        }

    return result;
}

@end
