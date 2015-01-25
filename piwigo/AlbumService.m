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
		albumData.albumId = [[category objectForKey:@"id"] integerValue];
		albumData.name = [category objectForKey:@"name"];
		albumData.comment = [category objectForKey:@"comment"];
		albumData.globalRank = [[category objectForKey:@"global_rank"] integerValue];
		albumData.numberOfImages = [[category objectForKey:@"total_nb_images"] integerValue];
		
		id thumbId = [category objectForKey:@"representative_picture_id"];
		if(thumbId != [NSNull null]) {
			albumData.albumThumbnailId = [[category objectForKey:@"representative_picture_id"] integerValue];
			albumData.albumThumbnailUrl = [category objectForKey:@"tn_url"];
		}
		
		[albums addObject:albumData];
	}
	
	return albums;
}

+(AFHTTPRequestOperation*)getAlbumPhotosForAlbumId:(NSInteger)albumId
									  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albumImages))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoCategoriesGetImages
		URLParameters:@{@"albumId" : @(albumId)}
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  // @TODO: check if there's more images from key: "paging"
						  NSArray *albumImages = [AlbumService parseAlbumImageJSON:[responseObject objectForKey:@"result"]];
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

+(NSArray*)parseAlbumImageJSON:(NSDictionary*)json
{
	NSDictionary *imagesInfo = [json objectForKey:@"images"];
	
	NSMutableArray *albumImages = [NSMutableArray new];
	for(NSDictionary *image in imagesInfo)
	{
		PiwigoImageData *imgData = [PiwigoImageData new];
		imgData.name = [image objectForKey:@"file"];
		imgData.fullResPath = [image objectForKey:@"element_url"];
		
		NSDictionary *imageSizes = [image objectForKey:@"derivatives"];
		imgData.thumbPath = [[imageSizes objectForKey:@"thumb"] objectForKey:@"url"];
		imgData.squarePath = [[imageSizes objectForKey:@"square"] objectForKey:@"url"];
		imgData.mediumPath = [[imageSizes objectForKey:@"medium"] objectForKey:@"url"];
		
		NSArray *categories = [image objectForKey:@"categories"];
		NSMutableArray *categoryIds = [NSMutableArray new];
		for(NSDictionary *category in categories)
		{
			[categoryIds addObject:[category objectForKey:@"id"]];
		}
		
		imgData.categoryIds = categoryIds;
		
		[albumImages addObject:imgData];
	}
	return albumImages;
}

@end
