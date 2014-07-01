//
//  GrowlMailUUIDPatcher.m
//  GrowlMailUUIDPatcher
//
//  Copyright 2010–2014 The Growl Project. All rights reserved.
//

#import "GrowlMailUUIDPatcher.h"

#import "GrowlMailFoundBundle.h"
#import "GrowlMailWarningNote.h"

#include "GrowlVersionUtilities.h"

NSString * const mailAppBundleID = @"com.apple.mail";


@interface GrowlMailUUIDPatcher () <NSTableViewDelegate>

@property (nonatomic, strong) NSTimer *delayedEnableTimer;

@property (nonatomic, copy) NSString *mailUUID;

@property (nonatomic, readonly) BOOL multipleGrowlMailsInstalled;
@property (nonatomic, strong) NSMutableArray *growlMailFoundBundles;
@property (nonatomic, strong) NSIndexSet *selectedBundleIndexes;
@property (nonatomic, readonly) BOOL canAndShouldPatchSelectedBundle;

@property (nonatomic, copy) NSArray *warningNotes;

@property (nonatomic, strong) IBOutlet NSWindow *window;
@property (nonatomic, strong) IBOutlet NSTableView *warningNotesTable;
@property (nonatomic, strong) IBOutlet NSPanel *confirmationSheet;
@property (unsafe_unretained, nonatomic, readonly) NSIndexSet *selectionIndexesOfWarningNotes;

@property (nonatomic, strong) IBOutlet NSButton *okButton;

@property (nonatomic, copy) NSString *currentVersionOfGrowlMail; //Current as in latest. Retrieved from website.

//Returns the selected bundle or nil if none is selected.
- (GrowlMailFoundBundle *) selectedBundle;

- (void) recomputeSelectedBundleNotes;

- (void) applyChangeToFoundBundle:(GrowlMailFoundBundle *)bundle;
- (void) enableOKButton:(NSTimer *)timer;
- (IBAction) patchSelectedBundle:(id)sender;
- (IBAction) ok:(id) sender;
- (IBAction) cancel:(id) sender;

- (void) confirmationSheetDidEnd:(NSWindow *)sheet
					  returnCode:(NSInteger)returnCode
					 contextInfo:(void *)contextInfo;

- (BOOL)moveBundleBackToActiveLocation:(NSBundle*)chosenOne;
- (void)relaunchMail;

@end

#define BUTTON_ENABLING_DELAY 15.0 /*seconds*/

//This is due to be replaced by an appcast, as soon as we work out how we want to do that.
static NSString *const hardCodedGrowlMailCurrentVersionNumber = @"1.3.0";

@implementation GrowlMailUUIDPatcher

+ (NSSet *) keyPathsForValuesAffectingMultipleGrowlMailsInstalled
{
	return [NSSet setWithObject:@"growlMailFoundBundles"];
}

+ (NSSet *) keyPathsForValuesAffectingCanAndShouldPatchSelectedBundle
{
	return [NSSet setWithObject:@"selectedBundleIndexes"];
}

- (id) init
{
	if ((self = [super init]))
    {
		self.growlMailFoundBundles = [NSMutableArray array];

		NSArray *libraryFolders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
		for (NSString *libraryPath in libraryFolders)
        {
			NSString *mailFolderPath = [libraryPath stringByAppendingPathComponent:@"Mail"];
			NSString *bundlesFolderPath = [mailFolderPath stringByAppendingPathComponent:@"Bundles"];
			NSString *growlMailBundlePath = [bundlesFolderPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"];

			NSURL *growlMailBundleURL = [NSURL fileURLWithPath:growlMailBundlePath];
			if ([growlMailBundleURL checkResourceIsReachableAndReturnError:NULL]) {
				[self.growlMailFoundBundles addObject:[GrowlMailFoundBundle foundBundleWithURL:growlMailBundleURL]];
			}
            
			bundlesFolderPath = [mailFolderPath stringByAppendingPathComponent:@"Bundles (Disabled)"];
			growlMailBundlePath = [bundlesFolderPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"];
            
			growlMailBundleURL = [NSURL fileURLWithPath:growlMailBundlePath];
			if ([growlMailBundleURL checkResourceIsReachableAndReturnError:NULL]) {
				[self.growlMailFoundBundles addObject:[GrowlMailFoundBundle foundBundleWithURL:growlMailBundleURL]];
			}

		}

		if ([self.growlMailFoundBundles count] > 0UL) {
			self.selectedBundleIndexes = [NSIndexSet indexSetWithIndex:0UL];
		} else {
			self.selectedBundleIndexes = [NSIndexSet indexSet];
		}

		NSBundle *mailAppBundle = [NSBundle bundleWithPath:@"/Applications/Mail.app"];
		self.mailUUID = [mailAppBundle objectForInfoDictionaryKey:@"PluginCompatibilityUUID"];

		self.currentVersionOfGrowlMail = hardCodedGrowlMailCurrentVersionNumber;

		[NSBundle loadNibNamed:@"GrowlMailBundles" owner:self];
		
		[self recomputeSelectedBundleNotes];
		[self.warningNotesTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        
        [self addObserver:self forKeyPath:@"selectedBundleIndexes" options:NSKeyValueObservingOptionNew context:nil];
	}
	return self;
}

- (void) dealloc
{
	[self removeObserver:self forKeyPath:@"selectedBundleIndexes"];
    [self.delayedEnableTimer invalidate];
    
	[self.confirmationSheet close];
	[self.window close];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"selectedBundleIndexes"])
    {
        [self recomputeSelectedBundleNotes];
    }
}

- (BOOL) multipleGrowlMailsInstalled
{
	return [self.growlMailFoundBundles count] > 1UL;
}

- (BOOL) canAndShouldPatchSelectedBundle
{
	return self.selectedBundle && (!self.selectedBundle.isCompatibleWithCurrentMailAndMessageFramework) && ([[self.warningNotes valueForKeyPath:@"@sum.fatal"] unsignedIntegerValue] == 0UL);
}

- (void) recomputeSelectedBundleNotes
{
	GrowlMailFoundBundle *selectedBundle = self.selectedBundle;
	NSMutableArray *newNotes = [NSMutableArray array];

	if ([self.growlMailFoundBundles count] > 1UL)
    {
		[newNotes addObject:[GrowlMailWarningNote warningNoteForMultipleGrowlMailsWithCurrentVersion:self.currentVersionOfGrowlMail]];
	}
	if (selectedBundle)
    {
		if (compareVersionStrings(selectedBundle.bundleVersion, self.currentVersionOfGrowlMail) == kCFCompareLessThan)
        {
			[newNotes addObject:[GrowlMailWarningNote warningNoteForGrowlMailOlderThanCurrentVersion:self.currentVersionOfGrowlMail]];
		}
		if (selectedBundle.domain != NSUserDomainMask)
        {
			[newNotes addObject:[GrowlMailWarningNote warningNoteForGrowlMailInTheWrongPlace]];
		}
	}

	self.warningNotes = newNotes;

	//Recompute window size.
	NSView *scrollView = [self.warningNotesTable superview];
	NSRect tableFrameInWindowSpace = [scrollView convertRect:[scrollView bounds] toView:nil];
	NSRect windowFrame = [self.window frame];
	CGFloat heightOfWindow = windowFrame.size.height;
	CGFloat heightBelow = NSMinY(tableFrameInWindowSpace);
	CGFloat heightAbove = heightOfWindow - NSMaxY(tableFrameInWindowSpace);

	CGFloat newHeightOfTable = 0.0f;
	for (NSUInteger i = 0UL, numNotes = [self.warningNotes count]; i < numNotes; ++i)
    {
		newHeightOfTable += [self tableView:self.warningNotesTable heightOfRow:i];
	}
	if (newHeightOfTable < 1.0f)
	{
        newHeightOfTable = 1.0f;
	}
    else
    {
		//Icky fudge factor to avoid the descent of the last line of the last row being cut off in some cases.
		newHeightOfTable += 4.0f;
	}

	CGFloat newHeightOfWindow = heightAbove + newHeightOfTable + heightBelow;
	CGFloat windowTop = windowFrame.origin.y + windowFrame.size.height;
	windowFrame.size.height = newHeightOfWindow;
	windowFrame.origin.y = windowTop - newHeightOfWindow;
	[self.window setFrame:windowFrame display:YES animate:YES];
}

- (GrowlMailFoundBundle *) selectedBundle
{
	return ([self.selectedBundleIndexes count] == 1UL)
		? (self.growlMailFoundBundles)[[self.selectedBundleIndexes firstIndex]]
		: nil;
}

//Ensure that the warning notes table never has a selection.
- (NSIndexSet *) selectionIndexesOfWarningNotes {
	return [NSIndexSet indexSet];

}

- (void) setSelectionIndexesOfWarningNotes:(NSIndexSet *)newIndexes
{
	//Do nothing, successfully.
	//The only reason this is here is because NSArrayController hates being bound to this property if there's no setter.
}

- (void) applyChangeToFoundBundle:(GrowlMailFoundBundle *)bundle
{
	NSParameterAssert(bundle != nil);
	NSParameterAssert([bundle isKindOfClass:[GrowlMailFoundBundle class]]);

	NSURL *bundleURL = bundle.URL;
	NSURL *infoDictURL = [[bundleURL URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];

	NSInputStream *inStream = [NSInputStream inputStreamWithURL:infoDictURL];
	NSError *error = nil;
	NSPropertyListFormat format = 0;
	[inStream open];
	NSMutableDictionary *dict = [NSPropertyListSerialization propertyListWithStream:inStream
																			options:NSPropertyListMutableContainers
																			 format:&format
																			  error:&error];
	[inStream close];
	if (!dict)
    {
		[self.window presentError:error];
	}
    else
    {
		NSMutableArray *UUIDs = dict[@"SupportedPluginCompatibilityUUIDs"];
		if(!UUIDs)
        {
            [dict setValue:[NSMutableArray array] forKey:@"SupportedPluginCompatibilityUUIDs"];
            UUIDs = dict[@"SupportedPluginCompatibilityUUIDs"];
        }
        if (self.mailUUID && ![UUIDs containsObject:self.mailUUID])
		{
            [UUIDs addObject:self.mailUUID];
        }
        
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict
																  format:format
																 options:0
																   error:&error];
		if (!data)
        {
			[self.window presentError:error];
		}
        else
        {
			[self willChangeValueForKey:@"canAndShouldPatchSelectedBundle"];
			[bundle willChangeValueForKey:@"isCompatibleWithCurrentMailAndMessageFramework"];
			BOOL wrote = [data writeToURL:infoDictURL
								  options:NSDataWritingAtomic
									error:&error];
			[bundle didChangeValueForKey:@"isCompatibleWithCurrentMailAndMessageFramework"];
			[self didChangeValueForKey:@"canAndShouldPatchSelectedBundle"];
			if (!wrote)
            {
				[self.window presentError:error];
			}
		}
	}

}

- (IBAction) patchSelectedBundle:(id)sender
{
	[self.okButton setEnabled:NO];
    
	[self.delayedEnableTimer invalidate];
	self.delayedEnableTimer = nil;
	
    if([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
    {
        [self enableOKButton:nil];
    }
    else
    {
        self.delayedEnableTimer = [NSTimer scheduledTimerWithTimeInterval:BUTTON_ENABLING_DELAY target:self selector:@selector(enableOKButton:) userInfo:nil repeats:NO];
	}
    [NSApp beginSheet:self.confirmationSheet modalForWindow:self.window modalDelegate:self didEndSelector:@selector(confirmationSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void) enableOKButton:(NSTimer *)timer
{
	[self.okButton setEnabled:YES];
}

- (void) confirmationSheetDidEnd:(NSWindow *)sheet
					  returnCode:(NSInteger)returnCode
					 contextInfo:(void *)contextInfo
{
	[self.delayedEnableTimer invalidate];
	self.delayedEnableTimer = nil;

	if (returnCode == NSOKButton)
    {
		[self applyChangeToFoundBundle:self.selectedBundle];
        [self moveBundleBackToActiveLocation:[NSBundle bundleWithPath:self.selectedBundle.URL.path]];
        [self relaunchMail];
	}

	[sheet close];
}

- (IBAction) ok:(id) sender
{
	NSWindow *dialog = [sender respondsToSelector:@selector(window)] ? [sender window] : sender;
	[NSApp endSheet:dialog returnCode:NSOKButton];
}

- (IBAction) cancel:(id) sender
{
	NSWindow *dialog = [sender respondsToSelector:@selector(window)] ? [sender window] : sender;
	[NSApp endSheet:dialog returnCode:NSCancelButton];
}

- (BOOL)moveBundleBackToActiveLocation:(NSBundle*)chosenOne
{
    BOOL result = YES;
    NSString *path = [chosenOne bundlePath];
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    NSString *destinationPath = [parentPath stringByDeletingLastPathComponent];
    
    if(![[parentPath lastPathComponent] isEqualToString:@"Bundles"])
    {
        destinationPath = [destinationPath stringByAppendingPathComponent:@"Bundles"];
        BOOL dir = NO;
        NSError *error = nil;
        if(![[NSFileManager defaultManager] fileExistsAtPath:destinationPath isDirectory:&dir] || !dir)
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        
        if(error)
        {
            result = NO;
        }
        
        if(result)
        {
            [[NSFileManager defaultManager] moveItemAtPath:[chosenOne bundlePath] toPath:[destinationPath stringByAppendingPathComponent:@"GrowlMail.mailbundle"] error:&error];
        }
        
        if(error)
        {
            result = NO;
        }
    }
    else
    {
        result = NO;
    }
    
    return result;
}

- (BOOL)mailIsRunning
{
	BOOL result = NO;
	NSArray *applications = [[NSWorkspace sharedWorkspace] runningApplications];
	for(NSRunningApplication *application in applications)
	{
		if([[application bundleIdentifier] isEqualToString:@"com.apple.mail"])
		{	
			result = YES;
			break;
		}
	}
	return result;
}

- (void)relaunchMail
{
    NSArray *applications = [[NSWorkspace sharedWorkspace] runningApplications];
    for(NSRunningApplication *application in applications)
    {
        if([[application bundleIdentifier] isEqualToString:mailAppBundleID])
        {	
            [application addObserver:self forKeyPath:@"terminated" options:NSKeyValueObservingOptionNew context:(__bridge void *)(self)];
            if([application terminate])
            {
                [application removeObserver:self forKeyPath:@"terminated"];
                [[NSWorkspace sharedWorkspace] performSelector:@selector(launchApplication:) withObject:@"Mail.app" afterDelay:2.0f];
            }
        }
    }
}

#pragma mark NSTableViewDelegate protocol conformance

- (CGFloat) tableView:(NSTableView *)theTableView heightOfRow:(NSInteger)row {
	CGFloat height = [self.warningNotesTable rowHeight];
	/*This code is adapted from an Apple code sample:
	 *	http://developer.apple.com/mac/library/samplecode/CocoaTipsAndTricks/Listings/TableViewVariableRowHeights_TableViewVariableRowHeightsAppDelegate_m.html
	 *It is more reliable than measuring the text directly. Thanks to Jesper for telling me about it. -PRH
	 */ {
		// It is important to use a constant value when calculating the height. Querying the tableColumn width will not work, since it dynamically changes as the user resizes -- however, we don't get a notification that the user "did resize" it until after the mouse is let go. We use the latter as a hook for telling the table that the heights changed. We must return the same height from this method every time, until we tell the table the heights have changed. Not doing so will quicly cause drawing problems.
		NSString *tableColumnIdentifier = @"message";
		NSTableColumn *tableColumnToWrap = [self.warningNotesTable tableColumnWithIdentifier:tableColumnIdentifier];
		NSInteger columnToWrap = [self.warningNotesTable.tableColumns indexOfObject:tableColumnToWrap];

		// Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
		NSCell *cell = [self.warningNotesTable preparedCellAtColumn:columnToWrap row:row];

		// See how tall it naturally would want to be if given a restricted with, but unbound height
		NSRect constrainedBounds = NSMakeRect(0, 0, [[self.warningNotesTable tableColumnWithIdentifier:tableColumnIdentifier] width], CGFLOAT_MAX);
		NSSize naturalSize = [cell cellSizeForBounds:constrainedBounds];

		// Make sure we have a minimum height -- use the table's set height as the minimum.
		if (naturalSize.height > height)
        {
			height = naturalSize.height;
		}
	}
	
	CGFloat iconColumnWidth = [[theTableView tableColumnWithIdentifier:@"fatality"] width];
	if (height < iconColumnWidth)
    {
		height = iconColumnWidth;
    }
	return height;
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
	//Never allow any selection.
	return [NSIndexSet indexSet];
}

@end
