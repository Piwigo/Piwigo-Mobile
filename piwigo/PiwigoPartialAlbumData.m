//
//  PiwigoPartialAlbumData.m
//  piwigo
//
//  Created by Olaf Greck on 5.Jun.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoPartialAlbumData.h"

#import "CategoriesData.h"

@interface PiwigoPartialAlbumData ()

@property (nonatomic, strong) NSMutableArray *imageNamesArray;

@end

@implementation PiwigoPartialAlbumData

- (instancetype)init {
    return [self initWithAlbum:[PiwigoAlbumData new]];
}

-(instancetype)initWithAlbum:(PiwigoAlbumData *)fullAlbum {
    self = [super init];
    if (self) {
        _albumId        = fullAlbum.albumId;
        _albumName      = fullAlbum.name;
        _albumPath      = [self _buildAlbumPath:fullAlbum];
        _numberOfImages = fullAlbum.numberOfImages;
        _isSelected     = NO;
        _imageNamesArray  = [NSMutableArray new];
    }
    return self;
}

-(NSString *)_buildAlbumPath:(PiwigoAlbumData *)fullAlbum  {
    if (fullAlbum.parentAlbumId == 0) { // root level
        return @"";
    } else {
        NSMutableArray *parents = [NSMutableArray new];
        PiwigoAlbumData *parentAlbum = [[CategoriesData sharedInstance] getCategoryById:fullAlbum.parentAlbumId];
        do {
            [parents addObject:parentAlbum.name];
            parentAlbum = [[CategoriesData sharedInstance] getCategoryById:parentAlbum.parentAlbumId];
        } while (parentAlbum.parentAlbumId != 0);
        [parents addObject:fullAlbum.name];
        return [parents componentsJoinedByString:@" / "];
    }
}

-(void)addImageAsMember:(PiwigoImageData *)anImage {
    self.isSelected = YES;
    [self.imageNamesArray addObject:anImage.name];
}

-(NSString *)imageNames {
    return [self.imageNamesArray componentsJoinedByString:@" "];
}

#pragma mark - debugging support -

-(NSString *)stringFor:(NSString *)aString {
    NSString *objectIsNil = @"<nil>";
    return (nil == aString ? objectIsNil : (0 == [aString length] ? @"''" : aString));
}

-(NSString *)description {
    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
 
    [descriptionArray addObject:[NSString stringWithFormat:@"albumName             = %@", [self stringFor:self.albumName]]];
    [descriptionArray addObject:[NSString stringWithFormat:@"albumPath             = %@", [self stringFor:self.albumPath]]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"albumId               = %ld", (long)self.albumId]];
    [descriptionArray addObject:[NSString stringWithFormat:@"numberOfImages        = %ld", (long)self.numberOfImages]];
    [descriptionArray addObject:[NSString stringWithFormat:@"_isSelected           = %@", (self.isSelected ? @"YES" : @"NO")]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"imageNamesArray [%ld] = %@", (long)self.imageNamesArray.count, self.imageNamesArray]];

    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}



@end
