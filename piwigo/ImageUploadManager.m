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

@interface ImageUploadManager()

@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) NSInteger maximumImagesForBatch;
@property (nonatomic, assign) NSInteger onCurrentImageUpload;

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
	[self addImage:newImage];
}

-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy
{
	for(NSString* imageName in imageNames)
	{
		[self addImage:imageName forCategory:category andPrivacy:privacy];
	}
}

-(void)addImage:(ImageUpload*)image
{
	[self.imageUploadQueue addObject:image];
	self.maximumImagesForBatch++;
	[self startUploadIfNeeded];
}

-(void)addImages:(NSArray*)images
{
	for(ImageUpload *image in images)
	{
		[self addImage:image];
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
	
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamName : nextImageToBeUploaded.imageUploadName,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : nextImageToBeUploaded.author,
									  kPiwigoImagesUploadParamDescription : nextImageToBeUploaded.imageDescription
									  };
	
	[UploadService uploadImage:imageData
			   withInformation:imageProperties
					onProgress:^(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks) {
						
						if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
						{
							[self.delegate imageProgress:nextImageToBeUploaded onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
						}
					} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						
						self.onCurrentImageUpload++;
						if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
						{
							[self.delegate imageUploaded:nextImageToBeUploaded placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
						}
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

-(void)setIsUploading:(BOOL)isUploading
{
	_isUploading = isUploading;
	
	if(!isUploading)
	{
		self.maximumImagesForBatch = 0;
		self.onCurrentImageUpload = 1;
	}
}

-(void)setMaximumImagesForBatch:(NSInteger)maximumImagesForBatch
{
	_maximumImagesForBatch = maximumImagesForBatch;
	
	if([self.delegate respondsToSelector:@selector(imagesToUploadChanged:)])
	{
		[self.delegate imagesToUploadChanged:maximumImagesForBatch];
	}
}


@end
