//
//  KeychainAccess.m
//  missionprep
//
//  Created by Spencer Baker on 12/24/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "KeychainAccess.h"
#import "KeychainItemWrapper.h"

static NSString *kKeychainAppID = @"PiwigoLogin";

@implementation KeychainAccess

+(void)storeLoginInKeychainForUser:(NSString*)user andPassword:(NSString*)password
{
	KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kKeychainAppID accessGroup:nil];
	
	[keychain setObject:user forKey:(__bridge id)(kSecAttrAccount)];
	[keychain setObject:password forKey:(__bridge id)(kSecValueData)];
}

+(NSString*)getLoginUser
{
	KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kKeychainAppID accessGroup:nil];
	
	return [keychain objectForKey:(__bridge id)(kSecAttrAccount)];
}

+(NSString*)getLoginPassword
{
	KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kKeychainAppID accessGroup:nil];
	
	return [keychain objectForKey:(__bridge id)(kSecValueData)];
}

+(void)resetKeychain
{
	KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:kKeychainAppID accessGroup:nil];
	[keychain resetKeychainItem];
}

@end
