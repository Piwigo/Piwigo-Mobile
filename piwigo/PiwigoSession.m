//
//  PiwigoNetwork.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoSession.h"
#import "KeychainAccess.h"
#import "Model.h"

@implementation PiwigoSession

+(AFHTTPRequestOperation*)performLoginWithServer:(NSString*)server
										 andUser:(NSString*)user
									 andPassword:(NSString*)password
									onCompletion:(void (^)(BOOL result, id response))completion
{
	[Model sharedInstance].serverName = server;
	[[Model sharedInstance] saveToDisk];
	
	return [self post:kPiwigoSessionLogin
		URLParameters:nil
		   parameters:@{@"username" : user,
						@"password" : password}
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"] && [[responseObject objectForKey:@"result"] boolValue])
					  {
						  [KeychainAccess storeLoginInKeychainForUser:user andPassword:password];
						  completion(YES, [responseObject objectForKey:@"result"]);
					  }
					  else
					  {
						  completion(NO, nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(completion) {
						[PiwigoSession showConnectionError:error];
				  }
			  }];
}

+(AFHTTPRequestOperation*)getStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
{
	return [self post:kPiwigoSessionGetStatus
		URLParameters:nil
		   parameters:nil
			  success:^(AFHTTPRequestOperation *operation, id responseObject) {
				  
				  if(completion) {
					  if([[responseObject objectForKey:@"stat"] isEqualToString:@"ok"])
					  {
						  [Model sharedInstance].pwgToken = [[responseObject objectForKey:@"result" ] objectForKey:@"pwg_token"];
						  completion([responseObject objectForKey:@"result"]);
					  }
					  else
					  {
						  completion(nil);
					  }
				  }
			  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
				  
				  if(completion) {
					  [PiwigoSession showConnectionError:error];
				  }
			  }];
}

@end
