//
//  Network.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "Network.h"

NSString * const kBaseUrlPath = @"http://pwg.bakercrew.com/piwigo/ws.php?";

@implementation Network

+(void)getPost:(NSString*)path success:(SuccessBlock)success
{
	NSString *string = [NSString stringWithFormat:@"%@format=json&method=pwg.categories.getImages", kBaseUrlPath];
	NSURL *url = [NSURL URLWithString:string];
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	
	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	operation.responseSerializer = jsonResponseSerializer;
	
	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		success(responseObject);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		
	}];
	
	[operation start];
}

+(AFHTTPRequestOperation*)afPost:(SuccessBlock)success
{
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	
	manager.responseSerializer = jsonResponseSerializer;
	
	return [manager POST:[NSString stringWithFormat:@"%@format=json&method=pwg.categories.getImages", kBaseUrlPath]
			   parameters:nil
				  success:^(AFHTTPRequestOperation *operation, id responseObject) {
					  success(responseObject);
				  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
					  //
				  }];
}

@end
