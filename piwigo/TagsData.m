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

-(void)addTagList:(NSArray*)newTags
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

-(void)getTagsOnCompletion:(void (^)(NSArray *tags))completion
{
	[TagsService getTagsOnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
		if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
		{
			NSArray *tags = [self parseTagsJson:response];
			[self addTagList:tags];
			if(completion)
			{
				completion(self.tagList);
			}
		}
	} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
		NSLog(@"Failed to get Tags: %@", [error localizedDescription]);
	}];
}

-(NSArray*)parseTagsJson:(NSDictionary*)json
{
	NSMutableArray *tags = [NSMutableArray new];
	
	NSDictionary *tagsArray = [[json objectForKey:@"result"] objectForKey:@"tags"];
	
	for(NSDictionary *tagData in tagsArray)
	{
		PiwigoTagData *newTagData = [PiwigoTagData new];
		newTagData.tagId = [[tagData objectForKey:@"id"] integerValue];
		newTagData.tagName = [tagData objectForKey:@"name"];
		[tags addObject:newTagData];
	}
	
	return tags;
}

@end
