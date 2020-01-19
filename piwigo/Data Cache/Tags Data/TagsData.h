//
//  TagsData.h
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PiwigoTagData;

@interface TagsData : NSObject

+(TagsData*)sharedInstance;

@property (nonatomic, strong) NSArray *tagList;

-(void)getTagsForAdmin:(BOOL)isAdmin onCompletion:(void (^)(NSArray *tags))completion;
-(NSString*)getTagsStringFromList:(NSArray*)tagList;
-(NSInteger)getIndexOfTag:(PiwigoTagData*)tag;
-(BOOL)listOfTags:(NSArray *)listOfTags containsTag:(PiwigoTagData *)refTag;

-(void)addTagToList:(NSArray*)newTags;
-(void)clearCache;

@end
