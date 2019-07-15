//
//  SearchImagesViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SearchImagesViewController : UIViewController

@property (nonatomic, strong) NSString *searchQuery;
@property (nonatomic, strong) UICollectionView *imagesCollection;

-(void)searchAndLoadImages;

@end
