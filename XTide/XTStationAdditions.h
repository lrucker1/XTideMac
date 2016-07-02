//
//  XTStationAdditions.h
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTStationAdditions.h"
#import "XTStationRefInt.h"
#import "XTStation.h"

@interface XTStationRef (MacOSAdditions)

- (NSImage *)stationDot;

@end


@interface XTStation (MacOSAdditions)

- (NSAttributedString *)stationInfo;

@end
