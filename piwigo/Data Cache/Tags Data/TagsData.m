//
//  TagsData.m
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TagsData.h"
#import "TagsService.h"
#import "PiwigoTagData.h"

@implementation TagsData

+(TagsData*)sharedInstance
{
	static TagsData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.tagList = [NSArray new];
	});
	return instance;
}

-(void)clearCache
{
	self.tagList = [NSArray new];
}

-(void)replaceAllTags:(NSArray*)tags
{
    // Create new list of tags
    NSMutableArray *newTags = [[NSMutableArray alloc] init];

    // Loop on freshly retrieved categories
    for(PiwigoTagData *tagData in tags)
    {
        // Is this a known tag?
        NSInteger index = [self.tagList indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PiwigoTagData *knownTag = (PiwigoTagData *)obj;
            if(knownTag.tagId == tagData.tagId)
                return YES;
            else
                return NO;
        }];
        
        // Reuse some data if possible
        if (index != NSNotFound)
        {
            // Retrieve exisiting data…
            // Nothing to keep from old list…
            // PiwigoTagData *existingTag = [self.tagList objectAtIndex:index];
        }

        // Append category to new list
        [newTags addObject:tagData];
    }
    
    // Update list of displayed categories
    self.tagList = newTags;
    
    // Post to the app that the tag data has been updated (if necessary)
//    if (self.tagList.count > 0)
//        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationTagDataUpdated object:nil];
}

-(void)addTagToList:(NSArray*)newTags
{
	NSMutableArray *tags = [[NSMutableArray alloc] initWithArray:self.tagList];
	for(PiwigoTagData *tagData in newTags)
	{
		BOOL alreadyExists = NO;
		for(PiwigoTagData *existingData in tags)
		{
			if(existingData.tagId == tagData.tagId)
			{
				alreadyExists = YES;
				break;
			}
		}
		
		if(!alreadyExists)
		{
			[tags addObject:tagData];
		}
	}
	
	self.tagList = tags;
}

-(void)getTagsForAdmin:(BOOL)isAdmin onCompletion:(void (^)(NSArray *tags))completion
{
    [TagsService getTagsForAdmin:isAdmin
                    onCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
		if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
		{
			NSArray *tags = [self parseTagsJson:response];
			[self replaceAllTags:tags];
			if(completion)
			{
				completion(self.tagList);
			}
		}
	} onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
		NSLog(@"Failed to get Tags: %@", [error localizedDescription]);
#endif
    }];
}

-(NSArray*)parseTagsJson:(NSDictionary*)json
{
	NSMutableArray *tags = [NSMutableArray new];
	
	NSDictionary *tagsArray = [[json objectForKey:@"result"] objectForKey:@"tags"];
	
	for(NSDictionary *tagData in tagsArray)
	{
        // => pwg.tags.getAdminList returns:
        // id, (lastmodified), name e.g. "Médicaments", (url_name) e.g. "divers_medicaments"
        PiwigoTagData *newTagData = [PiwigoTagData new];
        newTagData.tagId = [[tagData objectForKey:@"id"] integerValue];
        newTagData.tagName = [NetworkHandler UTF8EncodedStringFromString:[tagData objectForKey:@"name"]];
        
        // => pwg.tags.getList returns in addition: counter, url
        if ([tagData objectForKey:@"counter"]) {
            newTagData.numberOfImagesUnderTag = [[tagData objectForKey:@"counter"] integerValue];
        } else {
            newTagData.numberOfImagesUnderTag = NSNotFound;
        }

        [tags addObject:newTagData];
	}
	
	return tags;
}

-(NSString*)getTagsStringFromList:(NSArray*)tagList
{
	NSString *tagListString = @"";
    if (tagList != nil) {
        if ([tagList count] > 0)
        {
            tagListString = [[tagList firstObject] tagName];
            for(NSInteger i = 1; i < tagList.count; i++)
            {
                PiwigoTagData *tagData = [tagList objectAtIndex:i];
                tagListString = [NSString stringWithFormat:@"%@, %@", tagListString, tagData.tagName];
            }
        }
	}
	return tagListString;
}

-(NSInteger)getIndexOfTag:(PiwigoTagData*)tag
{
	NSInteger count = 0;
	for(PiwigoTagData *tagData in self.tagList)
	{
		if(tagData.tagId == tag.tagId)
		{
			return count;
		}
		count++;
	}
	return count;
}

#pragma mark - debugging support -

-(NSString *)description {
    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"tagList [%ld]  = %@", (long)self.tagList.count, self.tagList]];
    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}
    
@end
