//
//  XTCalendar.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 5/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "libxtide.hh"
#import "Calendar.hh"
#import "CalendarFormNotC.hh"
#import "CalendarFormH.hh"

@class XTStation;

extern NSString * const XTCalColumnsKey;
extern NSString * const XTCalDaysKey;

namespace libxtide {

class CocoaCalendar: public libxtide::CalendarFormH {
public:
  CocoaCalendar (libxtide::Station &station,
		 libxtide::Timestamp startTime,
		 libxtide::Timestamp endTime,
		 libxtide::Mode::Mode mode);

   NSDictionary *buildDataSource();

protected:
   void setPV(const libxtide::Timestamp &eventTime,
              const libxtide::PredictionValue &pv,
              int index,
              NSMutableArray *columns);

   void setColumnValue(NSObject *newObj,
                       int index,
                       NSMutableArray *columns);

   void setTime(const libxtide::Timestamp &eventTime,
                int index,
                NSMutableArray *columns);

};

} // namespace

@interface XTCalendar : NSObject
{
   libxtide::CocoaCalendar *mCalendar;
}

- (id)initWithStation: (XTStation *)station
            startTime: (NSDate *)startTime
              endTime: (NSDate *)endTime;

- (NSString *)generateHTML;
- (NSDictionary *)generateDataSource;

@end
