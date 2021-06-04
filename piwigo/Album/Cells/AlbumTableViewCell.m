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
#import "ImageService.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "NetworkHandler.h"
#import "PiwigoAlbumData.h"
#import "SAMKeychain.h"

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
        if(NetworkVarsObjc.shared.hasAdminRights) {
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
    [numberFormatter setPositiveFormat:@"#,##0"];
    if (self.albumData.numberOfSubCategories == 0) {
        
        // There are no sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfImages]],
                                    self.albumData.numberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
        
    } else if (self.albumData.totalNumberOfImages == 0) {
        
        // There are no images but sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]],
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
        
    } else {
        
        // There are images and sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@, %@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.totalNumberOfImages]],
                                    self.albumData.totalNumberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo"),
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]],
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
    }
    self.numberOfImages.font = [self.numberOfImages.font fontWithSize:[UIFont fontSizeForLabel:self.numberOfImages nberLines:1]];

    // Add renaming, moving and deleting capabilities when user has admin rights
    if(NetworkVarsObjc.shared.hasAdminRights)
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
    self.backgroundImage.layer.cornerRadius = 10;
//    NSInteger imageSize = CGImageGetHeight(albumData.categoryImage.CGImage) * CGImageGetBytesPerRow(albumData.categoryImage.CGImage);
//    
//    if (albumData.categoryImage && imageSize > 0)
//    {
//        // Album thumbnail in memory
//        self.backgroundImage.image = albumData.categoryImage;
//    }
//    else
        if (albumData.albumThumbnailUrl.length <= 0)
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
        NSURL *URL = [NSURL URLWithString:albumData.albumThumbnailUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [self.backgroundImage setImageWithURLRequest:request
                                    placeholderImage:[UIImage imageNamed:@"placeholder"]
                                             success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                 albumData.categoryImage = image;
                                                 weakSelf.backgroundImage.image = image;
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
