/*
 Copyright (c) Rudy Richter, 2011-2012
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

#import "GrowlMail.h"
#import "GrowlMailNotifier.h"

#import <objc/runtime.h>
#import "GMSparkleController.h"


NSBundle *GMGetGrowlMailBundle(void)
{
	return [NSBundle bundleForClass:[GrowlMail class]];
}

static NSImage *growlMailIcon = nil;

@implementation GrowlMail

#pragma mark Boring bookkeeping stuff
+ (void) load
{
    [[GMSparkleController sharedController] checkForUpdatesInBackground];
}

+ (void) initialize 
{
	[super initialize];
    
	//We attempt to get a reference to the MVMailBundle class so we can swap superclasses, failing that 
	//we disable ourselves and are done since this is an undefined state
	Class mvMailBundleClass = NSClassFromString(@"MVMailBundle");
	if(!mvMailBundleClass)
		GMShutDownGrowlMailAndWarn(@"Mail.app does not have a MVMailBundle class available");
	else
	{		
		//finish setup
        growlMailIcon = [[GMGetGrowlMailBundle() imageForResource:@"GrowlMail"] retain];
		[growlMailIcon setName:@"GrowlMail"];
		
		[GrowlMail registerBundle];
		
		NSLog(@"Loaded GrowlMail %@", [GMGetGrowlMailBundle() objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]);        
        
    }
}

+ (void)registerBundle 
{
    if(class_getClassMethod(NSClassFromString(@"MVMailBundle"), @selector(registerBundle)))
       [NSClassFromString(@"MVMailBundle") performSelector:@selector(registerBundle)];
    [[self class] setup];
}

+ (BOOL) hasPreferencesPanel 
{
	return YES;
}

+ (NSString *) preferencesOwnerClassName 
{
	return @"GrowlMailPreferencesModule";
}

+ (NSString *) preferencesPanelName 
{
	return @"GrowlMail";
}

+ (void) setup 
{
    NSString *privateFrameworksPath = [GMGetGrowlMailBundle() privateFrameworksPath];
    NSString *growlBundlePath = [privateFrameworksPath stringByAppendingPathComponent:@"Growl.framework"];
    NSBundle *growlBundle = [NSBundle bundleWithPath:growlBundlePath];
    if (growlBundle) 
    {
        if ([growlBundle load]) 
        {
            if ([NSClassFromString(@"GrowlApplicationBridge") respondsToSelector:@selector(frameworkInfoDictionary)]) {
                //Create or obtain our singleton notifier instance.
                GrowlMailNotifier *sharedNotifier = [GrowlMailNotifier sharedNotifier];
                if (!sharedNotifier)
                    NSLog(@"Could not initialize GrowlMail notifier object");
                
                NSDictionary *infoDictionary = [NSClassFromString(@"GrowlApplicationBridge") frameworkInfoDictionary];
                NSLog(@"Using Growl.framework %@ (%@)",
                      [infoDictionary objectForKey:@"CFBundleShortVersionString"],
                      [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey]);
            } 
        }
    } 
    else 
    {
        NSLog(@"Could not load Growl.framework, GrowlMail disabled");
    }
}

@end
