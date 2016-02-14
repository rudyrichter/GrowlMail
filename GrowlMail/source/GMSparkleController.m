/*
 Copyright (c) 2011-2016, Rudy Richter.
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


#import "GMSparkleController.h"
#import "Sparkle/Sparkle.h"

@interface GMSparkleController () <NSFileManagerDelegate>
@end

static GMSparkleController *sharedControl = nil;

@implementation GMSparkleController

+ (GMSparkleController*)sharedController
{
    if(!sharedControl)
        sharedControl = [[GMSparkleController alloc] init];
    return sharedControl;
}

- (instancetype)init
{
    if ((self = [super init])) 
    {
        NSBundle *growlMailBundle = [NSBundle bundleForClass:[self class]];
        NSString *privateFrameworksPath = growlMailBundle.privateFrameworksPath;
        
        NSString *sparkleBundlePath = [privateFrameworksPath stringByAppendingPathComponent:@"Sparkle.framework"];
        NSBundle *sparkleBundle = [NSBundle bundleWithPath:sparkleBundlePath];
        if (sparkleBundle && [sparkleBundle load]) 
        {
            sparkleClass = NSClassFromString(@"BRGMSUUpdater");
            sparkle = [sparkleClass updaterForBundle:growlMailBundle];
            
            [sparkle setDelegate:self];
            [sparkle checkForUpdatesInBackground];
        }
    }
    
    return self;
}

- (IBAction)checkForUpdates:(id)sender
{
    [sparkle checkForUpdates:self];
}

- (void)checkForUpdatesInBackground
{
    [sparkle checkForUpdatesInBackground];
}

- (NSArray *)feedParametersForUpdater:(id)updater sendingSystemProfile:(BOOL)sendingProfile
{
    return @[@{@"value": @"1", @"key": @"id"}];
}

- (void)setUpdateCheckInterval:(NSTimeInterval)updateTime
{
    [sparkle setUpdateCheckInterval:updateTime];
}
@end
