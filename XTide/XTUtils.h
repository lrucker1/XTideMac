/*
 *  XTUtils.h
 *  XTideCocoa
 *
 *  Created by Lee Ann Rucker on 4/13/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */


#import <Foundation/Foundation.h>
#include "Units.hh"

class Dstr;

NSString *
DstrToNSString(const Dstr &s);

NSDate *
TimestampToNSDate(const libxtide::Timestamp t);

void DisplayCoreError(const Dstr &errorDstr, libxtide::Error::ErrType fatality);