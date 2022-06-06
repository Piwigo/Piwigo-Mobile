//
//  NetworkHandler.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <AFNetworking/AFImageDownloader.h>

#import "NetworkHandler.h"
#import "MBProgressHUD.h"

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

// Piwigo URLs:
//NSString * const kReflectionGetMethodList = @"format=json&method=reflection.getMethodList";
//NSString * const kPiwigoSessionLogin = @"format=json&method=pwg.session.login";
//NSString * const kPiwigoSessionGetStatus = @"format=json&method=pwg.session.getStatus";
//NSString * const kCommunitySessionGetStatus = @"format=json&method=community.session.getStatus";
NSString * const kPiwigoSessionGetPluginsList = @"format=json&method=pwg.plugins.getList";
//NSString * const kPiwigoSessionLogout = @"format=json&method=pwg.session.logout";

//NSString * const kPiwigoCategoriesGetList = @"format=json&method=pwg.categories.getList";
//NSString * const kCommunityCategoriesGetList = @"format=json&method=community.categories.getList";
NSString * const kPiwigoCategoriesGetImages = @"format=json&method=pwg.categories.getImages";
//NSString * const kPiwigoCategoriesAdd = @"format=json&method=pwg.categories.add";
//NSString * const kPiwigoCategoriesSetInfo = @"format=json&method=pwg.categories.setInfo";
//NSString * const kPiwigoCategoriesDelete = @"format=json&method=pwg.categories.delete";
//NSString * const kPiwigoCategoriesMove = @"format=json&method=pwg.categories.move";
//NSString * const kPiwigoCategoriesSetRepresentative = @"format=json&method=pwg.categories.setRepresentative";
//NSString * const kPiwigoCategoriesRefreshRepresentative = @"format=json&method=pwg.categories.refreshRepresentative";

//NSString * const kPiwigoImagesGetInfo = @"format=json&method=pwg.images.getInfo";
//NSString * const kPiwigoImageSetInfo = @"format=json&method=pwg.images.setInfo";
//NSString * const kPiwigoImageDelete = @"format=json&method=pwg.images.delete";
NSString * const kPiwigoImageSearch = @"format=json&method=pwg.images.search";

NSString * const kPiwigoTagsGetList = @"format=json&method=pwg.tags.getList";
NSString * const kPiwigoTagsGetAdminList = @"format=json&method=pwg.tags.getAdminList";
NSString * const kPiwigoTagsGetImages = @"format=json&method=pwg.tags.getImages";
NSString * const kPiwigoTagsAdd = @"format=json&method=pwg.tags.add";

//NSString * const kPiwigoUserFavoritesAdd = @"format=json&method=pwg.users.favorites.add";
//NSString * const kPiwigoUserFavoritesRemove = @"format=json&method=pwg.users.favorites.remove";
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


#pragma mark - Session Managers

+(void)createJSONdataSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 30;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 4;       // 4 is the advised default value
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    if (@available(iOS 11.0, *)) {
        config.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;
    } else {
        // Fallback on earlier versions
    }
    
    // Create session manager
    NetworkVarsObjc.sessionManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [NetworkVarsObjc.sessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    NetworkVarsObjc.sessionManager.responseSerializer = serializer;

    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [NetworkVarsObjc.sessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            NSURLCredential *credentialForTrust = [self didRequestServerTrust:challenge withPolicy:policy];
            if (credentialForTrust != nil) {
                *credential = credentialForTrust;
                return NSURLSessionAuthChallengeUseCredential;
            }
            return NSURLSessionAuthChallengeRejectProtectionSpace;
        }
        
        return NSURLSessionAuthChallengeRejectProtectionSpace;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [NetworkVarsObjc.sessionManager setAuthenticationChallengeHandler:^id _Nonnull(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable)) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            NSURLCredential *credential = [self didRequestHTTPBasicAuthentication:challenge];
            if (credential != nil) {
                return credential;
            }
            return @(NSURLSessionAuthChallengeRejectProtectionSpace);
        }
        return @(NSURLSessionAuthChallengeRejectProtectionSpace);
    }];
}

+(void)createFavoritesDataSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 30;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 1;       // 1 is the advised default value
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    if (@available(iOS 11.0, *)) {
        config.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;
    } else {
        // Fallback on earlier versions
    }
    
    // Create session manager
    NetworkVarsObjc.favoritesManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]] sessionConfiguration:config];
        
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [NetworkVarsObjc.favoritesManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    NetworkVarsObjc.favoritesManager.responseSerializer = serializer;

    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [NetworkVarsObjc.favoritesManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            NSURLCredential *credentialForTrust = [self didRequestServerTrust:challenge withPolicy:policy];
            if (credentialForTrust != nil) {
                *credential = credentialForTrust;
                return NSURLSessionAuthChallengeUseCredential;
            }
            return NSURLSessionAuthChallengeRejectProtectionSpace;
        }
        
        return NSURLSessionAuthChallengeRejectProtectionSpace;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [NetworkVarsObjc.favoritesManager setAuthenticationChallengeHandler:^id _Nonnull(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable)) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            NSURLCredential *credential = [self didRequestHTTPBasicAuthentication:challenge];
            if (credential != nil) {
                return credential;
            }
            return @(NSURLSessionAuthChallengeRejectProtectionSpace);
        }
        return @(NSURLSessionAuthChallengeRejectProtectionSpace);
    }];
}

+(void)createImagesSessionManager
{
    // AFNetworking only uses a memory cache so we store thumbnails in it and
    // rely on NSURLCache to store shared and previewed images in disk cache.
    NetworkVarsObjc.imageCache = [[NSURLCache alloc]
                             initWithMemoryCapacity:0
                                       diskCapacity:AppVars.shared.diskCache * 1024 * 1024
                                           diskPath:@"com.alamofire.imagedownloader"];
    // Configuration
    NSURLSessionConfiguration *config = [AFImageDownloader defaultURLSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 60;          // 60 seconds is the advised default value
    config.HTTPMaximumConnectionsPerHost = 4;       // 4 is the advised default value
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    config.URLCache = NetworkVarsObjc.imageCache;
    config.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    if (@available(iOS 11.0, *)) {
        config.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;
    } else {
        // Fallback on earlier versions
    }

    // Create session manager
    NetworkVarsObjc.imagesSessionManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]] sessionConfiguration:config];
    
    // Create image downloader
    NetworkVarsObjc.thumbnailCache = [[AFAutoPurgingImageCache alloc] initWithMemoryCapacity:AppVars.shared.memoryCache * 1024 * 1024 preferredMemoryCapacity:AppVars.shared.memoryCache * 1024 * 768];
    AFImageDownloader *imageDownloader = [[AFImageDownloader alloc] initWithSessionManager:NetworkVarsObjc.imagesSessionManager downloadPrioritization:AFImageDownloadPrioritizationFIFO maximumActiveDownloads:4 imageCache:NetworkVarsObjc.thumbnailCache];
    [UIImageView setSharedImageDownloader:imageDownloader];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [NetworkVarsObjc.imagesSessionManager setSecurityPolicy:policy];
    
    // Add "text/plain" and "text/html" to response serializer (cases where URLs are forwarded)
    AFImageResponseSerializer *serializer = [[AFImageResponseSerializer alloc] init];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/html"];
    NetworkVarsObjc.imagesSessionManager.responseSerializer = serializer;

    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [NetworkVarsObjc.imagesSessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            NSURLCredential *credentialForTrust = [self didRequestServerTrust:challenge withPolicy:policy];
            if (credentialForTrust != nil) {
                *credential = credentialForTrust;
                return NSURLSessionAuthChallengeUseCredential;
            }
            return NSURLSessionAuthChallengeRejectProtectionSpace;
        }
        return NSURLSessionAuthChallengeRejectProtectionSpace;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [NetworkVarsObjc.imagesSessionManager setAuthenticationChallengeHandler:^id _Nonnull(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable)) {
//    [NetworkVars.imagesSessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {

#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            NSURLCredential *credential = [self didRequestHTTPBasicAuthentication:challenge];
            if (credential != nil) {
                return credential;
            }
            return @(NSURLSessionAuthChallengeRejectProtectionSpace);
        }
        return @(NSURLSessionAuthChallengeRejectProtectionSpace);
    }];
}

+(AFHTTPSessionManager *)createUploadSessionManager
{
    // Configuration
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.allowsCellularAccess = YES;
    config.timeoutIntervalForRequest = 60;          // 60 seconds is the advised default value
    config.timeoutIntervalForResource = 60;         // Maximum amount of time that a resource request is allowed to take
    config.HTTPMaximumConnectionsPerHost = 2;       // 4 is the advised default value
    config.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    config.HTTPShouldSetCookies = YES;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    config.URLCache = nil;
    if (@available(iOS 11.0, *)) {
        config.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;
    } else {
        // Fallback on earlier versions
    }

    // Create session manager
    AFHTTPSessionManager *imageUploadManager = [[AFHTTPSessionManager manager] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]] sessionConfiguration:config];
    
    // Security policy
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
    [imageUploadManager setSecurityPolicy:policy];
    
    // Add "text/plain" to response serializer
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    serializer.acceptableContentTypes = [serializer.acceptableContentTypes setByAddingObject:@"text/plain"];
    imageUploadManager.responseSerializer = serializer;
    
    // Session-Wide Authentication Challenges
    // Perform server trust authentication (certificate validation)
    [imageUploadManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential * _Nullable __autoreleasing * _Nullable credential) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust)
        {
            NSURLCredential *credentialForTrust = [self didRequestServerTrust:challenge withPolicy:policy];
            if (credentialForTrust != nil) {
                *credential = credentialForTrust;
                return NSURLSessionAuthChallengeUseCredential;
            }
            return NSURLSessionAuthChallengeRejectProtectionSpace;
        }
        
        return NSURLSessionAuthChallengeRejectProtectionSpace;
    }];

    // Task-Specific Authentication Challenges
    // For servers performing HTTP Basic/Digest Authentication
    [imageUploadManager setAuthenticationChallengeHandler:^id _Nonnull(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, void (^ _Nonnull completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable)) {
        
#if defined(DEBUG_SESSION)
        NSLog(@"===>> didReceiveAuthenticationChallenge: %@", challenge.protectionSpace);
#endif
        if ((challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic) ||
            (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest))
        {
            NSURLCredential *credential = [self didRequestHTTPBasicAuthentication:challenge];
            if (credential != nil) {
                return credential;
            }
            return @(NSURLSessionAuthChallengeRejectProtectionSpace);
        }
        return @(NSURLSessionAuthChallengeRejectProtectionSpace);
    }];
    return imageUploadManager;
}


#pragma mark - Authentication Methods

+(NSURLCredential *)didRequestServerTrust:(NSURLAuthenticationChallenge *)challenge
                               withPolicy:(AFSecurityPolicy *)policy
{
    // Initialise SSL certificate approval flag
    NetworkVarsObjc.didRejectCertificate = NO;

    // Evaluate the trust the standard way.
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    NSString *strURL = [NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];
    NSURL *serverURL = [NSURL URLWithString:strURL];
    BOOL trusted = [policy evaluateServerTrust:trust forDomain:serverURL.host];
#if defined(DEBUG_SESSION)
    NSLog(@"===>> trusted: %@ (%@:%@)", trusted ? @"Yes" : @"No", serverURL.host, serverURL.port);
#endif
    // If the standard policy says that it's trusted, allow it right now.
    if (trusted) {
        return [NSURLCredential credentialForTrust:trust];
    }
    
    // If there is no certificate, report an error (should rarely happen)
    if (SecTrustGetCertificateCount(trust) == 0) {
        // No certificate!
        NetworkVarsObjc.didRejectCertificate = YES;
        return nil;
    }

    // Retrieve the certificate of the server
    SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);

    // Get certificate in Keychain if it exists
    // Certificates are stored in the Keychain with label "Piwigo:<host>"
    SecCertificateRef storedCertificate = NULL;
    NSDictionary *getQuery = @{ (id)kSecClass:      (id)kSecClassCertificate,
                                (id)kSecAttrLabel:  [NSString stringWithFormat:@"Piwigo:%@", serverURL.host],
                                (id)kSecMatchLimit: (id)kSecMatchLimitOne,
                                (id)kSecReturnRef:  (id)kCFBooleanTrue,
    };
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getQuery,
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
#if defined(DEBUG_SESSION)
            NSLog(@"===>> certificate found in Keychain ;-)");
#endif
            // Release certificate after use and trust server
            if (storedCertificate) { CFRelease(storedCertificate); }
            return [NSURLCredential credentialForTrust:trust];
        }
    }

    // No certificate or different non-trusted certificate found in Keychain for that host
#if defined(DEBUG_SESSION)
    NSLog(@"===>> non-trusted certificate of server not found in Keychain ;-)");
#endif
    // Does the user trust this server?
    if (NetworkVarsObjc.didApproveCertificate) {
        // The user trusts this server.
        if (storedCertificate) {
            // Delete certificate in Keychain (updating the certificate data is not sufficient)
#if defined(DEBUG_SESSION)
            NSLog(@"===>> delete certificate from Keychain…");
#endif
            NSDictionary *delQuery = @{ (id)kSecClass:      (id)kSecClassCertificate,
                                        (id)kSecAttrLabel:  [NSString stringWithFormat:@"Piwigo:%@", serverURL.host],
            };
            OSStatus status = SecItemDelete((CFDictionaryRef)delQuery);
//                    NSDictionary *changes = @{(__bridge NSString *)kSecValueData : (__bridge_transfer NSData *)SecCertificateCopyData(storedCertificate)};
//                    OSStatus status = SecItemUpdate((CFDictionaryRef)delQuery, (CFDictionaryRef)changes);
            CFRelease(storedCertificate);
            if (status != errSecSuccess) {
                // Handle the error
                // See https://www.osstatus.com/search/results?platform=all&framework=all&search=-50
#if defined(DEBUG_SESSION)
                NSLog(@"===>> could not delete certificate from Keychain, error %d", (int)status);
#endif
            }
        }

        // Store server certificate in Keychain with same label "Piwigo:<host>"
#if defined(DEBUG_SESSION)
        NSLog(@"===>> store new non-trusted certificate in Keychain…");
#endif
        NSDictionary* addquery = @{ (id)kSecValueRef:   (__bridge id)certificate,
                                    (id)kSecClass:      (id)kSecClassCertificate,
                                    (id)kSecAttrLabel:  [NSString stringWithFormat:@"Piwigo:%@", serverURL.host],
        };
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addquery, NULL);
        if (status != errSecSuccess) {
            // Handle the error
            // See https://www.osstatus.com/search/results?platform=all&framework=all&search=-50
#if defined(DEBUG_SESSION)
            NSLog(@"===>> could not store non-trusted certificate in Keychain, error %d", (int)status);
#endif
        }

        // Will reject a connection if the certificate is changed during a session
        // but it will still be possible to logout.
        NetworkVarsObjc.didApproveCertificate = NO;
        
        // Accept connection
        return [NSURLCredential credentialForTrust:trust];
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
    NetworkVarsObjc.certificateInformation = [certString copy];
    NetworkVarsObjc.didRejectCertificate = YES;
#if defined(DEBUG_SESSION)
    NSLog(@"===>> Certificate: %@", certString);
#endif
    return nil;
}

+(NSURLCredential *)didRequestHTTPBasicAuthentication:(NSURLAuthenticationChallenge *)challenge
{
    // Initialise HTTP authentication flag
    NetworkVarsObjc.didFailHTTPauthentication = NO;
    
    // Get HTTP basic authentification credentials
    NSString *user = NetworkVarsObjc.httpUsername;
    NSString *password = [KeychainUtilitiesObjc passwordForService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:user];
    
    // Without HTTP credentials available, tries Piwigo credentials
    if ((user == nil) || (user.length <= 0) || (password == nil)) {
        user  = NetworkVarsObjc.username;
        password = [KeychainUtilitiesObjc passwordForService:NetworkVarsObjc.serverPath account:user];
        if (password == nil) password = @"";
        
        NetworkVarsObjc.httpUsername = user;
        [KeychainUtilitiesObjc setPassword:password forService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:user];
    }
    
    // Supply requested credentials if not provided yet
    if (challenge.previousFailureCount == 0) {
        // Try HTTP credentials…
        NSURLCredential *credential = [NSURLCredential
                       credentialWithUser:user
                       password:password
                       persistence:NSURLCredentialPersistenceSynchronizable];
        return credential;
    }
    
    // HTTP credentials refused... delete them in Keychain
    [KeychainUtilitiesObjc deletePasswordForService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:user];

    // Remember failed HTTP authentication
    NetworkVarsObjc.didFailHTTPauthentication = YES;
    return nil;
}


#pragma mark - Tasks Methods

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
                    NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];
        }
        authority = [leftURL substringWithRange:NSMakeRange(0, range.location)];
        leftURL = [leftURL stringByReplacingOccurrencesOfString:authority withString:@"" options:0 range:NSMakeRange(0, authority.length)];
        
        // The Piwigo server may not be in the root e.g. example.com/piwigo/…
        // So we remove the path to avoid a duplicate if necessary
        NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]];
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
                           NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath, path];
        }
        else {
            // URL seems to contain a query
            path = [leftURL substringWithRange:NSMakeRange(0, range.location+1)];
            path = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
            leftURL = [leftURL stringByReplacingOccurrencesOfString:path withString:@"" options:0 range:NSMakeRange(0, path.length)];
            leftURL = [leftURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            originalURL = [NSString stringWithFormat:@"%@%@%@%@",
                           NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath, path, leftURL];
        }
    }
    
    serverURL = [NSURL URLWithString:originalURL];
    if (serverURL == nil) {
        // The URL is still not RFC compliant —> return image.jpg to avoid a crash
        return [NSString stringWithFormat:@"%@%@/image.jpg",
                NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];
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
    NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]];
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
                                 NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath, prefix, cleanPath];
    
#if defined(DEBUG_SESSION)
    if (![encodedImageURL isEqualToString:originalURL]) {
        NSLog(@"=> originalURL:%@", originalURL);
        NSLog(@"    encodedURL:%@", encodedImageURL);
        NSLog(@"   path=%@, parameterString=%@, query:%@, fragment:%@", serverURL.path, serverURL.parameterString, serverURL.query, serverURL.fragment);
    }
#endif
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
                NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath];
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
    NSURL *loginURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath]];
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
                     NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath, prefix, cleanPath];
    
#if defined(DEBUG_SESSION)
    if (![url isEqualToString:originalURL]) {
        NSLog(@"=> %@ (%@)", originalURL, params);
        NSLog(@"   %@", url);
        NSLog(@"   path=%@, parameterString=%@, query:%@, fragment:%@", serverURL.path, serverURL.parameterString, serverURL.query, serverURL.fragment);
    }
#endif
    return url;
}

// path: format={param1}
// URLParams: {@"param1" : @"hello" }
+(NSURLSessionTask*)post:(NSString*)path
           URLParameters:(NSDictionary*)urlParams
              parameters:(NSDictionary*)parameters
          sessionManager:(AFHTTPSessionManager *)sessionManager
                progress:(void (^)(NSProgress *))progress
                 success:(void (^)(NSURLSessionTask *task, id responseObject))success
                 failure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
    NSURLSessionTask *task = [sessionManager
                              POST:[NetworkHandler getURLWithPath:path withURLParams:urlParams]
                              parameters:parameters headers:nil
                              progress:progress
                              success:^(NSURLSessionTask *task, id responseObject) {
#if defined(DEBUG_SESSION)
        NSLog(@"••> post request URL: %@", task.originalRequest.URL);
        NSLog(@"••> post request HTTP headers: %@", task.originalRequest.allHTTPHeaderFields);
        NSLog(@"••> post request HttpBody: %@ i.e. \"%@\"", task.originalRequest.HTTPBody, [[NSString alloc] initWithData:task.originalRequest.HTTPBody encoding:NSUTF8StringEncoding]);
        
        NSLog(@"••> post response URL: %@", task.response.URL);
        NSLog(@"••> post response MIME: %@", task.response.MIMEType);
        NSLog(@"••> post response Encoding: %@", task.response.textEncodingName);
#endif
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


#pragma mark - Piwigo Errors

+(NSError *)getPiwigoErrorFromResponse:(id)responseObject path:(NSString *)path andURLparams:(NSDictionary *)urlParams
{
    NSInteger errorCode = NSNotFound;
    if ([responseObject objectForKey:@"err"]) {
        errorCode = [[responseObject objectForKey:@"err"] intValue];
    }
    NSString *errorMsg = @"";
    if ([responseObject objectForKey:@"message"]) {
        errorMsg = [responseObject objectForKey:@"message"];
    }
    NSString *url = [self getURLWithPath:path withURLParams:urlParams];

    NSError *error;
    switch (errorCode) {
        case kInvalidMethod:
            error = [NSError errorWithDomain:url code:errorCode userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r%@", errorMsg.length ? errorMsg : NSLocalizedString(@"serverInvalidMethodError_message", @"Failed to call server method."), url]}];
            break;
            
        case kMissingParameter:
            error = [NSError errorWithDomain:url code:errorCode userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r%@", errorMsg.length ? errorMsg : NSLocalizedString(@"serverMissingParamError_message", @"Failed to execute server method with missing parameter."), url]}];
            break;
            
        case kInvalidParameter:
            error = [NSError errorWithDomain:url code:errorCode userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r%@", errorMsg.length ? errorMsg : NSLocalizedString(@"serverInvalidParamError_message", @"Failed to call server method with provided parameters."), url]}];
            break;
            
        default:
            error = [NSError errorWithDomain:url code:errorCode userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@\r%@", errorMsg.length ? errorMsg : NSLocalizedString(@"serverUnknownError_message", @"Unexpected error encountered while calling server method with provided parameters."), url]}];
            break;
    }
    return error;
}

+(void)showPiwigoError:(NSError*)error withCompletion:(void (^)(void))completion;
{
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error")
        message:[NSString stringWithFormat:@"%@", [error localizedDescription]]
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            if (completion) { completion(); }
    }];
    
    [alert addAction:defaultAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }

    NSArray<UIViewController *> *topViewControllers = [UIApplication.sharedApplication topViewControllers];
    for (UIViewController *topViewController in topViewControllers) {
        [topViewController presentViewController:alert animated:YES completion:^{
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange;
        }];
    }
}

@end

