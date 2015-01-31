//
//  AlbumService.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "PiwigoAlbumData.h"
#import "PiwigoImageData.h"
#import "Model.h"
#import "CategoriesData.h"

NSString * const kGetImageOrderFileName = @"file";
NSString * const kGetImageOrderId = @"id";
NSString * const kGetImageOrderName = @"name";
NSString * const kGetImageOrderRating = @"rating_score";
NSString * const kGetImageOrderDateCreated = @"date_creation";
NSString * const kGetImageOrderDateAdded = @"date_available";
NSString * const kGetImageOrderRandom = @"random";

@implementation AlbumService

+(AFHTTPRequestOperation*)getAlbumListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albums))completion
									   onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoCategoriesGetList
		URLParameters:nil
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  NSArray *albums = [AlbumService parseAlbumJSON:[[responseObject objectForKey:@"result"] objectForKey:@"categories"]];
						  [[CategoriesData sharedInstance] addCategories:albums];
						  completion(operation, albums);
					  } else {
						  completion(operation, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(NSArray*)parseAlbumJSON:(NSArray*)json
{
	NSMutableArray *albums = [NSMutableArray new];
	for(NSDictionary *category in json)
	{
		PiwigoAlbumData *albumData = [PiwigoAlbumData new];
		albumData.albumId = [category objectForKey:@"id"];
		albumData.name = [category objectForKey:@"name"];
		albumData.comment = [category objectForKey:@"comment"];
		albumData.globalRank = [[category objectForKey:@"global_rank"] integerValue];
		albumData.numberOfImages = [[category objectForKey:@"total_nb_images"] integerValue];
		
		id thumbId = [category objectForKey:@"representative_picture_id"];
		if(thumbId != [NSNull null]) {
			albumData.albumThumbnailId = [[category objectForKey:@"representative_picture_id"] integerValue];
			albumData.albumThumbnailUrl = [category objectForKey:@"tn_url"];
		}
		
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		[dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[Model sharedInstance].language]];
		albumData.dateLast = [dateFormatter dateFromString:[category objectForKey:@"date_last"]];
		
		[albums addObject:albumData];
	}
	
	return albums;
}

+(AFHTTPRequestOperation*)getAlbumPhotosForAlbumId:(NSInteger)albumId
											onPage:(NSInteger)page
										  forOrder:(NSString*)order
									  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albumImages))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoCategoriesGetImages
		URLParameters:@{@"albumId" : @(albumId),
						@"perPage" : @([Model sharedInstance].imagesPerPage),
						@"page" : @(page),
						@"order" : order}
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"]) {
						  NSArray *albumImages = [AlbumService parseAlbumImagesJSON:[responseObject objectForKey:@"result"]];
						  completion(operation, albumImages);
					  } else {
						  completion(operation, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(NSArray*)parseAlbumImagesJSON:(NSDictionary*)json
{
	NSDictionary *paging = [json objectForKey:@"paging"];
	[Model sharedInstance].lastPageImageCount = [[paging objectForKey:@"count"] integerValue];
	
	NSDictionary *imagesInfo = [json objectForKey:@"images"];
	
	NSMutableArray *albumImages = [NSMutableArray new];
	for(NSDictionary *image in imagesInfo)
	{
		PiwigoImageData *imgData = [AlbumService parseBasicImageInfoJSON:image];
		[albumImages addObject:imgData];
	}
	return albumImages;
}

+(AFHTTPRequestOperation*)getImageInfoById:(NSInteger)imageId
						  ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, PiwigoImageData *imageData))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoImagesGetInfo
		URLParameters:@{@"imageId" : @(imageId)}
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  completion(operation, [AlbumService parseBasicImageInfoJSON:[responseObject objectForKey:@"result"]]);
					  } else {
						  completion(operation, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(fail) {
					  fail(operation, error);
				  }
			  }];
}

+(PiwigoImageData*)parseBasicImageInfoJSON:(NSDictionary*)imageJson
{
	PiwigoImageData *imageData = [PiwigoImageData new];
	
	imageData.imageId = [imageJson objectForKey:@"id"];
	imageData.fileName = [imageJson objectForKey:@"file"];
	imageData.name = [imageJson objectForKey:@"name"];
	imageData.fullResPath = [imageJson objectForKey:@"element_url"];
	
	NSDictionary *imageSizes = [imageJson objectForKey:@"derivatives"];
	imageData.thumbPath = [[imageSizes objectForKey:@"thumb"] objectForKey:@"url"];
	imageData.squarePath = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
	imageData.mediumPath = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
	
	NSArray *categories = [imageJson objectForKey:@"categories"];
	NSMutableArray *categoryIds = [NSMutableArray new];
	for(NSDictionary *category in categories)
	{
		[categoryIds addObject:[category objectForKey:@"id"]];
	}
	
	imageData.categoryIds = categoryIds;
	
	return imageData;
}

@end
