//
//  GrowlMailUUIDPatcherAppDelegate.m
//  GrowlMailUUIDPatcher
//
//  Created by Rudy Richter on 7/10/10.
//  Copyright 2010–2011 The Growl Project. All rights reserved.
//

#import "GrowlMailUUIDPatcherAppDelegate.h"

#import "GrowlMailUUIDPatcher.h"

@interface GrowlMailUUIDPatcherAppDelegate()
@property (nonatomic, strong) GrowlMailUUIDPatcher *patcher;
@end

@implementation GrowlMailUUIDPatcherAppDelegate

- (void) dealloc
{
    self.patcher = nil;
}

- (void) applicationWillFinishLaunching:(NSNotification *)aNotification {
	self.patcher = [[GrowlMailUUIDPatcher alloc] init];
}


- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

@end
