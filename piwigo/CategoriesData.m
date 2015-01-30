//
//  CategoriesData.m
//  piwigo
//
//  Created by Spencer Baker on 1/29/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"

@interface CategoriesData()

@property (nonatomic, strong) NSDictionary *categories;

@end

@implementation CategoriesData

+(CategoriesData*)sharedInstance
{
	static CategoriesData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.categories = [NSDictionary new];
		
	});
	return instance;
}

-(void)addCategories:(NSArray*)categories
{
	NSMutableDictionary *newCategories = [[NSMutableDictionary alloc] initWithDictionary:self.categories];
	for(PiwigoAlbumData *categoryData in categories)
	{
		[newCategories setObject:categoryData forKey:categoryData.albumId];
	}
	self.categories = newCategories;
}

-(PiwigoImageData*)getImageForCategory:(NSString*)category andIndex:(NSInteger)index
{
	if(index > [[[CategoriesData sharedInstance].categories objectForKey:category] imageList].count) return nil;
	return [[[[CategoriesData sharedInstance].categories objectForKey:category] imageList] objectAtIndex:index];
}

@end
