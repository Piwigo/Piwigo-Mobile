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
NSString * const kReflectionGetMethodList = @"format=json&method=reflection.getMethodList";
NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
NSString * const kCommunitySessionGetStatus = @"format=json&method=community.session.getStatus";
NSString * const kPiwigoSessionGetPluginsList = @"format=json&method=pwg.plugins.getList";
NSString * const kPiwigoSessionLogout = @"format=json&method=pwg.session.logout";

NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList&cat_id={categoryId}&recursive={recursive}&faked_by_community={faked}";
NSString * const kCommunityCategoriesGetList = @"format=json&method=community.categories.getList&cat_id={categoryId}&recursive={recursive}";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages&cat_id={albumId}&per_page={perPage}&page={page}&order={order}";
NSString * const kPiwigoCategoriesAdd = @"format=json&method=pwg.categories.add&name={name}&status={status}";
NSString * const kPiwigoCategoriesSetInfo = @"format=json&method=pwg.categories.setInfo";
NSString * const kPiwigoCategoriesDelete = @"format=json&method=pwg.categories.delete";
NSString * const kPiwigoCategoriesMove = @"format=json&method=pwg.categories.move";
NSString * const kPiwigoCategoriesSetRepresentative = @"format=json&method=pwg.categories.setRepresentative";

NSString * const kPiwigoImagesUpload = @"format=json&method=pwg.images.upload";
NSString * const kCommunityImagesUploadCompleted = @"format=json&method=community.images.uploadCompleted";
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
NSString * const kPiwigoImagesUploadParamMimeType = @"mimeType";

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
+(NSURLSessionTask*)post:(NSString*)path
           URLParameters:(NSDictionary*)urlParams
              parameters:(NSDictionary*)parameters
                progress:(void (^)(NSProgress *))progress
                 success:(void (^)(NSURLSessionTask *task, id responseObject))success
                 failure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
    NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
    [jsonAcceptableContentTypes addObject:@"text/plain"];
    jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
    manager.responseSerializer = jsonResponseSerializer;
    
    // Ensure that SSL certificates won't be rejected
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [manager setSecurityPolicy:policy];
    
    NSURLSessionTask *task = [manager POST:[NetworkHandler getURLWithPath:path asPiwigoRequest:YES withURLParams:urlParams]
                                parameters:parameters
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       if (success) {
                                           success(task, responseObject);
                                       }
                                       [manager invalidateSessionCancelingTasks:YES];
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                       NSLog(@"NetworkHandler/post Error: %@", error);
#endif
                                       if(fail) {
                                           fail(task, error);
                                       }
                                       [manager invalidateSessionCancelingTasks:YES];
                                  }
                              ];
    
    return task;
}

+(NSURLSessionTask*)postMultiPart:(NSString*)path
                       parameters:(NSDictionary*)parameters
                         progress:(void (^)(NSProgress *))progress
                          success:(void (^)(NSURLSessionTask *task, id responseObject))success
                          failure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    AFJSONResponseSerializer *jsonResponseSerializer = [AFJSONResponseSerializer serializer];
    NSMutableSet *jsonAcceptableContentTypes = [NSMutableSet setWithSet:jsonResponseSerializer.acceptableContentTypes];
    [jsonAcceptableContentTypes addObject:@"text/plain"];
    jsonResponseSerializer.acceptableContentTypes = jsonAcceptableContentTypes;
    manager.responseSerializer = jsonResponseSerializer;
    
    // Ensure that SSL certificates won't be rejected
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [manager setSecurityPolicy:policy];
    
    NSURLSessionTask *task = [manager POST:[NetworkHandler getURLWithPath:path asPiwigoRequest:YES withURLParams:nil]
                                parameters:nil
                 constructingBodyWithBlock:^(id<AFMultipartFormData> formData)
    {
        [formData appendPartWithFileData:[parameters objectForKey:kPiwigoImagesUploadParamData]
                                    name:@"file"
                                fileName:[parameters objectForKey:kPiwigoImagesUploadParamFileName]
                                mimeType:[parameters objectForKey:kPiwigoImagesUploadParamMimeType]];
        
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
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       if (success) {
                                           success(task, responseObject);
                                       }
                                       [manager invalidateSessionCancelingTasks:YES];
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                       NSLog(@"NetworkHandler/post Error: %@", error);
#endif
                                       if(fail) {
                                           fail(task, error);
                                       }
                                       [manager invalidateSessionCancelingTasks:YES];
                                   }];
    
    return task;
}

+(NSString*)getURLWithPath:(NSString*)path asPiwigoRequest:(BOOL)piwigo withURLParams:(NSDictionary*)params
{
    NSString *cleanPath = [path stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:[Model sharedInstance].serverName withString:@""];
    
    NSString *url = [NSString stringWithFormat:@"%@%@%@%@",
                     [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName,
                     piwigo ? @"/ws.php?" : @"", cleanPath];

	for(NSString *parameter in params)
	{
		NSString *replaceMe = [NSString stringWithFormat:@"{%@}", parameter];
		NSString *toReplace = [NSString stringWithFormat:@"%@", [params objectForKey:parameter]];
		url = [url stringByReplacingOccurrencesOfString:replaceMe withString:toReplace];
	}
	
	return [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

+(void)showConnectionError:(NSError*)error
{
	UIAlertView *connectionError = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
															  message:[NSString stringWithFormat:@"%@", [error localizedDescription]]
															 delegate:nil
													cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
													otherButtonTitles:nil];
	[connectionError show];
}

@end
