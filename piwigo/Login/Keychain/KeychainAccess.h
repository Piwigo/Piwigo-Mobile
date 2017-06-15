//
//  KeychainAccess.h
//  piwigo
//
//  Created by Spencer Baker on 12/24/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *kKeychainUser = @"user";
static NSString *kKeychainPassword = @"password";

@interface KeychainAccess : NSObject

+(void)storeLoginInKeychainForUser:(NSString*)user andPassword:(NSString*)password;
+(NSString*)getLoginUser;
+(NSString*)getLoginPassword;
+(void)resetKeychain;

@end
