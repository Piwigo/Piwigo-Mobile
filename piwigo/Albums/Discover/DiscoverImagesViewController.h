//
//  DiscoverImagesViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DiscoverImagesViewController : UIViewController

@property (nonatomic, strong) UICollectionView *imagesCollection;

-(instancetype)initWithCategoryId:(NSInteger)categoryId;

@end
