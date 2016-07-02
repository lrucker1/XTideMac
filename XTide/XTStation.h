//
//  XTStation.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/13/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef XTStation_h
#define XTStation_h

@interface XTStation : NSObject

+ (NSArray *)unitsPrefMap;

- (NSTimeZone *)timeZone;
- (NSString *)stationInfoAsHTML;
- (NSArray *)stationMetadata;

@end

#endif /* XTStation_h */
