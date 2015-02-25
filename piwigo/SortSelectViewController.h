//
//  SortSelectViewController.h
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	kPiwigoSortByName,
	kPiwigoSortByNotUploaded,
	kPiwigoSortByCount
} kPiwigoSortBy;

@protocol SortSelectViewControllerDelegate <NSObject>

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType;

@end

@interface SortSelectViewController : UIViewController

@property (nonatomic, assign) kPiwigoSortBy currentSortType;
@property (nonatomic, weak) id<SortSelectViewControllerDelegate> delegate;

+(NSString*)getNameForSortType:(kPiwigoSortBy)sortType;
+(void)getSortedImageNameArrayFromSortType:(kPiwigoSortBy)sortType
							   forCategory:(NSInteger)category
							   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
							  onCompletion:(void (^)(NSArray *imageNames))completion;

@end
