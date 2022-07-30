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
extern NSString * const XStationIndexWillReloadNotification;
extern NSString * const XStationIndexDidLoadNotification;

@class XTStation;
@class XTStationRef;

@interface XTStationIndex : NSObject

@property (readonly, retain, nonatomic) NSArray *stationRefArray;
@property (readonly, copy, nonatomic) NSString *resourceTCDVersion;
@property (readwrite, retain, nonatomic) NSUserDefaults *favoritesDefaults;

+ (XTStationIndex *)sharedStationIndex;
+ (void)releaseSharedStationIndex;

- (void)loadHarmonicsFiles;
- (void)reloadHarmonicsFiles;
- (XTStationRef *)stationRefByName: (NSString *)name;
- (NSString *)harmonicsFileIDs;
- (NSString *)versionFromHarmonicsFile:(NSString *)filePath;

- (void)addFavorite:(XTStationRef *)ref;
- (void)removeFavorite:(XTStationRef *)ref;
- (BOOL)isFavorite:(XTStationRef *)ref;
- (BOOL)isFavoriteStation:(XTStation *)station;
- (NSArray *)favoriteNames;
- (NSArray *)favoriteStationRefs;
- (void)saveClosestFavorite:(XTStationRef *)closest;
- (XTStationRef *)closestFavorite;
- (XTStationRef *)favoriteNearestLocation:(CLLocation *)location;
- (XTStationRef *)stationRefNearestLocation:(CLLocation *)location
                                 inStations:(NSArray *)refs;

@end
