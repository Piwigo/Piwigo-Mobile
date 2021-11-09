//
//  AlbumTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "AlbumTableViewCell.h"
#import "CategoriesData.h"
#import "MBProgressHUD.h"
#import "NetworkHandler.h"
#import "PiwigoAlbumData.h"

NSString * const kAlbumTableCell_ID = @"AlbumTableViewCell";

@interface AlbumTableViewCell()

@end

@implementation AlbumTableViewCell

-(void)imageUpdated
{
    self.backgroundImage.image = self.albumData.categoryImage;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
    if(!albumData) return;
    
    self.albumData = albumData;
    
    // General settings
    self.backgroundColor = [UIColor piwigoColorBackground];
    self.contentView.layer.cornerRadius = 14;
    self.contentView.backgroundColor = [UIColor piwigoColorCellBackground];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.topCut.layer.cornerRadius = 7;
    self.topCut.backgroundColor = [UIColor piwigoColorBackground];
    self.bottomCut.layer.cornerRadius = 7;
    self.bottomCut.backgroundColor = [UIColor piwigoColorBackground];

    // Album name
    self.albumName.text = self.albumData.name;
    self.albumName.font = [UIFont piwigoFontButton];
    self.albumName.textColor = [UIColor piwigoColorOrange];
    self.albumName.font = [self.albumName.font fontWithSize:[UIFont fontSizeForLabel:self.albumName nberLines:2]];

    // Album comment
    if (self.albumData.comment.length == 0) {
        if(NetworkVarsObjc.hasAdminRights) {
            self.albumComment.text = [NSString stringWithFormat:@"(%@)", NSLocalizedString(@"createNewAlbumDescription_noDescription", @"no description")];
            self.albumComment.textColor = [UIColor piwigoColorRightLabel];
        } else {
            self.albumComment.text = @"";
        }
    }
    else {
        self.albumComment.text = self.albumData.comment;
        self.albumComment.textColor = [UIColor piwigoColorText];
    }
    self.albumComment.font = [UIFont piwigoFontSmall];
    self.albumComment.font = [self.albumComment.font fontWithSize:[UIFont fontSizeForLabel:self.albumComment nberLines:3]];

    // Number of images and sub-albums
    self.numberOfImages.font = [UIFont piwigoFontTiny];
    self.numberOfImages.textColor = [UIColor piwigoColorText];
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    if (self.albumData.numberOfSubCategories == 0) {
        // There are no sub-albums
        NSString *nberImages = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfImages]];
        self.numberOfImages.text = self.albumData.numberOfImages > 1 ?
            [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), nberImages] :
            [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), nberImages];
    }
    else if (self.albumData.totalNumberOfImages == 0) {
        // There are no images but sub-albums
        NSString *nberAlbums = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]];
        self.numberOfImages.text = self.albumData.numberOfSubCategories > 1 ?
            [NSString stringWithFormat:NSLocalizedString(@"severalSubAlbumsCount", @"%@ sub-albums"), nberAlbums] :
            [NSString stringWithFormat:NSLocalizedString(@"singleSubAlbumCount", @"%@ sub-album"), nberAlbums];
    }
    else {
        // There are images and sub-albums
        NSString *nberImages = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.totalNumberOfImages]];
        NSMutableString *nberOfImages = [[NSMutableString alloc] initWithString: self.albumData.totalNumberOfImages > 1 ?
            [NSString stringWithFormat:NSLocalizedString(@"severalImagesCount", @"%@ photos"), nberImages] :
            [NSString stringWithFormat:NSLocalizedString(@"singleImageCount", @"%@ photo"), nberImages]];
        [nberOfImages appendString:@", "];
        NSString *nberAlbums = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]];
        [nberOfImages appendString:self.albumData.numberOfSubCategories > 1 ?
            [NSString stringWithFormat:NSLocalizedString(@"severalSubAlbumsCount", @"%@ sub-albums"), nberAlbums] :
            [NSString stringWithFormat:NSLocalizedString(@"singleSubAlbumCount", @"%@ sub-album"), nberAlbums]];
        self.numberOfImages.text = nberOfImages;
    }
    self.numberOfImages.font = [self.numberOfImages.font fontWithSize:[UIFont fontSizeForLabel:self.numberOfImages nberLines:1]];

    // Add renaming, moving and deleting capabilities when user has admin rights
    if(NetworkVarsObjc.hasAdminRights)
    {
        // Handle
        self.handleButton.layer.cornerRadius = 7;
        self.handleButton.backgroundColor = [UIColor piwigoColorOrange];
        self.handleButton.hidden = NO;
  
        // Left => Right swipe (only if there are images in the album)
        // Disabled because it does not work reliably on the server side
//        if (self.albumData.numberOfImages > 0) {
//
//            self.leftSwipeSettings.transition = MGSwipeTransitionBorder;
//            self.leftButtons = @[[MGSwipeButton buttonWithTitle:@""
//                                                           icon:[UIImage imageNamed:@"SwipeRefresh.png"]
//                                                backgroundColor:[UIColor blueColor]
//                                                       callback:^BOOL(MGSwipeTableCell *sender) {
//                                                           [self resfreshRepresentative];
//                                                           return YES;
//                                                       }]];
//        }
    }
    
    // Display album image
    UIImage *placeHolder = [UIImage imageNamed:@"placeholder"];
    self.backgroundImage.layer.cornerRadius = 10;
    NSInteger imageSize = CGImageGetHeight(albumData.categoryImage.CGImage) * CGImageGetBytesPerRow(albumData.categoryImage.CGImage);
    
    if (albumData.categoryImage && imageSize > 0 &&
        ![albumData.categoryImage isEqual:placeHolder])
    {
        // Album thumbnail in memory
        self.backgroundImage.image = albumData.categoryImage;
    }
    else if (albumData.albumThumbnailUrl.length <= 0)
    {
        // No album thumbnail
        albumData.categoryImage = [UIImage imageNamed:@"placeholder"];
        self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
        return;
    }
    else
    {
        // Load album thumbnail
        __weak typeof(self) weakSelf = self;
        CGSize size = self.backgroundImage.bounds.size;
        CGFloat scale = fmax(1.0, self.backgroundImage.traitCollection.displayScale);
        NSURL *URL = [NSURL URLWithString:albumData.albumThumbnailUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
        [self.backgroundImage setImageWithURLRequest:request
                                    placeholderImage:[UIImage imageNamed:@"placeholder"]
                                             success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
                // Process saliency
                UIImage *croppedImage;
                if (@available(iOS 13.0, *)) {
                    croppedImage = [image processSaliency];
                    if (croppedImage == nil) { croppedImage = image; }
                } else {
                    // Fallback on earlier versions
                    croppedImage = image;
                }

                // Reduce size?
                CGSize imageSize = croppedImage.size;
                if (fmax(imageSize.width, imageSize.height) > fmax(size.width, size.height) * scale) {
                    UIImage *albumImage = [ImageUtilities downsampleWithImage:croppedImage to:size scale:scale];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        albumData.categoryImage = albumImage;
                        weakSelf.backgroundImage.image = albumImage;
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        albumData.categoryImage = croppedImage;
                        weakSelf.backgroundImage.image = croppedImage;
                    });
                }
            });
         }
         failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
#if defined(DEBUG)
             NSLog(@"setupWithAlbumData — Fail to get album bg image for album at %@", albumData.albumThumbnailUrl);
#endif
         }];
    }
}


-(void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.backgroundImage cancelImageDownloadTask];
    self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
    
    self.albumName.text = @"";
    self.numberOfImages.text = @"";
}

-(void)setFrame:(CGRect)frame
{
    frame.size.height -= 8.0;
    [super setFrame:frame];
}

@end
