//
//  XTStationRefInt.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/14/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#ifndef XTStationRefInt_h
#define XTStationRefInt_h

#import "XTStationRef.h"

#import "libxtide.hh"
#import "StationRef.hh"

@interface XTStationRef ()

- (id)initWithStationRef: (libxtide::StationRef *)aStationRef;
- (NSMutableDictionary *)stationRefValuesDictionary;

@end

#endif /* XTStationRefInt_h */
