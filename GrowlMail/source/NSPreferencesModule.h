/*
 Copyright (c) 2011-2013, Rudy Richter.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 3. Neither the name of Growl nor the names of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

@protocol NSPreferencesModule
- (void) moduleWasInstalled;
- (void) moduleWillBeRemoved;
- (void) didChange;
- (void) initializeFromDefaults;
- (void) willBeDisplayed;
- (void) saveChanges;
- (char) hasChangesPending;
- (NSImage *) imageForPreferenceNamed:(NSString *)aName;
- (NSView *) viewForPreferenceNamed:(NSString *)aName;
@end

@interface NSPreferencesModule:NSObject <NSPreferencesModule>
{
	IBOutlet NSBox *_preferencesView;
	NSSize _minSize;
	BOOL _hasChanges;
	void *_reserved;
}

+ (id) sharedInstance;
- (void) dealloc;
- (id) init;
- (NSString *) preferencesNibName;
- (void) setPreferencesView:fp12;
- (id) viewForPreferenceNamed:(NSString *)aName;
- (NSImage *) imageForPreferenceNamed:(NSString *)aName;
- (NSString *) titleForIdentifier:(NSString *)aName;
- (BOOL) hasChangesPending;
- (void) saveChanges;
- (void) willBeDisplayed;
- (void) initializeFromDefaults;
- (void) didChange;
- (NSSize) minSize;
- (void) moduleWillBeRemoved;
- (void) moduleWasInstalled;
- (BOOL) isResizable;

@end
