//
//  XTStationIndex.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "libxtide.hh"
#import "StationIndex.hh"
#import "HarmonicsFile.hh"

#import "XTSettings.h"
#import "XTStationIndex.h"
#import "XTStation.h"
#import "XTStationRefInt.h"
#import "XTUtils.h"

static XTStationIndex *gStationIndex = NULL;
static NSString *XTStationFavoritesKey = @"stationFavorites";
static NSString *XTStationClosestFavoriteKey = @"closestFavorite";

NSString * const XTStationIndexStationsReloadedNotification = @"XTStationIndexStationsReloadedNotification";
NSString * const XTStationIndexFavoritesChangedNotification = @"XTStationIndexFavoritesChangedNotification";

@interface XTStationIndex ()
{
   libxtide::StationIndex *mStationIndex;
   NSArray *stationRefArray;
}

@property (readwrite, retain) NSArray *stationRefArray;
@property (readwrite, copy, nonatomic) NSString *resourceTCDVersion;

- (void)loadHarmonicsFile: (NSString *)harmonicsFile;
- (NSInteger)count;

@end

@implementation XTStationIndex

@synthesize stationRefArray;

/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex sharedStationIndex] --
 *
 *      Accessor for the singleton XTStationIndex.
 *
 * Results:
 *      The singleton XTStationIndex.
 *
 * Side effects:
 *      Allocates and initializes the singleton if it doesn't exist.
 *
 *-----------------------------------------------------------------------------
 */

+ (XTStationIndex *)sharedStationIndex
{
	static dispatch_once_t loadMap;
    dispatch_once(&loadMap, ^{
        gStationIndex = [[XTStationIndex alloc] init];
        [gStationIndex loadHarmonicsFiles];
    });
    return gStationIndex;
}

/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex releaseSharedStationIndex] --
 *
 *      Releases the singleton XTStationIndex.
 *
 * Results:
 *      None
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

+ (void)releaseSharedStationIndex
{
    //[gStationIndex release];
    gStationIndex = nil;
}

/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex init] --
 *
 *      Designated initializer.
 *
 * Results:
 *      A new instance.
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (id)init
{
    if ((self = [super init])) {
        mStationIndex = new libxtide::StationIndex();
    }
    return self;
}

#pragma mark favorites

- (NSUserDefaults *)userDefaults
{
    return self.favoritesDefaults ? self.favoritesDefaults
                                  : [NSUserDefaults standardUserDefaults];
}

- (void)addFavorite:(XTStationRef *)ref
{
    NSUserDefaults *defaults = self.userDefaults;
    NSArray *favoritesLoaded = [defaults objectForKey:XTStationFavoritesKey];
    NSMutableArray *favorites = nil;

    if (favoritesLoaded) {
        favorites = [NSMutableArray arrayWithArray:favoritesLoaded];
    } else {
        favorites = [NSMutableArray array];
    }

    [favorites addObject:[ref title]];

    [defaults setObject:favorites forKey:XTStationFavoritesKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter]
                postNotificationName:XTStationIndexFavoritesChangedNotification
							  object:self
                            userInfo:@{@"ref":ref, @"isAdd":@(YES)}];
}

- (void)removeFavorite:(XTStationRef *)ref
{
    NSUserDefaults *defaults = self.userDefaults;
    NSArray *favoritesLoaded = [defaults objectForKey:XTStationFavoritesKey];

    if (!favoritesLoaded) {
        return;
    }
    NSMutableArray *favorites = [NSMutableArray arrayWithArray:favoritesLoaded];

    [favorites removeObject:[ref title]];

    [defaults setObject:favorites forKey:XTStationFavoritesKey];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter]
                postNotificationName:XTStationIndexFavoritesChangedNotification
							  object:self
                            userInfo:@{@"ref":ref, @"isAdd":@(NO)}];
}

- (BOOL)isFavorite:(XTStationRef *)ref
{
    return [[self favoriteNames] containsObject:[ref title]];
}

- (BOOL)isFavoriteStation:(XTStation *)station
{
    return [[self favoriteNames] containsObject:[station name]];
}

// Return names for simple lists.
- (NSArray *)favoriteNames
{
    return [self.userDefaults objectForKey:XTStationFavoritesKey];
}

// Return StationRefs for the current favorites.
- (NSArray *)favoriteStationRefs
{
    NSArray *names = [self favoriteNames];
    NSMutableArray *refs = [NSMutableArray array];
    for (NSString *name in names) {
        XTStationRef *ref = [self stationRefByName:name];
        if (ref) {
            [refs addObject:ref];
        }
    }
    return [NSArray arrayWithArray:refs];
}

- (XTStationRef *)stationRefNearestLocation:(CLLocation *)location
                                 inStations:(NSArray *)refs
{
    CLLocationDistance d = DBL_MAX; // No CLLocationDistanceMax on macOS
    XTStationRef *closest = nil;
    for (XTStationRef *ref in refs) {
        CLLocationCoordinate2D coord = ref.coordinate;
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:coord.latitude longitude:coord.longitude];
        CLLocationDistance dMeters = [loc distanceFromLocation:location];
        if (dMeters < d) {
            d = dMeters;
            closest = ref;
        }
    }
    return closest;
}

- (XTStationRef *)favoriteNearestLocation:(CLLocation *)location
{
    return [self stationRefNearestLocation:location inStations:[self favoriteStationRefs]];
}

- (XTStationRef *)closestFavorite
{
    NSUserDefaults *defaults = self.userDefaults;
    NSString *name = [defaults objectForKey:XTStationClosestFavoriteKey];
    if (name) {
        return [self stationRefByName:name];
    }
    return nil;
}

- (void)saveClosestFavorite:(XTStationRef *)closest
{
    NSUserDefaults *defaults = self.userDefaults;
    [defaults setObject:[closest title] forKey:XTStationClosestFavoriteKey];
    [defaults synchronize];
}


#pragma mark adaptation

- (NSString *)versionFromHarmonicsFile:(NSString *)filePath
{
    Dstr dname([filePath UTF8String]);
    libxtide::HarmonicsFile hf(dname);
    return DstrToNSString(hf.versionString());
}

- (void)loadHarmonicsFiles
{
    NSArray *harmonicsFiles = [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"tcd" inDirectory:nil];
    // Load files and read the version info.
    NSMutableArray *info = [NSMutableArray array];
    BOOL useResource = ![XTSettings_GetUserDefaults() boolForKey:XTide_ignoreResourceHarmonics];
    for (NSString *harmonicsFile in harmonicsFiles) {
        if (useResource) {
            [self loadHarmonicsFile:harmonicsFile];
        }
        [info addObject:[self versionFromHarmonicsFile:harmonicsFile]];
    }
    self.resourceTCDVersion = [info componentsJoinedByString:@"\n"];
    NSArray *urls = XTSettings_GetHarmonicsURLsFromPrefs();
    for (NSURL *url in urls) {
        [self loadHarmonicsFile:[url path]];
    }
}


- (NSArray *)buildStationRefArray
{
    int i;
    NSInteger count = [self count];
    NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
        libxtide::StationRef *ref = mStationIndex->operator[](i);
        XTStationRef *xtRef = [[XTStationRef alloc] initWithStationRef:ref];
        
        [tmpArray addObject:xtRef];
    }
    return tmpArray;
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex loadHarmonicsFile:] --
 *
 *      Load the harmonics file.
 *
 * Results:
 *      None
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (void)loadHarmonicsFile: (NSString *)harmonicsFile
{
    if (harmonicsFile) {
        Dstr dname([harmonicsFile UTF8String]);
        mStationIndex->addHarmonicsFile(dname);
        if (mStationIndex->empty()) {
            libxtide::Global::barf (libxtide::Error::NO_HFILE_IN_PATH,
                          [[harmonicsFile stringByDeletingLastPathComponent] UTF8String]);
            // Ignore the stupid case where the file exists but contains no
            // stations.
        }
        mStationIndex->sort();
        mStationIndex->setRootStationIndexIndices();
    }
    // Don't build the ref array yet; we can have multiple harmonics files.
    // Throw it away if we have one to force a rebuild with all files.
    if (stationRefArray) {
        self.stationRefArray = nil;
        [[NSNotificationCenter defaultCenter]
                postNotificationName:XTStationIndexStationsReloadedNotification
							  object:self];
    }
}

- (NSArray *)stationRefArray
{
    if (!stationRefArray) {
        self.stationRefArray = [self buildStationRefArray];
    }
    return stationRefArray;
}

// HTML file containing all the version info.
- (NSString *)harmonicsFileIDs
{
  Dstr hfileIDs;
  mStationIndex->hfileIDs(hfileIDs);
  return DstrToNSString(hfileIDs);
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex dealloc] --
 *
 *      Dealloc
 *
 * Results:
 *      None
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (void)dealloc
{
    if (self == gStationIndex) {
        gStationIndex = nil;
    }
    // Created and owned by self.
    delete mStationIndex;
    self.stationRefArray = nil;
    //[super dealloc];
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTStationIndex count] --
 *
 *      Wrappers for Vector methods.
 *
 * Results:
 *      None
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (NSInteger)count
{
    return mStationIndex->size();
}

- (XTStationRef *)stationRefByName: (NSString *)name
{
    libxtide::StationRef *ref = mStationIndex->getStationRefByName([name UTF8String]);
    return ref == NULL ? nil : [[XTStationRef alloc] initWithStationRef:ref];
}

@end
