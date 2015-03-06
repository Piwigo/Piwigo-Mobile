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
#import "PiwigoTagData.h"
#import "ImageService.h"
#import "CategoriesData.h"

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
		self.imageNamesUploadQueue = [NSMutableDictionary new];
		self.isUploading = NO;
	}
	return self;
}

-(void)addImage:(NSString*)imageName forCategory:(NSInteger)category andPrivacy:(kPiwigoPrivacy)privacy
{
	ImageUpload *newImage = [[ImageUpload alloc] initWithImageName:imageName forCategory:category forPrivacyLevel:privacy];
	[self addImage:newImage];
}

-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(kPiwigoPrivacy)privacy
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
	[self.imageNamesUploadQueue setObject:image.image forKey:image.image];
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
	
	NSString *imageKey = nextImageToBeUploaded.image;
	ALAsset *imageAsset = [[PhotosFetch sharedInstance].localImages objectForKey:imageKey];
	
	ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
	Byte *buffer = (Byte*)malloc(rep.size);
	NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
	NSData *imageData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
	
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in nextImageToBeUploaded.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamFileName : nextImageToBeUploaded.image,
									  kPiwigoImagesUploadParamName : nextImageToBeUploaded.imageUploadName,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : nextImageToBeUploaded.author,
									  kPiwigoImagesUploadParamDescription : nextImageToBeUploaded.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy]
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
						
						[[CategoriesData sharedInstance] getCategoryById:nextImageToBeUploaded.categoryToUploadTo].numberOfImages++;
						[self addImageDataToCategoryCache:response];
						[self setImageResponse:response withInfo:imageProperties];
						
						[self.imageUploadQueue removeObjectAtIndex:0];
						[self.imageNamesUploadQueue removeObjectForKey:imageKey];
						if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
						{
							[self.delegate imageUploaded:nextImageToBeUploaded placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
						}
						
						[self uploadNextImage];
					} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						if(error.code == -1016 &&
						   ([nextImageToBeUploaded.image rangeOfString:@".MOV"].location != NSNotFound ||
						   [nextImageToBeUploaded.image rangeOfString:@".mov"].location != NSNotFound))
						{	// they need to install the VideoJS plugin
							[UIAlertView showWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
											   message:NSLocalizedString(@"videoUploadError_message", @"You need to add the plugin \"VideoJS\" and edit your local config file to allow video to be uploaded to your Piwigo")
									 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
									 otherButtonTitles:nil
											  tapBlock:nil];
						}
						else
						{
							NSLog(@"ERROR IMAGE UPLOAD: %@", error);
							[self showUploadError:error];
						}
						
						[self.imageUploadQueue removeObjectAtIndex:0];
						[self.imageNamesUploadQueue removeObjectForKey:imageKey];
						if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
						{
							[self.delegate imageUploaded:nextImageToBeUploaded placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:nil];
						}
						
						[self uploadNextImage];
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

-(NSInteger)getIndexOfImage:(ImageUpload*)image
{
	return [self.imageUploadQueue indexOfObject:image];
}

-(void)setImageResponse:(NSDictionary*)jsonResponse withInfo:(NSDictionary*)imageProperties
{
	if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
	{
		NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
		NSString *imageId = [imageResponse objectForKey:@"image_id"];
		
		[UploadService setImageInfoForImageWithId:imageId
								  withInformation:imageProperties
									   onProgress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
										   // progress
									   } OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
										   // completion
									   } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
										   // fail
									   }];
		
	}
}

-(void)addImageDataToCategoryCache:(NSDictionary*)jsonResponse
{
	
	NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
	[ImageService getImageInfoById:[[imageResponse objectForKey:@"image_id"] integerValue]
				  ListOnCompletion:^(AFHTTPRequestOperation *operation, PiwigoImageData *imageData) {
					  //
				  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					  //
				  }];
}


@end
