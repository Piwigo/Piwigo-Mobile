//
//  TagsService.m
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "Model.h"
#import "TagsService.h"

@implementation TagsService

+(NSURLSessionTask*)getTagsForAdmin:(BOOL)isAdmin
                       onCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post: isAdmin ? kPiwigoTagsGetAdminList : kPiwigoTagsGetList
		URLParameters:nil
           parameters:nil
             progress:nil
			  success:completion
			  failure:fail];
}

+(NSURLSessionTask*)addTagWithName:(NSString *)tagName
                      onCompletion:(void (^)(NSURLSessionTask *task, NSInteger tagId))completion
                         onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    return [self post:kPiwigoTagsAdd
        URLParameters:nil
           parameters:@{@"name": tagName}
             progress:nil
              success:^(NSURLSessionTask *task, id responseObject) {
                  
                  if(completion) {
                      if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
                      {
                          NSInteger tagId = [[[responseObject objectForKey:@"result"] objectForKey:@"id"] integerValue];
                          completion(task, tagId);
                      }
                      else
                      {
                          // Display Piwigo error
                          NSInteger errorCode = NSNotFound;
                          if ([responseObject objectForKey:@"err"]) {
                              errorCode = [[responseObject objectForKey:@"err"] intValue];
                          }
                          NSString *errorMsg = @"";
                          if ([responseObject objectForKey:@"message"]) {
                              errorMsg = [responseObject objectForKey:@"message"];
                          }
                          [NetworkHandler showPiwigoError:errorCode withMessage:errorMsg forPath:kPiwigoImageSearch andURLparams:nil];
                          
                          completion(task, NSNotFound);
                      }
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  // No error returned if task was cancelled
                  if (task.state == NSURLSessionTaskStateCanceling) {
                      completion(task, NSNotFound);
                  }
                  
                  // Error !
#if defined(DEBUG)
                  NSLog(@"=> addTagWithName:%@ — Failed!", tagName);
#endif
                  NSInteger statusCode = [[[error userInfo] valueForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
                  if ((statusCode == 401) ||        // Unauthorized
                      (statusCode == 403) ||        // Forbidden
                      (statusCode == 404))          // Not Found
                  {
                      NSLog(@"…notify kPiwigoNotificationNetworkErrorEncountered!");
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationNetworkErrorEncountered object:nil userInfo:nil];
                      });
                  }
                  if(fail) {
                      fail(task, error);
                  }
              }];
}

@end
