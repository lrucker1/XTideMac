//
//  NSDate+NSDate_XTWAdditions.m
//  XTide.
//
//  Created by Lee Ann Rucker on 7/16/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "NSDate+NSDate_XTWAdditions.h"

@implementation NSDate (NSDate_XTWAdditions_m)


// The TARDIS joke is writing itself...
// The watch shows local time, even for non-local stations.
- (NSString *)localizedTimeAndRelativeDateString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.doesRelativeDateFormatting = YES;
    return [dateFormatter stringFromDate:self];
}

@end
