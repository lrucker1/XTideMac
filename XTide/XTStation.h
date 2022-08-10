//
//  XTStation.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/13/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef XTStation_h
#define XTStation_h

#ifndef USE_HARMONICS // Because we obviously have not included a .hh file
#define USE_HARMONICS 1
#endif

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@class XTTideEventsOrganizer;
#if USE_HARMONICS
@class XTStationRef;
#endif
@class XTTideEvent;

@interface XTStation : NSObject

@property double aspect;

+ (NSArray *)unitsPrefMap;

- (NSString *)name;
- (NSTimeZone *)timeZone;
- (NSString *)stationInfoAsHTML;
- (NSArray *)stationMetadata;
#if USE_HARMONICS
- (XTStationRef *)stationRef;
#endif

- (NSString *)timeStringFromDate:(NSDate *)date;
- (NSString *)dayStringFromDate:(NSDate *)date;
- (NSString *)dateStringFromDate:(NSDate *)date;

- (NSData *)SVGImageWithWidth:(CGFloat)width
                       height:(CGFloat)height
                         date:(NSDate *)date;

- (XTTideEvent *)nextMajorEventAfter:(NSDate *)startTime;
- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer;


- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer
                        filter:(int)filter;

// Return the tide events as an IPC compliant dictionary for a watch.
- (NSArray *)generateWatchEventsStart:(NSDate*)startTime
                                  end:(NSDate*)endTime
                          includeRing:(BOOL)includeRing;

- (NSDictionary *)clockInfoWithXSize:(CGFloat)xsize
                               ysize:(CGFloat)ysize
                               scale:(CGFloat)scale;

- (NSDictionary *)iconInfoWithSize:(CGFloat)size
                             scale:(CGFloat)scale
                           forDate:(NSDate *)date;
                             
#if USE_HARMONICS
- (NSDictionary *)stationValuesDictionary;
#endif

@end

#endif /* XTStation_h */
