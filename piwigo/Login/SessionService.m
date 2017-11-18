//
//  SessionService.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SessionService.h"
#import "Model.h"

@implementation SessionService

// Get Piwigo server methods
// and determine if the Community extension is installed and active
+(NSURLSessionTask*)getMethodsListOnCompletion:(void (^)(NSDictionary *methodsList))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kReflectionGetMethodList
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      
                      // Did the server answer the request? (it should have)
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          // Loop over the methods
                          id methodsList = [[responseObject objectForKey:@"result"] objectForKey:@"methods"];
                          for (NSString *method in methodsList) {
                              
                              // Check if the Community extension is installed and active (> 2.9a)
                              if([method isEqualToString:@"community.session.getStatus"]) {
                                  [Model sharedInstance].usesCommunityPluginV29 = YES;
                              }
                          }
                          completion([[responseObject objectForKey:@"result"] objectForKey:@"methods"]);
                      }
                      else  // Strange…
                      {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)performLoginWithUser:(NSString*)user
                             andPassword:(NSString*)password
                            onCompletion:(void (^)(BOOL result, id response))completion
                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    [[Model sharedInstance] saveToDisk];
    
    return [self post:kPiwigoSessionLogin
        URLParameters:nil
           parameters:@{@"username" : user,
                        @"password" : password}
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] && [[responseObject objectForKey:@"result"] boolValue])
                      {
                          [Model sharedInstance].username = user;
                          [Model sharedInstance].hadOpenedSession = YES;
                          completion(YES, [responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          // May be this server only uses HTTP authentication
                          if ([Model sharedInstance].performedHTTPauthentication) {
                              [Model sharedInstance].username = user;
                              [Model sharedInstance].hadOpenedSession = YES;
                              completion(YES, nil);
                          } else {
                              [Model sharedInstance].hadOpenedSession = NO;
                              completion(NO, nil);
                          }
                      }
                  }
              }
              failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail)
                  {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getPiwigoStatusAtLogin:(BOOL)isLogginIn
                              OnCompletion:(void (^)(NSDictionary *responseObject))completion
                                 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoSessionGetStatus
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          if (isLogginIn) {
                              [Model sharedInstance].pwgToken = [[responseObject objectForKey:@"result"] objectForKey:@"pwg_token"];
                              [Model sharedInstance].language = [[responseObject objectForKey:@"result"] objectForKey:@"language"];
                              [Model sharedInstance].version = [[responseObject objectForKey:@"result"] objectForKey:@"version"];
                              NSString *uploadFileTypes = [[responseObject objectForKey:@"result"] objectForKey:@"upload_file_types"];

                              // Images and videos can be uploaded if their file types are found.
                              // The iPhone creates mov files that will be uploaded in mp4 format.
                              [Model sharedInstance].uploadFileTypes = uploadFileTypes;
                              
                              // User rights are determined by Community extension (if installed)
                              if(![Model sharedInstance].usesCommunityPluginV29) {
                                  NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"status"];
                                  [Model sharedInstance].hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                              }
                              
                              // Collect the list of available sizes — Starting with default values
                              [Model sharedInstance].hasSquareSizeImages  = YES;
                              [Model sharedInstance].hasThumbSizeImages   = YES;
                              [Model sharedInstance].hasXXSmallSizeImages = NO;
                              [Model sharedInstance].hasXSmallSizeImages  = NO;
                              [Model sharedInstance].hasSmallSizeImages   = NO;
                              [Model sharedInstance].hasMediumSizeImages  = YES;
                              [Model sharedInstance].hasLargeSizeImages   = NO;
                              [Model sharedInstance].hasXLargeSizeImages  = NO;
                              [Model sharedInstance].hasXXLargeSizeImages = NO;
                              
                              id availableSizesList = [[responseObject objectForKey:@"result"] objectForKey:@"available_sizes"];
                              for (NSString *size in availableSizesList) {
                                  if ([size isEqualToString:@"square"]) {
                                      [Model sharedInstance].hasSquareSizeImages = YES;
                                  } else if ([size isEqualToString:@"thumb"]) {
                                      [Model sharedInstance].hasThumbSizeImages = YES;
                                  } else if ([size isEqualToString:@"2small"]) {
                                      [Model sharedInstance].hasXXSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@" "]) {
                                      [Model sharedInstance].hasXSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@"small"]) {
                                      [Model sharedInstance].hasSmallSizeImages = YES;
                                  } else if ([size isEqualToString:@"medium"]) {
                                      [Model sharedInstance].hasMediumSizeImages = YES;
                                  } else if ([size isEqualToString:@"large"]) {
                                      [Model sharedInstance].hasLargeSizeImages = YES;
                                  } else if ([size isEqualToString:@"xlarge"]) {
                                      [Model sharedInstance].hasXLargeSizeImages = YES;
                                  } else if ([size isEqualToString:@"xxlarge"]) {
                                      [Model sharedInstance].hasXXLargeSizeImages = YES;
                                  }
                              }
                          }
                          completion([responseObject objectForKey:@"result"]);
                      } else {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getCommunityStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kCommunitySessionGetStatus
        URLParameters:nil
           parameters:nil
             progress:^(NSProgress * progress) {
                 if ([Model sharedInstance].userCancelledCommunication) {
                     [progress cancel];
                 }
             }
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"real_user_status"];
                          [Model sharedInstance].hasAdminRights = ([userStatus isEqualToString:@"admin"] || [userStatus isEqualToString:@"webmaster"]);
                          
                          completion([responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)sessionLogoutOnCompletion:(void (^)(NSURLSessionTask *task, BOOL sucessfulLogout))completion
                                    onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoSessionLogout
		URLParameters:nil
           parameters:nil
             progress:nil
			  success:^(NSURLSessionTask *task, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  completion(task, [[responseObject objectForKey:@"result" ] boolValue]);
					  }
					  else
					  {
						  completion(task, NO);
					  }
				  }
			  } failure:^(NSURLSessionTask *task, NSError *error) {
				  
				  if(fail) {
                      [SessionService showConnectionError:error];
					  fail(task, error);
				  }
			  }];
}

@end
