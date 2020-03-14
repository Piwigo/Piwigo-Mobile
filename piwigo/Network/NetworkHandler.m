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

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

// Piwigo URLs:
NSString * const kReflectionGetMethodList = @"format=json&method=reflection.getMethodList";
NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
NSString * const kCommunitySessionGetStatus = @"format=json&method=community.session.getStatus";
NSString * const kPiwigoSessionGetPluginsList = @"format=json&method=pwg.plugins.getList";
NSString * const kPiwigoSessionLogout = @"format=json&method=pwg.session.logout";

NSString * const kPiwigoGetInfos = @"format=json&method=pwg.getInfos";
NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList";
NSString * const kCommunityCategoriesGetList = @"format=json&method=community.categories.getList";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages";
NSString * const kPiwigoCategoriesAdd = @"format=json&method=pwg.categories.add";
NSString * const kPiwigoCategoriesSetInfo = @"format=json&method=pwg.categories.setInfo";
NSString * const kPiwigoCategoriesDelete = @"format=json&method=pwg.categories.delete";
NSString * const kPiwigoCategoriesMove = @"format=json&method=pwg.categories.move";
NSString * const kPiwigoCategoriesSetRepresentative = @"format=json&method=pwg.categories.setRepresentative";
NSString * const kPiwigoCategoriesRefreshRepresentative = @"format=json&method=pwg.categories.refreshRepresentative";

NSString * const kPiwigoImagesUpload = @"format=json&method=pwg.images.upload";
NSString * const kCommunityImagesUploadCompleted = @"format=json&method=community.images.uploadCompleted";
NSString * const kPiwigoImagesGetInfo = @"format=json&method=pwg.images.getInfo";
NSString * const kPiwigoImageSetInfo = @"format=json&method=pwg.images.setInfo";
NSString * const kPiwigoImageDelete = @"format=json&method=pwg.images.delete";
NSString * const kPiwigoImageSearch = @"format=json&method=pwg.images.search";

NSString * const kPiwigoTagsGetList = @"format=json&method=pwg.tags.getList";
NSString * const kPiwigoTagsGetAdminList = @"format=json&method=pwg.tags.getAdminList";
NSString * const kPiwigoTagsGetImages = @"format=json&method=pwg.tags.getImages";
NSString * const kPiwigoTagsAdd = @"format=json&method=pwg.tags.add";

NSString * const kPiwigoUserFavoritesAdd = @"format=json&method=pwg.users.favorites.add";
NSString * const kPiwigoUserFavoritesRemove = @"format=json&method=pwg.users.favorites.remove";
NSString * const kPiwigoUserFavoritesGetList = @"format=json&method=pwg.users.favorites.getList";

// Parameter keys:
NSString * const kPiwigoImagesUploadParamFileName = @"file";
NSString * const kPiwigoImagesUploadParamTitle = @"name";
NSString * const kPiwigoImagesUploadParamAuthor = @"author";
NSString * const kPiwigoImagesUploadParamCreationDate = @"date_creation";
NSString * const kPiwigoImagesUploadParamDescription = @"description";
NSString * const kPiwigoImagesUploadParamCategory = @"category";
NSString * const kPiwigoImagesUploadParamTags = @"tags";
NSString * const kPiwigoImagesUploadParamPrivacy = @"privacyLevel";
NSString * const kPiwigoImagesUploadParamChunk = @"chunk";
NSString * const kPiwigoImagesUploadParamChunks = @"chunks";
NSString * const kPiwigoImagesUploadParamMimeType = @"mimeType";

// Piwigo errors:
NSInteger const kInvalidMethod = 501;
NSInteger const kMissingParameter = 1002;
NSInteger const kInvalidParameter = 1003;

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
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [[Model sharedInstance].sessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    [Model sharedInstance].sessionManager.responseSerializer = serializer;

    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [[Model sharedInstance].sessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            // Evaluate the trust the standard way.
            SecTrustRef trust = challenge.protectionSpace.serverTrust;
            NSString *strURL = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
            NSURL *serverURL = [NSURL URLWithString:strURL];
            BOOL trusted = [policy evaluateServerTrust:trust forDomain:serverURL.host];
            NSLog(@"===>> trusted: %@ (%@:%@)", trusted ? @"Yes" : @"No", serverURL.host, serverURL.port);

            // If the standard policy says that it's trusted, allow it right now.
            if (trusted) {
                *credential = [NSURLCredential credentialForTrust:trust];
                return NSURLSessionAuthChallengeUseCredential;
            }
            
            // If there is not certificate, report an error (should rarely happen)
            if (SecTrustGetCertificateCount(trust) == 0) {
                // No certificate!
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }

            // Retrieve the certificate of the server
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);

            // Get certificate in Keychain if it exists
            SecCertificateRef storedCertificate = NULL;
            NSDictionary *getquery = @{ (id)kSecClass:     (id)kSecClassCertificate,
                                        (id)kSecAttrLabel: serverURL.host,
                                        (id)kSecReturnRef: @YES,
            };
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                                  (CFTypeRef *)&storedCertificate);
            if (status == errSecSuccess) {
                // A certificate exists for that host.
                // Does it match the one of the server?
                NSData* certData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(certificate)
                );
                NSData* storedData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(storedCertificate)
                );
                if ([certData isEqualToData:storedData]) {
                    // Certificates are identical
                    NSLog(@"===>> certificate found in Keychain ;-)");
                    // Release certificate after use and trust server
                    if (storedCertificate) { CFRelease(storedCertificate); }
                    *credential = [NSURLCredential credentialForTrust:trust];
                    return NSURLSessionAuthChallengeUseCredential;
                }
            }

            // Release potential stored certificate after use
            if (storedCertificate) { CFRelease(storedCertificate); }

            // No certificate found in Keychain for that host
            // Does the user trust this server?
            if ([Model sharedInstance].didApproveCertificate) {
                // The user trusts this server.
                // Store server certificate in Keychain
                NSDictionary* addquery = @{ (id)kSecValueRef:   (__bridge id)certificate,
                                            (id)kSecClass:      (id)kSecClassCertificate,
                                            (id)kSecAttrLabel:  serverURL.host,
                };
                OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addquery, NULL);
                if (status != errSecSuccess) {
                    // Handle the error
                    NSLog(@"===>> could not store certificate in Keychain");
                }
                
                // Accepts connection
                [Model sharedInstance].didApproveCertificate = NO;
                *credential = [NSURLCredential credentialForTrust:trust];
                return NSURLSessionAuthChallengeUseCredential;
            }
            
            // Ask user whether we should trust this server
            // Compile string that will be presented to the user
            NSMutableString *certString = [NSMutableString new];
            [certString appendFormat:@"(%@", serverURL.host];

            // Summary, e.g. "QNAP NAS"
            NSString* summary = (NSString*)CFBridgingRelease(SecCertificateCopySubjectSummary(certificate));
            if (summary.length > 0) {
                [certString appendFormat:@", %@", summary];
            }

            // Email, e.g. support@qnap.com
            if (@available(iOS 10.0, *))
            {
                CFArrayRef emailAddressesRef;
                OSStatus status = SecCertificateCopyEmailAddresses(certificate, &emailAddressesRef);
                if (status == errSecSuccess)
                {
                    NSArray *emailAddresses = (__bridge NSArray *)emailAddressesRef;
                    if ([emailAddresses count]) {
                        [certString appendFormat:@", %@", [emailAddresses firstObject]];
                    }
                    CFRelease(emailAddressesRef);
                }
            }
            [certString appendString:@")"];
            [Model sharedInstance].certificateInformation = [certString copy];
            [Model sharedInstance].didRequestCertificateApproval = YES;
            NSLog(@"===>> Certificate: %@", certString);
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [[Model sharedInstance].sessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            // To remember app received anthentication challenge
            [Model sharedInstance].didRequestHTTPauthentication = YES;

            // HTTP basic authentification credentials
            NSString *user = [Model sharedInstance].HttpUsername;
            NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            
            // Without HTTP credentials available, tries Piwigo credentials
            if ((user == nil) || (user.length <= 0) || (password == nil)) {
                user  = [Model sharedInstance].username;
                password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
                if (password == nil) password = @"";
                
                [Model sharedInstance].HttpUsername = user;
                [[Model sharedInstance] saveToDisk];
                [SAMKeychain setPassword:password forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            }
            
            // Supply requested credentials if not provided yet
            if (challenge.previousFailureCount == 0) {
                // Trying HTTP credentials…
                *credential = [NSURLCredential
                               credentialWithUser:user
                               password:password
                               persistence:NSURLCredentialPersistenceSynchronizable];
                return NSURLSessionAuthChallengeUseCredential;
            } else {
                // HTTP credentials refused!
                [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];
//#if defined(DEBUG_SESSION)
//    NSLog(@"=> JSON data session manager created");
//#endif
}

+(void)createImagesSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 60;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 4;       // 4 is the advised default value

    // Create session manager
    [Model sharedInstance].imagesSessionManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [[Model sharedInstance].imagesSessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" and "text/html" to response serializer (cases where URLs are forwarded)
    AFImageResponseSerializer *serializer = [[AFImageResponseSerializer alloc] init];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/html"];
    [Model sharedInstance].imagesSessionManager.responseSerializer = serializer;

    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [[Model sharedInstance].imagesSessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            // Evaluate the trust the standard way.
            SecTrustRef trust = challenge.protectionSpace.serverTrust;
            NSString *strURL = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
            NSURL *serverURL = [NSURL URLWithString:strURL];
            BOOL trusted = [policy evaluateServerTrust:trust forDomain:serverURL.host];
            NSLog(@"===>> trusted: %@ (%@:%@)", trusted ? @"Yes" : @"No", serverURL.host, serverURL.port);

            // If the standard policy says that it's trusted, allow it right now.
            if (trusted) {
                *credential = [NSURLCredential credentialForTrust:trust];
                return NSURLSessionAuthChallengeUseCredential;
            }
            
            // If there is not certificate, report an error (should rarely happen)
            if (SecTrustGetCertificateCount(trust) == 0) {
                // No certificate!
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }

            // Retrieve the certificate of the server
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);

            // Get certificate in Keychain (should exist)
            SecCertificateRef storedCertificate = NULL;
            NSDictionary *getquery = @{ (id)kSecClass:     (id)kSecClassCertificate,
                                        (id)kSecAttrLabel: serverURL.host,
                                        (id)kSecReturnRef: @YES,
            };
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                                  (CFTypeRef *)&storedCertificate);
            if (status == errSecSuccess) {
                // A certificate exists for that host.
                // Does it match the one of the server?
                NSData* certData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(certificate)
                );
                NSData* storedData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(storedCertificate)
                );
                if ([certData isEqualToData:storedData]) {
                    // Certificates are identical
                    NSLog(@"===>> certificate found in Keychain ;-)");
                    // Release certificate after use and trust server
                    if (storedCertificate) { CFRelease(storedCertificate); }
                    *credential = [NSURLCredential credentialForTrust:trust];
                    return NSURLSessionAuthChallengeUseCredential;
                }
            }

            // Release potential stored certificate after use
            if (storedCertificate) { CFRelease(storedCertificate); }
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [[Model sharedInstance].imagesSessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            // To remember app received anthentication challenge
            [Model sharedInstance].didRequestHTTPauthentication = YES;

            // HTTP basic authentification credentials
            NSString *user = [Model sharedInstance].HttpUsername;
            NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            
            // Without HTTP credentials available, tries Piwigo credentials
            if ((user == nil) || (user.length <= 0) || (password == nil)) {
                user  = [Model sharedInstance].username;
                password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
                if (password == nil) password = @"";

                [Model sharedInstance].HttpUsername = user;
                [[Model sharedInstance] saveToDisk];
                [SAMKeychain setPassword:password forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            }
            
            // Supply requested credentials if not provided yet
            if (challenge.previousFailureCount == 0) {
                // Trying HTTP credentials…
                *credential = [NSURLCredential
                               credentialWithUser:user
                               password:password
                               persistence:NSURLCredentialPersistenceSynchronizable];
                return NSURLSessionAuthChallengeUseCredential;
            } else {
                // HTTP credentials refused!
                [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];
//#if defined(DEBUG_SESSION)
//    NSLog(@"=> Images session manager created");
//#endif
}

+(void)createUploadSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 60;          // 60 seconds is the advised default value
    config.timeoutIntervalForResource = 60;         // Maximum amount of time that a resource request is allowed to take
    config.HTTPMaximumConnectionsPerHost = 2;       // 4 is the advised default value
    config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    config.URLCache = nil;
    
    // Create session manager
    [Model sharedInstance].imageUploadManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [[Model sharedInstance].imageUploadManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    [Model sharedInstance].imageUploadManager.responseSerializer = serializer;
    
    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [[Model sharedInstance].imageUploadManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            // Evaluate the trust the standard way.
            SecTrustRef trust = challenge.protectionSpace.serverTrust;
            NSString *strURL = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
            NSURL *serverURL = [NSURL URLWithString:strURL];
            BOOL trusted = [policy evaluateServerTrust:trust forDomain:serverURL.host];
            NSLog(@"===>> trusted: %@ (%@:%@)", trusted ? @"Yes" : @"No", serverURL.host, serverURL.port);

            // If the standard policy says that it's trusted, allow it right now.
            if (trusted) {
                *credential = [NSURLCredential credentialForTrust:trust];
                return NSURLSessionAuthChallengeUseCredential;
            }
            
            // If there is not certificate, report an error (should rarely happen)
            if (SecTrustGetCertificateCount(trust) == 0) {
                // No certificate!
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }

            // Retrieve the certificate of the server
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);

            // Get certificate in Keychain (should exist)
            SecCertificateRef storedCertificate = NULL;
            NSDictionary *getquery = @{ (id)kSecClass:     (id)kSecClassCertificate,
                                        (id)kSecAttrLabel: serverURL.host,
                                        (id)kSecReturnRef: @YES,
            };
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                                  (CFTypeRef *)&storedCertificate);
            if (status == errSecSuccess) {
                // A certificate exists for that host.
                // Does it match the one of the server?
                NSData* certData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(certificate)
                );
                NSData* storedData = (NSData*)CFBridgingRelease( // ARC takes ownership
                   SecCertificateCopyData(storedCertificate)
                );
                if ([certData isEqualToData:storedData]) {
                    // Certificates are identical
                    NSLog(@"===>> certificate found in Keychain ;-)");
                    // Release certificate after use and trust server
                    if (storedCertificate) { CFRelease(storedCertificate); }
                    *credential = [NSURLCredential credentialForTrust:trust];
                    return NSURLSessionAuthChallengeUseCredential;
                }
            }

            // Release potential stored certificate after use
            if (storedCertificate) { CFRelease(storedCertificate); }
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [[Model sharedInstance].imageUploadManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        NSLog(@"===>> didReceiveAuthenticationChallenge/ %@", challenge.protectionSpace);
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            // To remember app received anthentication challenge
            [Model sharedInstance].didRequestHTTPauthentication = YES;
            
            // HTTP basic authentification credentials
            NSString *user = [Model sharedInstance].HttpUsername;
            NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            
            // Without HTTP credentials available, tries Piwigo credentials
            if ((user == nil) || (user.length <= 0) || (password == nil)) {
                user  = [Model sharedInstance].username;
                password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
                if (password == nil) password = @"";
                
                [Model sharedInstance].HttpUsername = user;
                [[Model sharedInstance] saveToDisk];
                [SAMKeychain setPassword:password forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
            }
            
            // Supply requested credentials if not provided yet
            if (challenge.previousFailureCount == 0) {
                // Trying HTTP credentials…
                *credential = [NSURLCredential
                               credentialWithUser:user
                               password:password
                               persistence:NSURLCredentialPersistenceSynchronizable];
                return NSURLSessionAuthChallengeUseCredential;
            } else {
                // HTTP credentials refused!
                [SAMKeychain deletePasswordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
                return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        }
        
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }];
//#if defined(DEBUG_SESSION)
//    NSLog(@"=> Image upload session manager created");
//#endif
}

+(NSString*)encodedImageURL:(NSString*)originalURL
{
    // Return nil if originalURL is nil and a placeholder will be used
    if (originalURL == nil) return nil;
    
    // Servers may return incorrect URLs (would lead to a crash)
    // See https://tools.ietf.org/html/rfc3986#section-2
    NSURL *serverURL = [NSURL URLWithString:originalURL];
    if (serverURL == nil) {
        // URL not RFC compliant!
        NSString *leftURL = originalURL;
        NSString *authority, *path;
        
        // Remove protocol header
        if ([originalURL hasPrefix:@"http://"]) {
            leftURL = [leftURL stringByReplacingOccurrencesOfString:@"http://" withString:@"" options:0 range:NSMakeRange(0, [@"http://" length])];
        }
        if ([originalURL hasPrefix:@"https://"]) {
            leftURL = [leftURL stringByReplacingOccurrencesOfString:@"https://" withString:@"" options:0 range:NSMakeRange(0, [@"https://" length])];
        }

        // Retrieve authority
        NSRange range = [leftURL rangeOfString:@"/"];
        if (range.location == NSNotFound) {
            // No path, incomplete URL —> return image.jpg but should never happen
            return [NSString stringWithFormat:@"%@%@/image.jpg",
                    [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
        }
        authority = [leftURL substringWithRange:NSMakeRange(0, range.location)];
        leftURL = [leftURL stringByReplacingOccurrencesOfString:authority withString:@"" options:0 range:NSMakeRange(0, authority.length)];
        
        // The Piwigo server may not be in the root e.g. example.com/piwigo/…
        // So we remove the path to avoid a duplicate if necessary
        NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]];
        if ([loginURL.path length] > 0) {
            if ([leftURL hasPrefix:loginURL.path]) {
                leftURL = [leftURL stringByReplacingOccurrencesOfString:loginURL.path withString:@"" options:0 range:NSMakeRange(0, loginURL.path.length)];
            }
        }
        
        // Retrieve path
        range = [leftURL rangeOfString:@"?"];
        if (range.location == NSNotFound) {
            // No query -> remaining string is a path
            path = [leftURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
            originalURL = [NSString stringWithFormat:@"%@%@%@",
                           [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, path];
        }
        else {
            // URL seems to contain a query
            path = [leftURL substringWithRange:NSMakeRange(0, range.location+1)];
            path = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
            leftURL = [leftURL stringByReplacingOccurrencesOfString:path withString:@"" options:0 range:NSMakeRange(0, path.length)];
            leftURL = [leftURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            originalURL = [NSString stringWithFormat:@"%@%@%@%@",
                           [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, path, leftURL];
        }
    }
    
    serverURL = [NSURL URLWithString:originalURL];
    if (serverURL == nil) {
        // The URL is still not RFC compliant —> return image.jpg to avoid a crash
        return [NSString stringWithFormat:@"%@%@/image.jpg",
                [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
    }

    // Servers may return image URLs different from those used to login (e.g. wrong server settings)
    // We only keep the path+query because we only accept to download images from the same server
    NSString* cleanPath = serverURL.path;
    if (serverURL.parameterString) {
        cleanPath = [cleanPath stringByAppendingString:serverURL.parameterString];
    }
    if (serverURL.query) {
        cleanPath = [cleanPath stringByAppendingString:@"?"];
        cleanPath = [cleanPath stringByAppendingString:serverURL.query];
    }
    if (serverURL.fragment) {
        cleanPath = [cleanPath stringByAppendingString:@"#"];
        cleanPath = [cleanPath stringByAppendingString:serverURL.fragment];
    }

    // The Piwigo server may not be in the root e.g. example.com/piwigo/…
    // So we remove the path to avoid a duplicate if necessary
    NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]];
    if ([loginURL.path length] > 0) {
        if ([cleanPath hasPrefix:loginURL.path]) {
            cleanPath = [cleanPath stringByReplacingOccurrencesOfString:loginURL.path withString:@"" options:0 range:NSMakeRange(0, loginURL.path.length)];
        }
    }
    
    // Remove the .php?, i? prefixes if any
    NSString *prefix = @"";
    NSRange pos = [cleanPath rangeOfString:@"?"];
    if (pos.location != NSNotFound ) {
        // The path contains .php?
        pos.length += pos.location;
        pos.location = 0;
        prefix = [cleanPath substringWithRange:pos];
        cleanPath = [cleanPath stringByReplacingOccurrencesOfString:prefix withString:@""];
    }

    // Path may not be encoded
    NSString *decodedPath = [cleanPath stringByRemovingPercentEncoding];
    if ([cleanPath isEqualToString:decodedPath]) {
        // Path may not be encoded
        NSCharacterSet *allowedCharacters = [NSCharacterSet URLPathAllowedCharacterSet];
        cleanPath = [cleanPath stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    }
    
    // Compile final URL using the one provided at login
    NSString *encodedImageURL = [NSString stringWithFormat:@"%@%@%@%@",
                            [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, prefix, cleanPath];
    
    // For debugging purposes
    if (![encodedImageURL isEqualToString:originalURL]) {
        NSLog(@"=> originalURL:%@", originalURL);
        NSLog(@"    encodedURL:%@", encodedImageURL);
        NSLog(@"   path=%@, parameterString=%@, query:%@, fragment:%@", serverURL.path, serverURL.parameterString, serverURL.query, serverURL.fragment);
    }
    return encodedImageURL;
}

+(NSString*)getURLWithPath:(NSString*)originalURL withURLParams:(NSDictionary*)params
{
    // Return nil if path is nil
    if (originalURL == nil) return nil;
    
    // Servers may return incorrect URLs (would lead to a crash)
    NSURL *serverURL = [NSURL URLWithString:originalURL];
    if (serverURL == nil) {
        // The URL is incorrect —> return image.jpg in server home page to avoid a crash
        return [NSString stringWithFormat:@"%@%@/image.jpg",
                [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
    }
    
    // Servers may return image URLs different from those used to login
    // We only keep the path because we only accept to download images from the same server
    NSString* cleanPath = serverURL.path;
    if (serverURL.parameterString) {
        cleanPath = [cleanPath stringByAppendingString:serverURL.parameterString];
    }
    if (serverURL.query) {
        cleanPath = [cleanPath stringByAppendingString:@"?"];
        cleanPath = [cleanPath stringByAppendingString:serverURL.query];
    }
    if (serverURL.fragment) {
        cleanPath = [cleanPath stringByAppendingString:@"#"];
        cleanPath = [cleanPath stringByAppendingString:serverURL.fragment];
    }

    // The Piwigo server may not be in the root e.g. example.com/piwigo/…
    // So we remove the path to avoid a duplicate if necessary
    NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName]];
    if ([loginURL.path length] > 0) {
        if ([cleanPath hasPrefix:loginURL.path]) {
            cleanPath = [cleanPath stringByReplacingOccurrencesOfString:loginURL.path withString:@"" options:0 range:NSMakeRange(0, loginURL.path.length)];
        }
    }

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
    NSString *decodedPath = [cleanPath stringByRemovingPercentEncoding];
    if ([cleanPath isEqualToString:decodedPath]) {
        // Path is not encoded
        NSCharacterSet *allowedCharacters = [NSCharacterSet URLPathAllowedCharacterSet];
        cleanPath = [cleanPath stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    }
    
    // Copy parameters in URL
    for(NSString *parameter in params)
    {
        NSString *replaceMe = [NSString stringWithFormat:@"{%@}", parameter];
        NSString *toReplace = [NSString stringWithFormat:@"%@", [params objectForKey:parameter]];
        cleanPath = [cleanPath stringByReplacingOccurrencesOfString:replaceMe withString:toReplace];
    }
    
    // Compile final URL
    NSString *url = [NSString stringWithFormat:@"%@%@/ws.php?%@%@",
                     [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName, prefix, cleanPath];
    
    // For debugging purposes
//    if (![url isEqualToString:originalURL]) {
//        NSLog(@"=> %@ (%@)", originalURL, params);
//        NSLog(@"   %@", url);
//        NSLog(@"   path=%@, parameterString=%@, query:%@, fragment:%@", serverURL.path, serverURL.parameterString, serverURL.query, serverURL.fragment);
//    }
    return url;
}

+(NSString*)UTF8EncodedStringFromString:(NSString *)string
{
    // Return empty string is nothing provided
    if(!string || [string isKindOfClass:[NSNull class]]) {
        return @"";
    }
    
    // Convert to UTF-8 string encoding
    NSData *strData = [string dataUsingEncoding:[Model sharedInstance].stringEncoding allowLossyConversion:YES];
    return [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
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
    NSURLSessionTask *task = [[Model sharedInstance].sessionManager
                              POST:[NetworkHandler getURLWithPath:path
                                                    withURLParams:urlParams]
                                parameters:parameters
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       if (success) {
                                           success(task, responseObject);
                                       }
//                                       [manager invalidateSessionCancelingTasks:YES];
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_SESSION)
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

// Only used to upload images
+(NSURLSessionTask*)postMultiPart:(NSString*)path
                             data:(NSData*)fileData
                       parameters:(NSDictionary*)parameters
                         progress:(void (^)(NSProgress *))progress
                          success:(void (^)(NSURLSessionTask *task, id responseObject))success
                          failure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSURLSessionTask *task = [[Model sharedInstance].imageUploadManager
                              POST:[NetworkHandler getURLWithPath:path withURLParams:nil]
                        parameters:nil
         constructingBodyWithBlock:^(id<AFMultipartFormData> formData)
                {
                    [formData appendPartWithFileData:fileData
                                                name:@"file"
                                            fileName:[parameters valueForKey:kPiwigoImagesUploadParamFileName]
                                            mimeType:[parameters valueForKey:kPiwigoImagesUploadParamMimeType]];
                    
                    // Image title is mandatory and must not be empty.
                    // We provide the file name with extension and will then replace it with the image title
                    // Not doing so prevents video uploads — see bug #212 — pwg.images.upload
                    [formData appendPartWithFormData:[[parameters valueForKey:kPiwigoImagesUploadParamFileName] dataUsingEncoding:NSUTF8StringEncoding] name:@"name"];
                    
                    [formData appendPartWithFormData:[[parameters valueForKey:kPiwigoImagesUploadParamChunk] dataUsingEncoding:NSUTF8StringEncoding] name:@"chunk"];

                    [formData appendPartWithFormData:[[parameters valueForKey:kPiwigoImagesUploadParamChunks] dataUsingEncoding:NSUTF8StringEncoding] name:@"chunks"];

                    [formData appendPartWithFormData:[[parameters valueForKey:kPiwigoImagesUploadParamCategory] dataUsingEncoding:NSUTF8StringEncoding] name:@"category"];

                    [formData appendPartWithFormData:[[parameters valueForKey:kPiwigoImagesUploadParamPrivacy] dataUsingEncoding:NSUTF8StringEncoding] name:@"level"];

                    [formData appendPartWithFormData:[[Model sharedInstance].pwgToken dataUsingEncoding:NSUTF8StringEncoding] name:@"pwg_token"];
                }
                                  progress:progress
                                   success:^(NSURLSessionTask *task, id responseObject) {
                                       if (success) {
                                           success(task, responseObject);
                                       }
                                   }
                                   failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_SESSION)
                                       NSLog(@"NetworkHandler/post Error %@: %@", @([error code]), [error localizedDescription]);
                                       NSLog(@"=> localizedFailureReason: %@", [error localizedFailureReason]);
                                       NSLog(@"=> originalRequest= %@", task.originalRequest);
                                       NSLog(@"=> response= %@", task.response);
#endif
                                       if(fail) {
                                           fail(task, error);
                                       }
                                   }];
    
    return task;
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
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }

    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}

+(NSError *)getPiwigoErrorMessageFromCode:(NSInteger)code message:(NSString *)msg path:(NSString *)path andURLparams:(NSDictionary *)urlParams
{
    NSError *error;
    NSString *url = [self getURLWithPath:path withURLParams:urlParams];

    switch (code) {
        case kInvalidMethod:
            error = [NSError errorWithDomain:url code:code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r(%@)", msg.length ? msg : NSLocalizedString(@"serverInvalidMethodError_message", @"Failed to call server method."), url]}];
            break;
            
        case kMissingParameter:
            error = [NSError errorWithDomain:url code:code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r(%@)", msg.length ? msg : NSLocalizedString(@"serverMissingParamError_message", @"Failed to execute server method with missing parameter."), url]}];
            break;
            
        case kInvalidParameter:
            error = [NSError errorWithDomain:url code:code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r(%@)", msg.length ? msg : NSLocalizedString(@"serverInvalidParamError_message", @"Failed to call server method with provided parameters."), url]}];
            break;
            
        default:
            error = [NSError errorWithDomain:url code:code userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r(%@)", msg.length ? msg : NSLocalizedString(@"serverUnknownError_message", @"Unexpected error encountered while calling server method with provided parameters."), url]}];
            break;
    }
    return error;
}

+(void)showPiwigoError:(NSInteger)code withMessage:(NSString *)msg forPath:(NSString *)path andURLparams:(NSDictionary *)urlParams
{
    NSError *error = [self getPiwigoErrorMessageFromCode:code message:msg path:path andURLparams:urlParams];
    [self showConnectionError:error];
}

@end

