//
//  CategoryMoveToViewController.h
//  piwigo
//
//  Created by Olaf Greck on 21/05/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CategoryMoveToViewController : UIViewController <UISearchBarDelegate, UISearchDisplayDelegate>

@property (weak, nonatomic) IBOutlet UITableView *albumsTableView;
@property (weak, nonatomic) IBOutlet UISearchBar *albumSearchBar;

@property (nonatomic, strong) NSArray *selectedImages;
@property (nonatomic, strong) NSMutableArray *availableAlbums;

-(instancetype)initWithSelectedImages:(NSArray *)selectedImages;

-(void)viewDidLoadUniversal;

@end
