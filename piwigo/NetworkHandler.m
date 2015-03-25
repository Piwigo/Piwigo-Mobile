//
//  NetworkHandler.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "NetworkHandler.h"
#import "Model.h"

// URLs:
NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
NSString * const kPiwigoSessionLogout = @"format=json&method=pwg.session.logout";

NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList&cat_id={categoryId}&recursive={recursive}";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages&cat_id={albumId}&per_page={perPage}&page={page}&order={order}";
NSString * const kPiwigoCategoriesAdd = @"format=json&method=pwg.categories.add&name={name}";
NSString * const kPiwigoCategoriesSetInfo = @"format=json&method=pwg.categories.setInfo";
NSString * const kPiwigoCategoriesDelete = @"format=json&method=pwg.categories.delete";
NSString * const kPiwigoCategoriesMove = @"format=json&method=pwg.categories.move";
NSString * const kPiwigoCategoriesSetRepresentative = @"format=json&method=pwg.categories.setRepresentative";

NSString * const kPiwigoImagesUpload = @"format=json&method=pwg.images.upload";
NSString * const kPiwigoImagesGetInfo = @"format=json&method=pwg.images.getInfo&image_id={imageId}";
NSString * const kPiwigoImageSetInfo = @"format=json&method=pwg.images.setInfo";
NSString * const kPiwigoImageDelete = @"format=json&method=pwg.images.delete";

NSString * const kPiwigoTagsGetList = @"format=json&method=pwg.tags.getList";

// parameter keys:
NSString * const kPiwigoImagesUploadParamData = @"data";
NSString * const kPiwigoImagesUploadParamFileName = @"fileName";
NSString * const kPiwigoImagesUploadParamName = @"name";
NSString * const kPiwigoImagesUploadParamChunk = @"chunk";
NSString * const kPiwigoImagesUploadParamChunks = @"chunks";
NSString * const kPiwigoImagesUploadParamCategory = @"category";
NSString * const kPiwigoImagesUploadParamPrivacy = @"privacyLevel";
NSString * const kPiwigoImagesUploadParamAuthor = @"author";
NSString * const kPiwigoImagesUploadParamDescription = @"description";
NSString * const kPiwigoImagesUploadParamTags = @"tags";

@interface NetworkHandler()

@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSDictionary *dictionary;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) SuccessBlock block;

@end

@implementation NetworkHandler


// path: format={param1}
// URLParams: {@"param1" : @"hello" }
+(AFHTTPRequestOperation*)post:(NSString*)path
				 URLParameters:(NSDictionary*)urlParams
					parameters:(NSDictionary*)parameters
					   success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
					   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
		
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	manager.responseSerializer = jsonResponseSerializer;
	
	AFHTTPRequestOperation *operation = [manager POST:[NetworkHandler getURLWithPath:path andURLParams:urlParams]
			  parameters:parameters
				 success:success
				 failure:^(AFHTTPRequestOperation *operation, NSError *error) {
					 if(fail) {
						 fail(operation, error);
					 }
				 }];
	
	return operation;
}

+(AFHTTPRequestOperation*)postMultiPart:(NSString*)path
							 parameters:(NSDictionary*)parameters
							   success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
							   failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	
	AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
	NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
	[jsonAcceptableContentTypes addObject:@"text/plain"];
	jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
	manager.responseSerializer = jsonResponseSerializer;
	
	return [manager POST:[NetworkHandler getURLWithPath:path andURLParams:nil]
			  parameters:nil
constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
	
	NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
	[mutableHeaders setValue:[NSString stringWithFormat:@"multipart/form-data"] forKey:@"Content-Type"];
	
	[formData appendPartWithFileData:[parameters objectForKey:kPiwigoImagesUploadParamData]
								name:@"file"
							fileName:[parameters objectForKey:kPiwigoImagesUploadParamFileName]
							mimeType:@"image/jpeg"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamName] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"name"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamChunk] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"chunk"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamChunks] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"chunks"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamCategory] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"category"];
	
	[formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamPrivacy] dataUsingEncoding:NSUTF8StringEncoding]
								name:@"level"];
	
	[formData appendPartWithFormData:[[Model sharedInstance].pwgToken dataUsingEncoding:NSUTF8StringEncoding]
								name:@"pwg_token"];
	}
				 success:success
				 failure:fail];
}



+(NSString*)getURLWithPath:(NSString*)path andURLParams:(NSDictionary*)params
{
	NSString *url = [NSString stringWithFormat:@"%@%@/ws.php?%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, path];

	for(NSString *parameter in params)
	{
		NSString *replaceMe = [NSString stringWithFormat:@"{%@}", parameter];
		NSString *toReplace = [NSString stringWithFormat:@"%@", [params objectForKey:parameter]];
		url = [url stringByReplacingOccurrencesOfString:replaceMe withString:toReplace];
	}
	
	return url;
}

+(void)showConnectionError:(NSError*)error
{
	UIAlertView *connectionError = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
															  message:[NSString stringWithFormat:@"%@", [error localizedDescription]]
															 delegate:nil
													cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
													otherButtonTitles:nil];
	[connectionError show];
}

@end
