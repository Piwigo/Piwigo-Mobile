//
//  SessionService.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SessionService.h"
#import "KeychainAccess.h"
#import "Model.h"

@implementation SessionService

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
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] && [[responseObject objectForKey:@"result"] boolValue])
                      {
                          [KeychainAccess storeLoginInKeychainForUser:user andPassword:password];
                          [Model sharedInstance].username = user;
                          completion(YES, [responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          completion(NO, nil);
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

+(NSURLSessionTask*)getStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoSessionGetStatus
        URLParameters:nil
           parameters:nil
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          [Model sharedInstance].pwgToken = [[responseObject objectForKey:@"result" ] objectForKey:@"pwg_token"];
                          [Model sharedInstance].language = [[responseObject objectForKey:@"result" ] objectForKey:@"language"];
                          [Model sharedInstance].version = [[responseObject objectForKey:@"result" ] objectForKey:@"version"];
                          
                          NSString *userStatus = [[responseObject objectForKey:@"result" ] objectForKey:@"status"];
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
                      [SessionService showConnectionError:error];
                      fail(task, error);
                  }
              }];
}

+(NSURLSessionTask*)getPluginsListOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoSessionGetPluginsList
        URLParameters:nil
           parameters:nil
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      // By default, the plugin is not installed/active
                      [Model sharedInstance].hasInstalledVideoJS = NO;
                      
                      // Did the server answer the request?
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          // Collect the list of plugins
                          id pluginsList = [responseObject objectForKey:@"result"];
                          
                          // Loop over the plugins
                          for (id plugin in pluginsList) {
                              NSString *pluginID = [plugin objectForKey:@"id"];
                              NSString *pluginState = [plugin objectForKey:@"state"];
                              
                              if([pluginID isEqualToString:@"piwigo-videojs"]) {
                                  // VideoJS is installed, but is it active ?
                                  if([pluginState isEqualToString:@"active"]) {
                                      [Model sharedInstance].hasInstalledVideoJS = YES;
                                  }
                              }
                          }
                          completion([responseObject objectForKey:@"result"]);
                      }
                      else
                      {
                          completion(nil);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  
                  if(fail) {
                      [SessionService showConnectionError:error];
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
