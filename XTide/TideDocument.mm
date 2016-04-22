//
//  TideDocument.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/20/06.
//  Copyright 2006 . 
//
/*
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "TideDocument.h"
#import "TideController.h"

NSString *NSICalPboardType = @"com.apple.ical.ics";
NSString *NSCSVPboardType = @"Comma-separated value (CSV) file";


@implementation TideDocument
// Makes an error object and returns NO for write failures @lar - fix me
- (BOOL)errorID:(int)err error:(NSError **)outError
{
	NSError *theError = [[NSError alloc] initWithDomain:@"XTideError"
		code:err
		userInfo:nil];
    if (outError) {
        *outError = theError;
    }
	return NO;
}

// Writes a text file 
- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	char form;
	if ([typeName isEqualToString:NSStringPboardType])
		form = 't'; // plain text
	else if ([typeName isEqualToString:NSICalPboardType])
		form = 'i'; // iCal format
	else if ([typeName isEqualToString:NSCSVPboardType])
		form = 'c'; // comma-separated value format
	else 
		return [self errorID:1 error:outError];
	
	// Set the form and mode based on typeName
	NSString *str = [mycontroller stringWithIndexes:nil form:form mode:'p'];
	if (str == nil)
		return [self errorID:1 error:outError];
	
	NSData *data = [str dataUsingEncoding:NSISOLatin1StringEncoding];
	if (!data) 
		return [self errorID:1 error:outError];

	BOOL success = [data writeToURL:absoluteURL atomically:YES];
	if (!success) 
		return [self errorID:2 error:outError];

	return YES;
}

- (NSSize)documentSize 
{
    NSPrintInfo *printInfo = [self printInfo];
    NSSize paperSize = [printInfo paperSize];
    paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
    paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
    return paperSize;
}


@end
