//
//  CategorySortViewController.h
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kPiwigoSortCategoryNameAscending,               // Photo title, A → Z
    kPiwigoSortCategoryNameDescending,              // Photo title, Z → A
    
    kPiwigoSortCategoryDateCreatedDescending,       // Date created, new → old
    kPiwigoSortCategoryDateCreatedAscending,        // Date created, old → new
    
    kPiwigoSortCategoryDatePostedDescending,        // Date posted, new → old
    kPiwigoSortCategoryDatePostedAscending,         // Date posted, old → new
    
    kPiwigoSortCategoryFileNameAscending,           // File name, A → Z
    kPiwigoSortCategoryFileNameDescending,          // File name, Z → A
    
    kPiwigoSortCategoryRatingScoreDescending,       // Rating score, high → low
    kPiwigoSortCategoryRatingScoreAscending,        // Rating score, low → high

    kPiwigoSortCategoryVisitsDescending,            // Visits, high → low
    kPiwigoSortCategoryVisitsAscending,             // Visits, low → high

    kPiwigoSortCategoryManual,                      // Manual order
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
