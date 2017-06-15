//
//  PiwigoTagData.m
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoTagData.h"

@implementation PiwigoTagData


#pragma mark - debugging support -

-(NSString *)description {
    NSString *objectIsNil = @"<nil>";

    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    [descriptionArray addObject:[NSString stringWithFormat:@"tagName                = %@", (nil == self.tagName ? objectIsNil : (0 == [self.tagName length] ? @"''" : self.tagName))]];

    [descriptionArray addObject:[NSString stringWithFormat:@"tagId                  = %ld", (long)self.tagId]];
    [descriptionArray addObject:[NSString stringWithFormat:@"numberOfImagesUnderTag = %ld", (long)self.numberOfImagesUnderTag]];
    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}

@end
