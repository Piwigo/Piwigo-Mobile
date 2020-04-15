//
//  ImageUpload.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "PhotosFetch.h"
#import "ImageUpload.h"
#import "Model.h"
#import "PiwigoImageData.h"

NSString * const kPiwigoNotificationDeselectImageToUpload = @"kPiwigoNotificationDeselectImageToUpload";

@implementation ImageUpload

-(instancetype)initWithImageAsset:(PHAsset*)imageAsset forCategory:(NSInteger)category
                     privacyLevel:(NSInteger)privacy author:(NSString*)author
{
    self = [super init];
    if(self)
    {
        if (imageAsset) {
            // Initialisation from image asset
            self.imageAsset = imageAsset;
            NSString *fileName = [[PhotosFetch sharedInstance] getFileNameFomImageAsset:imageAsset];
            if ([Model sharedInstance].prefixFileNameBeforeUpload &&
                ![fileName hasPrefix:[Model sharedInstance].defaultPrefix]) {
                self.fileName = [[Model sharedInstance].defaultPrefix stringByAppendingString:fileName];
            } else {
                self.fileName = fileName;
            }
            self.creationDate = [imageAsset creationDate];
            self.pixelWidth = [imageAsset pixelWidth];
            self.pixelHeight = [imageAsset pixelHeight];
            self.categoryToUploadTo = category;
            self.privacyLevel = privacy;            // default privacy level
            self.author = author;                   // Default author
            self.imageTitle = @"";                  // New images have no title
            self.comment = @"";                     // New images have no description
            self.tags = [[NSArray alloc] init];     // New images have no tags
        }
        self.stopUpload = NO;
    }
    return self;
}


#pragma mark - debugging support -

-(NSString *)description {
    NSString *objectIsNil = @"<nil>";
    
    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    PHImageRequestOptions * imageRequestOptions = [[PHImageRequestOptions alloc] init];
    if (@available(iOS 13.0, *)) {
        [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:self.imageAsset
                            options:imageRequestOptions
                      resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info) {
            NSLog(@"info = %@", info);
            if ([info objectForKey:@"PHImageFileURLKey"]) {
                NSURL *url = [info objectForKey:@"PHImageFileURLKey"];
                [descriptionArray addObject:[NSString stringWithFormat:@"imageAsset         = %@", url]];
            }
        }];
    }
    else {
        [[PHImageManager defaultManager] requestImageDataForAsset:self.imageAsset
                                                          options:imageRequestOptions
                                                    resultHandler:^(NSData *imageData, NSString *dataUTI,
                                                                    UIImageOrientation orientation, NSDictionary *info)
                         {
                             NSLog(@"info = %@", info);
                             if ([info objectForKey:@"PHImageFileURLKey"]) {
                                 NSURL *url = [info objectForKey:@"PHImageFileURLKey"];
                                 [descriptionArray addObject:[NSString stringWithFormat:@"imageAsset         = %@", url]];
                             }
                         }
        ];
    }

    [descriptionArray addObject:[NSString stringWithFormat:@"image              = %@", (nil == self.fileName ? objectIsNil :(0 == self.fileName.length ? @"''" : self.fileName))]];
    [descriptionArray addObject:[NSString stringWithFormat:@"title    = %@", (nil == self.imageTitle ? objectIsNil : (0 == self.imageTitle.length ? @"''" : self.imageTitle))]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"categoryToUploadTo = %ld", (long)self.categoryToUploadTo]];
    [descriptionArray addObject:[NSString stringWithFormat:@"privacyLevel       = %@", kPiwigoPrivacyString(self.privacyLevel)]];
    [descriptionArray addObject:[NSString stringWithFormat:@"imageDescription   = %@", (nil == self.comment ? objectIsNil :(0 == [self.comment length] ? @"''" : self.comment))]];

    [descriptionArray addObject:[NSString stringWithFormat:@"tags [%ld] %@", (long)self.tags.count, self.tags]];
    [descriptionArray addObject:[NSString stringWithFormat:@"imageId            = %ld", (long)self.imageId]];


    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}

    
@end
