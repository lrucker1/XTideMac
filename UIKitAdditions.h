//
//  UIKitAdditions.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef UIKitAdditions_h
#define UIKitAdditions_h

#import <UIKit/UIKit.h>
#import "XTStationRef.h"
#import "XTStation.h"

@interface XTStationRef (iOSAdditions)

- (UIImage *)stationDot;

@end


@interface XTStation (iOSAdditions)

- (NSAttributedString *)stationInfo;

@end

#endif /* UIKitAdditions_h */
