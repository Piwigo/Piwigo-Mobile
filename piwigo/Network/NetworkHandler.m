//
//  NetworkHandler.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "NetworkHandler.h"
#import "Model.h"
#import "KeychainAccess.h"
#import "SAMKeychain.h"
#import "MBProgressHUD.h"

// Piwigo URLs:
NSString * const kReflectionGetMethodList = @"format=json&method=reflection.getMethodList";
NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
NSString * const kCommunitySessionGetStatus = @"format=json&method=community.session.getStatus";
NSString * const kPiwigoSessionGetPluginsList = @"format=json&method=pwg.plugins.getList";
NSString * const kPiwigoSessionLogout = @"format=json&method=pwg.session.logout";

NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList";
NSString * const kCommunityCategoriesGetList = @"format=json&method=community.categories.getList";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages";
NSString * const kPiwigoCategoriesAdd = @"format=json&method=pwg.categories.add";
NSString * const kPiwigoCategoriesSetInfo = @"format=json&method=pwg.categories.setInfo";
NSString * const kPiwigoCategoriesDelete = @"format=json&method=pwg.categories.delete";
NSString * const kPiwigoCategoriesMove = @"format=json&method=pwg.categories.move";
NSString * const kPiwigoCategoriesSetRepresentative = @"format=json&method=pwg.categories.setRepresentative";

NSString * const kPiwigoImagesUpload = @"format=json&method=pwg.images.upload";
NSString * const kCommunityImagesUploadCompleted = @"format=json&method=community.images.uploadCompleted";
NSString * const kPiwigoImagesGetInfo = @"format=json&method=pwg.images.getInfo";
NSString * const kPiwigoImageSetInfo = @"format=json&method=pwg.images.setInfo";
NSString * const kPiwigoImageDelete = @"format=json&method=pwg.images.delete";

NSString * const kPiwigoTagsGetList = @"format=json&method=pwg.tags.getList";

// Parameter keys:
NSString * const kPiwigoImagesUploadParamData = @"data";
NSString * const kPiwigoImagesUploadParamFileName = @"fileName";
NSString * const kPiwigoImagesUploadParamTitle = @"name";
NSString * const kPiwigoImagesUploadParamChunk = @"chunk";
NSString * const kPiwigoImagesUploadParamChunks = @"chunks";
NSString * const kPiwigoImagesUploadParamCategory = @"category";
NSString * const kPiwigoImagesUploadParamPrivacy = @"privacyLevel";
NSString * const kPiwigoImagesUploadParamAuthor = @"author";
NSString * const kPiwigoImagesUploadParamDescription = @"description";
NSString * const kPiwigoImagesUploadParamTags = @"tags";
NSString * const kPiwigoImagesUploadParamMimeType = @"mimeType";

// HUD tag:
NSInteger const loadingViewTag = 899;

@interface NetworkHandler()

@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSDictionary *dictionary;
@property (nonatomic, assign) SEL action;
@property (nonatomic, copy) SuccessBlock block;

@end

@implementation NetworkHandler

+(void)createJSONdataSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 30;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 4;       // 4 is the advised default value
    
    // Create session manager
    [Model sharedInstance].sessionManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [[Model sharedInstance].sessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    [Model sharedInstance].sessionManager.responseSerializer = serializer;

    // For servers performing HTTP Authentication
    [[Model sharedInstance].sessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        // To remember app recieved anthentication challenge
        [Model sharedInstance].performedHTTPauthentication = YES;
        
        // HTTP basic authentification credentials
        NSString *user = [Model sharedInstance].HttpUsername;
        NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        
        // Without HTTP credentials available, tries Piwigo credentials
        if ((user == nil) || (user.length <= 0) || (password == nil)) {
            user  = [Model sharedInstance].username;
            password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
            
            [Model sharedInstance].HttpUsername = user;
            [[Model sharedInstance] saveToDisk];
            [SAMKeychain setPassword:password forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        }
        
        // Supply requested credentials if not provided yet
        if (challenge.previousFailureCount == 0) {
            // Trying HTTP credentials…
            *credential = [NSURLCredential credentialWithUser:user
                                                     password:password
                                                  persistence:NSURLCredentialPersistenceForSession];
            return NSURLSessionAuthChallengeUseCredential;
        } else {
            // HTTP credentials refused!
            [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }];
#if defined(DEBUG)
    NSLog(@"=> JSON data session manager created");
#endif
}

+(void)createImagesSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 30;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 4;       // 4 is the advised default value

    // Create session manager
    [Model sharedInstance].imagesSessionManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [[Model sharedInstance].imagesSessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFImageResponseSerializer *serializer = [[AFImageResponseSerializer alloc] init];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    [Model sharedInstance].imagesSessionManager.responseSerializer = serializer;

    // For servers performing HTTP Authentication
    [[Model sharedInstance].imagesSessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        // To remember app recieved anthentication challenge
        [Model sharedInstance].performedHTTPauthentication = YES;
        
        // HTTP basic authentification credentials
        NSString *user = [Model sharedInstance].HttpUsername;
        NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        
        // Without HTTP credentials available, tries Piwigo credentials
        if ((user == nil) || (user.length <= 0) || (password == nil)) {
            user  = [Model sharedInstance].username;
            password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
            
            [Model sharedInstance].HttpUsername = user;
            [[Model sharedInstance] saveToDisk];
            [SAMKeychain setPassword:password forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        }
        
        // Supply requested credentials if not provided yet
        if (challenge.previousFailureCount == 0) {
            // Trying HTTP credentials…
            *credential = [NSURLCredential credentialWithUser:user
                                                     password:password
                                                  persistence:NSURLCredentialPersistenceForSession];
            return NSURLSessionAuthChallengeUseCredential;
        } else {
            // HTTP credentials refused!
            [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }];     
#if defined(DEBUG)
    NSLog(@"=> Images session manager created");
#endif
}

+(NSString*)encodedURL:(NSString*)originalURL
{
//    NSLog(@"=> %@", originalURL);
    
    // Servers sometimes return http://… instead of https://…
    NSString *cleanPath = [originalURL stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:[Model sharedInstance].serverName withString:@""];
    NSLog(@"   %@", cleanPath);
    
    // Remove the .php? prefix if any
    NSString *prefix = @"";
    NSRange pos = [cleanPath rangeOfString:@".php?"];
    if (pos.location != NSNotFound ) {
        // The path contains .php?
        pos.length += pos.location;
        pos.location = 0;
        prefix = [cleanPath substringWithRange:pos];
        cleanPath = [cleanPath stringByReplacingOccurrencesOfString:prefix withString:@""];
    }

    // Path may not be encoded
//    NSLog(@"   %@", cleanPath);
    NSString *decodedPath = [cleanPath stringByRemovingPercentEncoding];
    if ([cleanPath isEqualToString:decodedPath]) {
        // Path is not encoded
        NSCharacterSet *allowedCharacters = [NSCharacterSet URLPathAllowedCharacterSet];
        cleanPath = [cleanPath stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    }
//    NSLog(@"   %@", cleanPath);
    
    // Compile final URL
    NSString *encodedURL = [NSString stringWithFormat:@"%@%@%@%@",
                            [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, prefix, cleanPath];
    
//    NSLog(@"   %@", encodedURL);
    return encodedURL;
}

// path: format={param1}
// URLParams: {@"param1" : @"hello" }
+(NSURLSessionTask*)post:(NSString*)path
           URLParameters:(NSDictionary*)urlParams
              parameters:(NSDictionary*)parameters
                progress:(void (^)(NSProgress *))progress
                 success:(void (^)(NSURLSessionTask *task, id responseObject))success
                 failure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
//    NSLog(@"   Network URL=%@", [NetworkHandler getURLWithPath:path asPiwigoRequest:YES withURLParams:urlParams]);
//    NSLog(@"   parameters =%@", parameters);
    NSURLSessionTask *task = [[Model sharedInstance].sessionManager POST:[NetworkHandler getURLWithPath:path asPiwigoRequest:YES withURLParams:urlParams]
                                parameters:parameters
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       if (success) {
                                           success(task, responseObject);
                                       }
//                                       [manager invalidateSessionCancelingTasks:YES];
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                       NSLog(@"NetworkHandler/post Error %@: %@", @([error code]), [error localizedDescription]);
                                       NSLog(@"=> localizedFailureReason: %@", [error localizedFailureReason]);
                                       NSLog(@"=> originalRequest= %@", task.originalRequest);
                                       NSLog(@"=> response= %@", task.response);
#endif
                                       if(fail) {
                                           fail(task, error);
                                       }
//                                       [manager invalidateSessionCancelingTasks:YES];
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
    NSURLSessionTask *task = [[Model sharedInstance].sessionManager POST:[NetworkHandler getURLWithPath:path asPiwigoRequest:YES withURLParams:nil]
                                parameters:nil
                 constructingBodyWithBlock:^(id<AFMultipartFormData> formData)
                  {
                      [formData appendPartWithFileData:[parameters objectForKey:kPiwigoImagesUploadParamData]
                                                  name:@"file"
                                              fileName:[parameters objectForKey:kPiwigoImagesUploadParamFileName]
                                              mimeType:[parameters objectForKey:kPiwigoImagesUploadParamMimeType]];
                      
                      // Fixes bug #212 — pwg.images.upload: filename key is "name"
                      [formData appendPartWithFormData:[[parameters objectForKey:kPiwigoImagesUploadParamFileName] dataUsingEncoding:NSUTF8StringEncoding]
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
//                                       [manager invalidateSessionCancelingTasks:YES];
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                       NSLog(@"NetworkHandler/post Error: %@", error);
#endif
                                       if(fail) {
                                           fail(task, error);
                                       }
//                                       [manager invalidateSessionCancelingTasks:YES];
                                   }];
    
    return task;
}

+(NSString*)getURLWithPath:(NSString*)path asPiwigoRequest:(BOOL)piwigo withURLParams:(NSDictionary*)params
{
    // Servers sometimes return http://… instead of https://…
    NSString *cleanPath = [path stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    cleanPath = [cleanPath stringByReplacingOccurrencesOfString:[Model sharedInstance].serverName withString:@""];
    
    // Remove the .php? prefix if any
    NSString *prefix = @"";
    NSRange pos = [cleanPath rangeOfString:@".php?"];
    if (pos.location != NSNotFound ) {
        // The path contains .php?
        pos.length += pos.location;
        pos.location = 0;
        prefix = [cleanPath substringWithRange:pos];
        cleanPath = [cleanPath stringByReplacingOccurrencesOfString:prefix withString:@""];
    }

    // Path may not be encoded
//    NSLog(@"path (before) => %@", cleanPath);
    NSString *decodedPath = [cleanPath stringByRemovingPercentEncoding];
    if ([cleanPath isEqualToString:decodedPath]) {
        // Path is not encoded
        NSCharacterSet *allowedCharacters = [NSCharacterSet URLPathAllowedCharacterSet];
        cleanPath = [cleanPath stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    }
//    NSLog(@"path (after) => %@", cleanPath);

    // Copy parameters in URL
    for(NSString *parameter in params)
    {
        NSString *replaceMe = [NSString stringWithFormat:@"{%@}", parameter];
        NSString *toReplace = [NSString stringWithFormat:@"%@", [params objectForKey:parameter]];
        cleanPath = [cleanPath stringByReplacingOccurrencesOfString:replaceMe withString:toReplace];
    }
    
    // Compile final URL
    NSString *url = [NSString stringWithFormat:@"%@%@%@%@%@",
                     [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName,
                     piwigo ? @"/ws.php?" : @"", prefix, cleanPath];
    
//    NSLog(@"path (final) => %@", url);
    return url;
}

+(void)showConnectionError:(NSError*)error
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
                                message:[NSString stringWithFormat:@"%@", [error localizedDescription]]
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}

@end

