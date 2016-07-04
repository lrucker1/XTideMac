//
//  AppKitAdditions.m
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "AppKitAdditions.h"
#import "XTColorUtils.h"

@implementation XTStationRef (MacOSAdditions)

- (NSImage *)stationDot
{
    return [NSImage imageWithSize:NSMakeSize(12, 12) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        if (self.isReferenceStation) {
            [ColorForKey(XTide_ColorKeys[refcolor]) set];
        } else {
            [ColorForKey(XTide_ColorKeys[subcolor]) set];
        }
        [[NSBezierPath bezierPathWithOvalInRect:dstRect] fill];
        return YES;
    }];
}

@end


@implementation XTStation (MacOSAdditions)


- (NSAttributedString *)stationInfo
{
	return [[NSAttributedString alloc] initWithHTML:[[self stationInfoAsHTML] dataUsingEncoding:NSASCIIStringEncoding]
								 documentAttributes:NULL];
}

@end