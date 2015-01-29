//
//  PhotosFetch.h
//  ftptest
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(id responseObject);

@interface PhotosFetch : NSObject

-(void)getLocalPhotosDictionary:(CompletionBlock)completion;

@end
