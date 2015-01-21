//
//  PiwigoNetwork.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoNetwork.h"
#import "Model.h"

@implementation PiwigoNetwork

+(AFHTTPRequestOperation*)performLoginWithServer:(NSString*)server
										 andUser:(NSString*)user
									 andPassword:(NSString*)password
									onCompletion:(void (^)(BOOL result, id response))completion
{
	[Model sharedInstance].serverName = server;
	[[Model sharedInstance] saveToDisk];
	
	return [self post:@"format=json"
		URLParameters:nil
		   parameters:@{@"method" : @"pwg.session.login",
						@"username" : user,
						@"password" : password}
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] && [[responseObject objectForKey:@"result"] boolValue])
					  {
						  completion(YES, [responseObject objectForKey:@"result"]);
					  }
					  else
					  {
						  completion(NO, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(completion) {
					  completion(NO, error);
				  }
			  }];
}

@end
