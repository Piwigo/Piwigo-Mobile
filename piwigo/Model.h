//
//  Model.h
//  WordSearch
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ALAssetsLibrary;

@interface Model : NSObject

+(Model*)sharedInstance;
-(void)saveToDisk;
+(ALAssetsLibrary*)defaultAssetsLibrary;

@property (nonatomic, strong) NSString *serverName;
@property (nonatomic, strong) NSString *pwgToken;

@property (nonatomic, assign) NSInteger imagesPerPage;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger lastPageImageCount;

@end
