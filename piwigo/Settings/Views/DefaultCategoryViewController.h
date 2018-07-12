//
//  DefaultCategoryViewController
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@interface DefaultCategoryViewController : UIViewController

-(instancetype)initWithSelectedCategory:(PiwigoAlbumData*)category;

@end
