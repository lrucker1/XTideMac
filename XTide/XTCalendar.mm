//
//  XTCalendar.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 5/4/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XTCalendar.h"
#import "XTStationInt.h"
#import "XTUtils.h"
#import "Station.hh"

NSString * const XTCalColumnsKey = @"XTCalColumnsKey";
NSString * const XTCalDaysKey = @"XTCalDaysKey";

@implementation XTCalendar

/*
 *-----------------------------------------------------------------------------
 *
 * -[XTCalendar initWithStation:startTime:endTime:] --
 *
 *      Initializer.
 *
 * Result:
 *      An instance or nil.
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (id)initWithStation: (XTStation *)station
            startTime: (NSDate *)startTime
              endTime: (NSDate *)endTime
{
   self = [super init];
   if (!self) {
      return nil;
   }
	libxtide::Station *cStation = [station adaptedStation];
	libxtide::Timestamp start((time_t)[startTime timeIntervalSince1970]);
	libxtide::Timestamp end((time_t)[endTime timeIntervalSince1970]);
	// Normalize dates
	start.floorDay(cStation->timezone);
	end.floorDay(cStation->timezone);
	
   mCalendar = new libxtide::CocoaCalendar(*cStation, start, end, libxtide::Mode::calendar);
   return self;
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTCalendar dealloc] --
 *
 *      The destructor.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      Deletes the CocoaCalendar instance.
 *
 *-----------------------------------------------------------------------------
 */

- (void)dealloc
{
   // Created and owned by self.
   delete mCalendar;
}

- (NSString *)generateHTML
{
	Dstr text_out;
	mCalendar->print(text_out);
	return DstrToNSString(text_out);
}

- (NSDictionary *)generateDataSource
{
	return mCalendar->buildDataSource();
}

@end

namespace libxtide {
/*
 *------------------------------------------------------------------------------
 *
 * CocoaCalendar --
 *
 *      Constructor.
 *
 * Results:
 *      The new Calendar
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

CocoaCalendar::CocoaCalendar (Station &station,
                              Timestamp startTime,
                              Timestamp endTime,
                              Mode::Mode mode):
  CalendarFormH (station, startTime, endTime, mode)
{
}

void
CocoaCalendar::setColumnValue(NSObject *newObj,
                              int index,
                              NSMutableArray *columns)
{
   NSObject *oldObj = [columns objectAtIndex:index];
   if ([oldObj isEqual:[NSNull null]]) {
      [columns replaceObjectAtIndex:index
                         withObject:newObj];
   } else {
      assert(0);
   }
}

void
CocoaCalendar::setPV(const Timestamp &eventTime,
                     const PredictionValue &pv,
                     int index,
                     NSMutableArray *columns)
{
   Dstr buf;
	pv.printnp (buf);
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                           TimestampToNSDate(eventTime), @"time",
                           DstrToNSString(buf), @"pv",
                           nil];
   setColumnValue(dict, index, columns);
}

void
CocoaCalendar::setTime(const Timestamp &eventTime,
                       int index,
                       NSMutableArray *columns)
{
   NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                           TimestampToNSDate(eventTime), @"time",
                           nil];
   setColumnValue(dict, index, columns);
}


/*
 *------------------------------------------------------------------------------
 *
 * CocoaCalendar::buildDataSource() --
 *
 *      Create a data source.
 *
 * Results:
 *      An autoreleased table data source
 *
 * Side effects:
 *      None
 *
 *------------------------------------------------------------------------------
 */

NSDictionary *
CocoaCalendar::buildDataSource()
{
   NSMutableDictionary *result = [NSMutableDictionary dictionary];
   NSMutableArray *daysArray = [NSMutableArray array];
   switch (_mode) {
         
      case Mode::calendar: {
         const Dstr &eventMask (Global::settings["em"].s);
         
         // Day ... [Mark transitions]? Surises Sunsets Moonphases
         // Tides: ... = High [Low High]+
         // Currents: ... = Slack Flood Slack [Ebb Slack Flood Slack]+
         // For Tides, X = max number of low tides in a day
         // For Currents, X = max number of max ebbs in a day
         // Exception:  ebbs with no intervening slack count as one
         
         // Find the value of "X" and check for mark transitions.  This is
         // a clone of the logic that is used when actually building the
         // table; X is figured based on what it tries to do.  See the
         // table-building loop for comments on the special cases.
         
         bool haveMarks (false);
         unsigned X;
         {
            unsigned maxtidecol (0);
            for (Date loopDate (firstDay); loopDate <= lastDay; ++loopDate) {
               unsigned tidecol (0);
               SafeVector<TideEvent> &eventVector (eventVectors[loopDate]);
               for (SafeVector<TideEvent>::iterator it (eventVector.begin());
                    it != eventVector.end();
                    ++it) {
                  TideEvent &te (*it);
                  switch (te.eventType) {
                     case TideEvent::max:
                        if (isCurrent) {
                           if (te.isMinCurrentEvent()) {
                              while ((tidecol+1) % 4)
                                 ++tidecol;
                           } else {
                              while ((tidecol+3) % 4)
                                 ++tidecol;
                           }
                        } else {
                           if (tidecol % 2)
                              ++tidecol;
                        }
                        break;
                        
                     case TideEvent::min:
                        if (isCurrent) {
                           if (te.isMinCurrentEvent()) {
                              while ((tidecol+3) % 4)
                                 ++tidecol;
                           } else {
                              while ((tidecol+1) % 4)
                                 ++tidecol;
                           }
                        } else {
                           if ((tidecol+1) % 2)
                              ++tidecol;
                        }
                        break;
                        
                     case TideEvent::slackrise:
                        assert (isCurrent);
                        if (tidecol % 2)
                           ++tidecol;
                        break;
                        
                     case TideEvent::slackfall:
                        assert (isCurrent);
                        if (tidecol == 0)
                           tidecol = 2;
                        else if (tidecol % 2)
                           ++tidecol;
                        break;
                        
                     case TideEvent::markrise:
                     case TideEvent::markfall:
                        haveMarks = true;
                     default:
                        ;
                  }
               }
               if (tidecol > maxtidecol)
                  maxtidecol = tidecol;
            }
            // maxtidecol + 1 - (3 or 1)
            if (isCurrent)
               X = std::max (1, (int) (ceil ((maxtidecol - 2) / 4.0)));
            else
               X = std::max (1, (int) (ceil (maxtidecol / 2.0)));
         }
         
         unsigned numtidecol (isCurrent ? 3+X*4 : 1+X*2);
         // Col. 0 is day
         // Cols. 1 .. numtidecol are tides/currents
         unsigned lastcol (numtidecol);
         // Col. numtidecol+1 is optionally mark 
         unsigned markcol (haveMarks ? ++lastcol : 0);
         // Remaining columns are as follows, or 0 if not applicable.
         unsigned p ((eventMask.strchr('p') == -1) ? ++lastcol : 0);
         unsigned S ((eventMask.strchr('S') == -1) ? ++lastcol : 0);
         unsigned s ((eventMask.strchr('s') == -1) ? ++lastcol : 0);
         unsigned M ((eventMask.strchr('M') == -1) ? ++lastcol : 0);
         unsigned m ((eventMask.strchr('m') == -1) ? ++lastcol : 0);
         // The usually blank phase column makes a natural separator between
         // the tide/current times and the sunrise/sunset times.
         NSMutableArray *headerColumns = [NSMutableArray arrayWithCapacity:lastcol+1];
         static NSString *XTCalSlackLabel = NSLocalizedString(@"Slack", @"Slack");
         static NSString *XTCalFloodLabel = NSLocalizedString(@"Flood", @"Flood");
         static NSString *XTCalHighLabel = NSLocalizedString(@"High", @"High");
         static NSString *XTCalLowLabel = NSLocalizedString(@"Low", @"Low");
         static NSString *XTCalEbbLabel = NSLocalizedString(@"Ebb", @"Ebb");

         [headerColumns addObject:NSLocalizedString(@"Day", @"Day")];
         if (isCurrent) {
            [headerColumns addObject:XTCalSlackLabel];
            [headerColumns addObject:XTCalFloodLabel];
            [headerColumns addObject:XTCalSlackLabel];
         } else {
            [headerColumns addObject:XTCalHighLabel];
         }
         for (unsigned a=0; a<X; ++a) {
            if (isCurrent) {
               [headerColumns addObject:XTCalEbbLabel];
               [headerColumns addObject:XTCalSlackLabel];
               [headerColumns addObject:XTCalFloodLabel];
               [headerColumns addObject:XTCalSlackLabel];
            } else {
               [headerColumns addObject:XTCalLowLabel];
               [headerColumns addObject:XTCalHighLabel];
            }
         }
         if (markcol) [headerColumns insertObject:NSLocalizedString(@"Mark", @"Mark")   atIndex:markcol];
         if (p) [headerColumns insertObject:NSLocalizedString(@"Phase", @"Phase")       atIndex:p];
         if (S) [headerColumns insertObject:NSLocalizedString(@"Sunrise", @"Sunrise")   atIndex:S];
         if (s) [headerColumns insertObject:NSLocalizedString(@"Sunset", @"Sunset")     atIndex:s];
         if (M) [headerColumns insertObject:NSLocalizedString(@"Moonrise", @"Moonrise") atIndex:M];
         if (m) [headerColumns insertObject:NSLocalizedString(@"Moonset", @"Moonset")   atIndex:m];
         [result setObject:headerColumns forKey:XTCalColumnsKey];
       
         for (Date loopDate (firstDay); loopDate <= lastDay; ++loopDate) {
            //const Date::DateStruct dateStruct (loopDate.dateStruct());
            
            NSMutableArray *columns = [NSMutableArray arrayWithCapacity:lastcol+1];
            /*
             * Pre-fill the array; not all columns will have values
             * plus they can get set out of order.
             */
            for (int i = 0; i <= lastcol; i++) [columns addObject:[NSNull null]];
           
            // Tidecol X maps to colbuf element X+1
            unsigned tidecol (0);
            
            SafeVector<TideEvent> &eventVector (eventVectors[loopDate]);
            for (SafeVector<TideEvent>::iterator it (eventVector.begin());
                 it != eventVector.end();
                 ++it) {
               TideEvent &te (*it);
               switch (te.eventType) {
                     
                     // For currents, we have the exception case of Min Floods and
                     // Min Ebbs to deal with.  The combination Max, Min, Max is
                     // crammed into one table cell.
                     
                     // We rely on the sorting done in Calendar::Calendar to
                     // resolve all sub station time warp anomalies and leave us
                     // with an ordering that goes into the table from left to
                     // right.  The only problem remaining is deciding where to
                     // start if the first event of the day is a slack.  Presently
                     // we assume that the type of the event (rising vs. falling)
                     // is authoritative, which could be risky in the presence of
                     // anomalies.
                     
                  case TideEvent::max:
                     if (isCurrent) {
                        if (te.isMinCurrentEvent()) {
                           while ((tidecol+1) % 4)
                              ++tidecol;
                        } else {
                           while ((tidecol+3) % 4)
                              ++tidecol;
                        }
                        assert (tidecol < numtidecol);
                     } else {
                        if (tidecol % 2)
                           ++tidecol;
                        assert (tidecol < numtidecol);
                     }
                     setPV(te.eventTime, te.eventLevel, tidecol+1, columns);
                     break;
                     
                  case TideEvent::min:
                     if (isCurrent) {
                        if (te.isMinCurrentEvent()) {
                           while ((tidecol+3) % 4)
                              ++tidecol;
                        } else {
                           while ((tidecol+1) % 4)
                              ++tidecol;
                        }
                        assert (tidecol < numtidecol);
                     } else {
                        if ((tidecol+1) % 2)
                           ++tidecol;
                        assert (tidecol < numtidecol);
                     }
                     setPV(te.eventTime, te.eventLevel, tidecol+1, columns);
                     break;
                     
#define doOtherEvent(x) \
assert (x);                                          \
setTime(te.eventTime, x, columns);                   \
break
                     
                  case TideEvent::slackrise:
                     assert (isCurrent);
                     if (tidecol % 2)
                        ++tidecol;
                     assert (tidecol < numtidecol);
                     doOtherEvent(tidecol+1);
                     
                  case TideEvent::slackfall:
                     assert (isCurrent);
                     if (tidecol == 0)
                        tidecol = 2;
                     else if (tidecol % 2)
                        ++tidecol;
                     assert (tidecol < numtidecol);
                     doOtherEvent(tidecol+1);
                     
                  case TideEvent::markrise:
                  case TideEvent::markfall:
                     doOtherEvent (markcol);
                     
                  case TideEvent::sunrise:   doOtherEvent(S);
                  case TideEvent::sunset:    doOtherEvent(s);
                  case TideEvent::moonrise:  doOtherEvent(M);
                  case TideEvent::moonset:   doOtherEvent(m);
                     
                  case TideEvent::newmoon:
                  case TideEvent::firstquarter:
                  case TideEvent::fullmoon:
                  case TideEvent::lastquarter:
                     assert (p);
                     setColumnValue(DstrToNSString(te.longDescription()), p, columns);
                     break;
                     
                  default:
                     assert (false);
               }
            }
            
            // Now print the day.
            [daysArray addObject:columns];
         }
         break;
      }
         
      default:
         assert (false);
   }
   [result setObject:daysArray forKey:XTCalDaysKey];
   return result;
}

} // namespace