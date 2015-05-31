//
//  CategoryMoveToViewController.m
//  piwigo
//
//  Created by Olaf on 21/05/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryMoveToViewController.h"
#import "PiwigoImageData.h"
#import "UploadService.h"
#import "PiwigoAlbumData.h"
#import "CategoriesData.h"

@interface CategoryMoveToViewController ()

@end

@implementation CategoryMoveToViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.categoryListDelegate = self;
}

-(void)selectedCategory:(PiwigoAlbumData *)category {
    MyLog(@"Category new: %@(%ld)", category.name, (long)category.albumId);
    for (PiwigoImageData *anImage in self.selectedImages) {
        NSArray * oldAlbumIds = anImage.categoryIds;
        MyLog(@"Image: %@, old Categories : %@", anImage.name, oldAlbumIds );
        // remove from old album
        [[CategoriesData sharedInstance]removeImage:anImage];
        // tell server
        anImage.categoryIds = @[@(category.albumId)];
        [self sendUpdatedImageInfo:anImage];
    }
    PiwigoAlbumData *newAlbum = [[CategoriesData sharedInstance] getCategoryById:category.albumId];
    [newAlbum addImages:self.selectedImages];
}

-(void)sendUpdatedImageInfo: (PiwigoImageData *)imageData {
    [UploadService updateImageInfo:imageData
                          category:[imageData.categoryIds.firstObject integerValue]
                        onProgress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
                            // progress
                        } onCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
                            // completion
                            MyLog(@"Completion operation: %@\nresponse %@",operation, response);
                        } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
                            // fail
                            MyLog(@"Fail error %@",error);
                        }];
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 50.0;
}
-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoGray];
    headerLabel.text = NSLocalizedString(@"categoryMove_chooseAlbum", @"Select an album to move the images to");
    headerLabel.adjustsFontSizeToFitWidth = YES;
    headerLabel.minimumScaleFactor = 0.5;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
    return header;
}

@end
