//
//  SparkleController.m
//  GrowlMail
//
//  Created by Rudy Richter on 10/9/11.
//  Copyright 2011 Ambrosia Software, Inc. All rights reserved.
//

#import "GMSparkleController.h"
#import "Sparkle/Sparkle.h"

static GMSparkleController *sharedControl = nil;

@implementation GMSparkleController

+ (id)sharedController
{
    if(!sharedControl)
        sharedControl = [[GMSparkleController alloc] init];
    return sharedControl;
}

- (id)init
{
    if ((self = [super init])) 
    {
        NSBundle *growlMailBundle = [NSBundle bundleForClass:[self class]];
        NSString *privateFrameworksPath = [growlMailBundle privateFrameworksPath];
        
        NSString *sparkleBundlePath = [privateFrameworksPath stringByAppendingPathComponent:@"Sparkle.framework"];
        NSBundle *sparkleBundle = [NSBundle bundleWithPath:sparkleBundlePath];
        if (sparkleBundle && [sparkleBundle load]) 
        {
            sparkleClass = NSClassFromString(@"RRGMSUUpdater");
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
    return [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"1", @"value", @"id", @"key", nil]];
}

- (void)setUpdateCheckInterval:(NSTimeInterval)updateTime
{
    [sparkle setUpdateCheckInterval:updateTime];
}
@end
