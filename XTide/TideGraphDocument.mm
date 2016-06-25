//
//  TideGraphDocument.m
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

#import "TideGraphDocument.h"
#import "TideGraphController.h"
#import "GraphView.h"

@implementation TideGraphDocument
+ (NSArray *)writableTypes
{
	return [NSArray arrayWithObjects:NSPDFPboardType, NSTIFFPboardType, 
		/*NSStringPboardType, NSICalPboardType, */nil];
}

// File type for Save/Save As...
- (NSString*)fileType
{
	return NSPDFPboardType;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	NSData *data = nil;
	GraphView *graphView = [self.self.mycontroller graphView];
	if ([typeName isEqualToString:NSPDFPboardType])
		data = [graphView PDFRepresentation];
	else if ([typeName isEqualToString:NSTIFFPboardType])
		data = [graphView TIFFRepresentation];
		
	if (!data) 
		return [self errorID:1 error:outError];

	BOOL success = [data writeToURL:absoluteURL atomically:YES];
	if (!success) 
		return [self errorID:2 error:outError];

	return YES;
}
// This method will only be invoked on Mac 10.4 and later. If you're writing an application that has to run on 10.3.x and earlier you should override -printShowingPrintPanel: instead.
- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError 
{
    
    // Create a view that will be used just for printing.
    NSSize documentSize = [self documentSize];
	GraphView *graphView = [self.mycontroller graphView];
	
	// Make sure the proportions are in the same ratio as current view @lar
//	NSSize viewSize = [graphView visibleRect].size;
	
//	documentSize.height = viewSize.height * (documentSize.width/viewSize.width);
	  
    GraphView *renderingView = [[GraphView alloc] 
			initWithFrame:NSMakeRect(0.0, 0.0, documentSize.width, documentSize.height) 
			date:[graphView graphdate]];
    
    // Create a print operation.
    NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:renderingView printInfo:[self printInfo]];
    
    // Specify that the print operation can run in a separate thread. This will cause the print progress panel to appear as a sheet on the document window.
    [printOperation setCanSpawnSeparateThread:YES];
    
    // Set any print settings that might have been specified in a Print Document Apple event. We do it this way because we shouldn't be mutating the result of [self printInfo] here, and using the result of [printOperation printInfo], a copy of the original print info, means we don't have to make yet another temporary copy of [self printInfo].
    [[[printOperation printInfo] dictionary] addEntriesFromDictionary:printSettings];
    
    // We don't have to autorelease the print operation because +[NSPrintOperation printOperationWithView:printInfo:] of course already autoreleased it. Nothing in this method can fail, so we never return nil, so we don't have to worry about setting *outError.
    return printOperation;
    
}

@end
