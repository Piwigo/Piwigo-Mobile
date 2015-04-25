//
//  AlbumImagesViewController_iPad.m
//  piwigo
//
//  Created by Olaf on 03.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController_iPad.h"

#import "PiwigoAlbumData.h"
#import "Model.h"

@interface AlbumImagesViewController_iPad ()

@property (nonatomic) BOOL cellEditMode;
@property (nonatomic, strong) NSIndexPath *cellEditIndexPath;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

@end

@implementation AlbumImagesViewController_iPad

-(instancetype)initWithAlbumId:(NSInteger)albumId {
    self = [super initWithAlbumId:albumId];
    if(self) {
        [self.imagesCollection registerNib:[AlbumCollectionViewCell nib]
         // Class:[AlbumCollectionViewCell class]
                forCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier]];
    }
    return self;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if([Model sharedInstance].hasAdminRights) {
        // attach long press gesture to collectionView
        if (nil == _longPressGestureRecognizer) {
            _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
                                           initWithTarget:self action:@selector(handleLongPress:)];
            _longPressGestureRecognizer.minimumPressDuration = 0.5f; //seconds
            _longPressGestureRecognizer.delegate = self;
            _longPressGestureRecognizer.delaysTouchesBegan = YES;
        }
        [self.imagesCollection addGestureRecognizer:_longPressGestureRecognizer];
    } 

}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateEnded) {
        MyLog(@"Cell: %@", self);
        CGPoint tapPoint = [gestureRecognizer locationInView:self.imagesCollection];
        
        NSIndexPath *indexPath;
        indexPath = [self.imagesCollection indexPathForItemAtPoint:tapPoint];
        if (indexPath == nil){
            MyLog(@"couldn't find index path");
        } else {
            if(indexPath.section == 0) {
                if (self.cellEditMode) { // turn off old selection
                    AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[self.imagesCollection cellForItemAtIndexPath:self.cellEditIndexPath];
                    [cell exitFromEditMode];
                }
                self.cellEditMode = YES;
                self.cellEditIndexPath = indexPath;
                
                AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[self.imagesCollection cellForItemAtIndexPath:indexPath];
                [cell goIntoEditMode];
            }
        }
        
    }
}


-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                           collectionView:(UICollectionView *)collectionView
                              atIndexPath:(NSIndexPath *)indexPath {
    AlbumCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[AlbumCollectionViewCell cellReuseIdentifier] forIndexPath:indexPath];
    
    [cell setupWithAlbumData:albumData];
    cell.cellDelegate = self;
    return cell;
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
        CGSize returnSize   = CGSizeMake(260, 180);
        returnSize.height   += 35;
        returnSize.width    += 35;
        return returnSize;
//        return CGSizeMake(collectionView.frame.size.width - 20, 188);
    }
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        if (self.cellEditMode) {
            if (self.cellEditIndexPath.section == indexPath.section &&
                self.cellEditIndexPath.row == indexPath.row) { // turn off
                AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[self.imagesCollection cellForItemAtIndexPath:self.cellEditIndexPath];
                [cell exitFromEditMode];
                self.cellEditMode = NO;
            } else { // user tapped somewhere else
                AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[self.imagesCollection cellForItemAtIndexPath:self.cellEditIndexPath];
                [cell exitFromEditMode];
                [self openAlbumAtIndexPath:indexPath];
            }
        } else { // this is just a normal tap on an album
            [self openAlbumAtIndexPath:indexPath];
        }
    } else if(indexPath.section == 1) {
        [super collectionView:collectionView inSectionOneSidSelectItemAtIndexPath:indexPath];
    
    } else {
        MyLog(@"Error, no such section");
    }
}

-(void)openAlbumAtIndexPath:(NSIndexPath *)indexPath {
    AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[self.imagesCollection cellForItemAtIndexPath:indexPath];
    AlbumImagesViewController_iPad *album = [[AlbumImagesViewController_iPad alloc] initWithAlbumId:cell.albumData.albumId];
    [self.navigationController pushViewController:album animated:YES];
}

#pragma mark AlbumTableViewCellDelegate Methods

-(void)pushView:(UIViewController *)viewController
{
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
