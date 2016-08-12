//
//  XTStationInfoViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/23/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTStationInfoViewController.h"
#import "XTStation.h"
#import "XTStationRef.h"

@interface XTStationInfoViewController ()

@end

@implementation XTStationInfoViewController

/*
 * NTH: Set the first column's width to fit if there are no
 * headers, because headers look like crap on a visual effects view.
 *  - they aren't vibrant, and they cause the parent view to be only partly vibrant too.
 */
- (void)reloadData
{
    XTStationRef *stationRef = (XTStationRef *)self.representedObject;
    XTStation *station = [stationRef loadStation];
    self.arrayController.content = [station stationMetadata];
}

- (void)awakeFromNib
{
    [self reloadData];
}

- (IBAction)copy:(id)sender
{
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSArray *meta = self.arrayController.content;
    NSMutableArray *lines = [NSMutableArray array];
    for (NSDictionary *d in meta) {
        [lines addObject:[NSString stringWithFormat:@"%@\t%@", [d objectForKey:@"name"], [d objectForKey:@"value"]]];
    }
    NSString *stringToCopy = [lines componentsJoinedByString:@"\n"];
    [pasteboard writeObjects:@[stringToCopy]];
}

//- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
//{
//    CGFloat colWidth = [[[tableView tableColumns] objectAtIndex:1] width];
//    NSArray *tempArray = self.arrayController.arrangedObjects;
//    
//    NSString *content = [[tempArray objectAtIndex:row] objectForKey:@"value"];
//    
//    float textWidth = [content sizeWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Lucida Grande" size:15],NSFontAttributeName ,nil]].width;
//    
//    float newHeight = ceil(textWidth/colWidth);
//    
//    newHeight = (newHeight * 17) + 13;
//    if(newHeight < 47){
//        return 47;
//    }
//    return newHeight;
//}

- (IBAction)cancel:(id)sender
{
    if (self.popover) {
        [self.popover close];
    } else {
        NSBeep();
    }
}

@end
