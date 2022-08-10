//
//  AppKitAdditions.h
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//
// Categories for AppKit specific methods.

#import <Cocoa/Cocoa.h>
#import "XTStationRef.h"
#import "XTStation.h"

@interface XTStationRef (MacOSAdditions)

- (NSImage *)stationDot;

@end


@interface XTStation (MacOSAdditions)

#if DEBUG
// Generate icon and watch background images.
- (void)createWatchPlaceholderImages;
#endif

- (NSAttributedString *)stationInfo;

@end
