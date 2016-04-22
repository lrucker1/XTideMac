//
//  XTStationIndex.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString * const XTStationIndexStationsReloadedNotification;

@class XTStationRef;

@interface XTStationIndex : NSObject

@property (readonly, retain, nonatomic) NSArray *stationRefArray;
@property (readonly, copy, nonatomic) NSString *resourceTCDVersion;

+ (XTStationIndex *)sharedStationIndex;
+ (void)releaseSharedStationIndex;

- (void)loadHarmonicsFiles;
- (XTStationRef *)stationRefByName: (NSString *)name;
- (NSString *)harmonicsFileIDs;
- (NSString *)versionFromHarmonicsFile:(NSString *)filePath;

@end
