//
//  NetworkHandler.m
//  WordSearch
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "NetworkHandler.h"

NSString * const kBaseUrlPath = @"http://pwg.bakercrew.com/piwigo/ws.php?";

@interface NetworkHandler()

@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSDictionary *dictionary;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) SuccessBlock block;
@property (nonatomic, copy) FailureBlock failBlock;

@end

@implementation NetworkHandler

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
