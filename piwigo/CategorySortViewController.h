//
//  CategorySortViewController.h
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	kPiwigoSortCategoryIdAscending,
	kPiwigoSortCategoryIdDescending,
	kPiwigoSortCategoryNameAscending,
	kPiwigoSortCategoryNameDescending,
	kPiwigoSortCategoryDateCreatedAscending,
	kPiwigoSortCategoryDateCreatedDescending,
	kPiwigoSortCategoryFileNameAscending,
	kPiwigoSortCategoryFileNameDescending,
//	kPiwigoSortCategoryVideoOnly,
//	kPiwigoSortCategoryImageOnly,
	
	kPiwigoSortCategoryCount	
} kPiwigoSortCategory;

@protocol CategorySortDelegate <NSObject>

-(void)didSelectCategorySortType:(kPiwigoSortCategory)sortType;

@end

@interface CategorySortViewController : UIViewController

@property (nonatomic, weak) id<CategorySortDelegate> sortDelegate;
@property (nonatomic, assign) kPiwigoSortCategory currentCategorySortType;

+(NSString*)getNameForCategorySortType:(kPiwigoSortCategory)sortType;

@end
