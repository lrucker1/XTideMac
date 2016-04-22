/*
 *  XTUtils.mm
 *  XTideCocoa
 *
 *  Created by Lee Ann Rucker on 4/13/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#import "libxtide.hh"
#import "XTUtils.h"

NSString *
DstrToNSString(const Dstr &s)
{
   return [NSString stringWithCString:s.aschar()
                             encoding:NSISOLatin1StringEncoding];
}

NSDate *
TimestampToNSDate(const libxtide::Timestamp t)
{
   return [NSDate dateWithTimeIntervalSince1970:t.timet()];
}
