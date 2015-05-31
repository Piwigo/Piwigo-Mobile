//
//  AlbumImagesViewController_iPhone.m
//  piwigo
//
//  Created by Olaf on 03.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController_iPhone.h"


@interface AlbumImagesViewController_iPhone ()

@property (nonatomic, strong) UIBarButtonItem *actionBarButton;

@end

@implementation AlbumImagesViewController_iPhone

-(instancetype)initWithAlbumId:(NSInteger)albumId {
    self = [super initWithAlbumId:albumId];
    if(self) {
        [self.imagesCollection registerClass:[CategoryCollectionViewCell class] forCellWithReuseIdentifier:@"category"];
        self.actionBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                             target:self
                                                                             action:@selector(openTheMenue)];

    }
    return self;
}

-(UICollectionViewCell*)cellWithAlbumData:(PiwigoAlbumData *)albumData
                      collectionView:(UICollectionView *)collectionView
                         atIndexPath:(NSIndexPath *)indexPath {
    CategoryCollectionViewCell *cell =
    [collectionView dequeueReusableCellWithReuseIdentifier:@"category" forIndexPath:indexPath];
    cell.categoryDelegate = self;
    [cell setupWithAlbumData:albumData];
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
        return CGSizeMake(collectionView.frame.size.width - 20, 188);
    }
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
      if(indexPath.section == 1) {
        [super collectionView:collectionView inSectionOneSidSelectItemAtIndexPath:indexPath];
        
    } else {
        MyLog(@"Error, no such section");
    }
    
}

-(void)pushView:(UIViewController *)viewController {
    [super pushView:viewController];
}


#pragma mark - Menue -

-(void)loadNavButtons
{
    if([Model sharedInstance].hasAdminRights)
    {
        if(self.isSelect) {
            [self.navigationItem setRightBarButtonItems:@[self.actionBarButton, self.uploadBarButton] animated:YES];
        } else {
            [self.navigationItem setRightBarButtonItems:@[self.selectBarButton, self.uploadBarButton] animated:YES];
        }
    }
    else
    {
        if(self.isSelect) {
            [self.navigationItem setRightBarButtonItem: self.actionBarButton animated:YES];
        } else {
            [self.navigationItem setRightBarButtonItem: self.selectBarButton animated:YES];
        }
    }
}

-(void)openTheMenue {
    if (self.isSelect) {
        if([Model sharedInstance].hasAdminRights) {
            [self showAdminUserMenue];
        } else {
            [self showNormalUserMenue];
        }
    }
}

-(void)showAdminUserMenue {
    [UIActionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem
                                animated:YES
                               withTitle:NSLocalizedString(@"AlbumImageMenueAdmin", @"Album Admin")
                       cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                  destructiveButtonTitle:NSLocalizedString(@"AlbumImageButtonDelete", @"Delete")            // BI: 0
                       otherButtonTitles:@[NSLocalizedString(@"AlbumImageButtonMove", @"Move"),             // BI: 1
                                           NSLocalizedString(@"AlbumImageButtonDownload", @"Download"),     // BI: 2
                                           NSLocalizedString(@"AlbumImageButtonEndSelect", @"End Select"),  // BI: 3
                                           ]
                                tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                                    if(buttonIndex == 0) {
                                        [self deleteImages];
                                    } else if (buttonIndex == 1) {  // Move
                                        [self moveSelection];
                                    } else if (buttonIndex == 2) {  // Download
                                        [self downloadImages];
                                    } else if (buttonIndex == 3) {  // End Select
                                        [self cancelSelect];
                                    } else {
                                        MyLog(@"unknown buttonIndex");
                                    }
                                }];
}

-(void)showNormalUserMenue {
    [UIActionSheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem
                                animated:YES
                               withTitle:NSLocalizedString(@"AlbumImageMenueNormal", @"Album normal")
                       cancelButtonTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                  destructiveButtonTitle:nil
                       otherButtonTitles:@[NSLocalizedString(@"AlbumImageButtonDownload", @"Download"),     // BI: 0
                                           NSLocalizedString(@"AlbumImageButtonEndSelect", @"End Select"),  // BI: 1
                                           ]
                                tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                                    if(buttonIndex == 0) {          // Download
                                        [super downloadImages];
                                    } else if (buttonIndex == 1) { // End Select
                                        [self cancelSelect];
                                    } else {
                                        MyLog(@"unknown buttonIndex");
                                    }
                                }];
    
}

@end
