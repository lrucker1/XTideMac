//
//  XTStationIndex.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

extern NSString * const XTStationIndexStationsReloadedNotification;
extern NSString * const XTStationIndexFavoritesChangedNotification;

@class XTStation;
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

- (void)addFavorite:(XTStationRef *)ref;
- (void)removeFavorite:(XTStationRef *)ref;
- (BOOL)isFavorite:(XTStationRef *)ref;
- (BOOL)isFavoriteStation:(XTStation *)station;
- (NSArray *)favoriteNames;
- (NSArray *)favoriteStationRefs;
- (XTStationRef *)favoriteNearestLocation:(CLLocation *)location;
- (XTStationRef *)stationRefNearestLocation:(CLLocation *)location
                                 inStations:(NSArray *)refs;

@end
