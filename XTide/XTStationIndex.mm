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
#import "XTStationRefInt.h"
#import "XTUtils.h"

static XTStationIndex *gStationIndex = NULL;
static NSString *XTStationFavoritesKey = @"stationFavorites";

NSString * const XTStationIndexStationsReloadedNotification = @"XTStationIndexStationsReloadedNotification";

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
    if (gStationIndex == nil) {
        gStationIndex = [[XTStationIndex alloc] init];
        [gStationIndex loadHarmonicsFiles];
    }
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

- (void)addFavorite:(XTStationRef *)ref
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
}

- (void)removeFavoriteByName:(NSString *)name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *favoritesLoaded = [defaults objectForKey:XTStationFavoritesKey];

    if (!favoritesLoaded) {
        return;
    }
    NSMutableArray *favorites = [NSMutableArray arrayWithArray:favoritesLoaded];

    [favorites removeObject:name];

    [defaults setObject:favorites forKey:XTStationFavoritesKey];
    [defaults synchronize];
}

- (void)removeFavorite:(XTStationRef *)ref
{
    [self removeFavoriteByName:[ref title]];
}

- (BOOL)isFavorite:(XTStationRef *)ref
{
    return [[self favoriteNames] containsObject:[ref title]];
}

// Return names for simple lists.
- (NSArray *)favoriteNames
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:XTStationFavoritesKey];
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

- (XTStationRef *)favoriteNearestLocation:(CLLocation *)location
{
    CLLocationDistance d = DBL_MAX;
    XTStationRef *closest = nil;
    NSArray *refs = [self favoriteStationRefs];
    for (XTStationRef *ref in refs) {
        CLLocationCoordinate2D coord = ref.coordinate;
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:coord.latitude longitude:coord.longitude];
        CLLocationDistance dTest = [loc distanceFromLocation:location];
        if (dTest < d) {
            d = dTest;
            closest = ref;
        }
    }
    return closest;
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
    NSArray *harmonicsFiles = [[NSBundle mainBundle] pathsForResourcesOfType:@"tcd" inDirectory:nil];
    if (self.resourceTCDVersion == nil) {
        // Read the version info.
        NSMutableArray *info = [NSMutableArray array];
        for (NSString *harmonicsFile in harmonicsFiles) {
            [info addObject:[self versionFromHarmonicsFile:harmonicsFile]];
        }
        self.resourceTCDVersion = [info componentsJoinedByString:@"\n"];
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:XTide_ignoreResourceHarmonics]) {
        for (NSString *harmonicsFile in harmonicsFiles) {
            [self loadHarmonicsFile:harmonicsFile];
        }
    }
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
    // Don't build the ref array yet; we have multiple harmonics files.
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
    return [[XTStationRef alloc] initWithStationRef:ref];
}

@end
