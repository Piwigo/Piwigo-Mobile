//
//  ImageUploadManager.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "PhotosFetch.h"
#import "ImageUpload.h"

NSString * const kPiwigoNotificationImageUploaded = @"kPiwigoNotificationImageUploaded";
NSString * const kPiwigoNotificationImageUploading = @"kPiwigoNotificationImageUploading";
NSString * const kPiwigoNotificationImageUploadNameKey = @"imageName";
NSString * const kPiwigoNotificationImageUploadCurrentKey = @"current";
NSString * const kPiwigoNotificationImageUploadTotalKey = @"total";
NSString * const kPiwigoNotificationImageUploadPercentKey = @"percent";
NSString * const kPiwigoNotificationImageUploadCurrentChunkKey = @"currentChunk";
NSString * const kPiwigoNotificationImageUploadTotalChunksKey = @"totalChunks";

@interface ImageUploadManager()

@property (nonatomic, assign) BOOL isUploading;

@end

@implementation ImageUploadManager

+(ImageUploadManager*)sharedInstance
{
	static ImageUploadManager *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});
	return instance;
}

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.imageUploadQueue = [NSMutableArray new];
		self.isUploading = NO;
	}
	return self;
}

-(void)addImage:(NSString*)imageName forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy
{
	ImageUpload *newImage = [[ImageUpload alloc] initWithImageName:imageName forCategory:category forPrivacyLevel:privacy];
	[self.imageUploadQueue addObject:newImage];
	[self startUploadIfNeeded];
}

-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy
{
	for(NSString* imageName in imageNames)
	{
		[self addImage:imageName forCategory:category andPrivacy:privacy];
	}
}

-(void)uploadNextImage
{
	if(self.imageUploadQueue.count <= 0)
	{
		self.isUploading = NO;
		return;
	}
	
	self.isUploading = YES;
	
	ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
	
	NSString *imageKey = nextImageToBeUploaded.imageUploadName;
	ALAsset *imageAsset = [[PhotosFetch sharedInstance].localImages objectForKey:imageKey];
	
	ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
	Byte *buffer = (Byte*)malloc(rep.size);
	NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
	NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
	
	[UploadService uploadImage:imageData
					  withName:[[imageAsset defaultRepresentation] filename]
					  forAlbum:nextImageToBeUploaded.categoryToUploadTo
			   andPrivacyLevel:nextImageToBeUploaded.privacyLevel
					onProgress:^(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks) {
						
						[[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationImageUploading
																			object:nil
																		  userInfo:@{kPiwigoNotificationImageUploadNameKey : imageKey,
																					 kPiwigoNotificationImageUploadCurrentKey : @(current),
																					 kPiwigoNotificationImageUploadTotalKey : @(total),
																					 kPiwigoNotificationImageUploadPercentKey : @((CGFloat)current / total),
																					 kPiwigoNotificationImageUploadCurrentChunkKey : @(currentChunk),
																					 kPiwigoNotificationImageUploadTotalChunksKey : @(totalChunks)}];
					} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						
						[[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationImageUploaded
																			object:nil
																		  userInfo:@{kPiwigoNotificationImageUploadNameKey : imageKey}];
						
						[self.imageUploadQueue removeObjectAtIndex:0];
						[self uploadNextImage];
					} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						NSLog(@"ERROR IMAGE UPLOAD: %@", error);
						[self showUploadError:error];
					}];
}

-(void)startUploadIfNeeded
{
	if(!self.isUploading)
	{
		[self uploadNextImage];
	}
}

-(void)showUploadError:(NSError*)error
{
	[UIAlertView showWithTitle:@"Upload Error"
					   message:[NSString stringWithFormat:@"Could not upload your image. Error: %@", [error localizedDescription]]
			 cancelButtonTitle:@"Okay"
			 otherButtonTitles:nil
					  tapBlock:nil];
}


@end
