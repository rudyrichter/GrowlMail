//
//  GMUserDefaults.m
//  GrowlMail
//
//  Created by Rudy Richter on 10/23/11.
//  Copyright (c) 2011-2014 Rudy Richter. All rights reserved.
//

#import "GMUserDefaults.h"

@implementation GMUserDefaults

- (instancetype)initWithPersistentDomainName:(NSString*)domain
{
    if((self = [super init]))
    {
        self.domain = domain;
        self.registeredDefaults = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronize) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    

}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    [self willChangeValueForKey:defaultName];
    CFPreferencesSetValue((CFStringRef)defaultName, (__bridge CFPropertyListRef)(value), (CFStringRef)self.domain,  kCFPreferencesCurrentUser,  kCFPreferencesAnyHost);
    [self didChangeValueForKey:defaultName];
    [self synchronize];
}

- (id)objectForKey:(NSString *)defaultName
{
    id result = (id)CFBridgingRelease(CFPreferencesCopyValue((CFStringRef)defaultName, (CFStringRef)self.domain, kCFPreferencesCurrentUser,  kCFPreferencesAnyHost));
    if(!result)
        result = (self.registeredDefaults)[defaultName];
    return result;
}

- (void)removeObjectForKey:(NSString *)defaultName
{
    [self willChangeValueForKey:defaultName];
    CFPreferencesSetAppValue((CFStringRef)defaultName, NULL, (CFStringRef)self.domain);
    [self didChangeValueForKey:defaultName];
}

- (BOOL)synchronize
{
    return (BOOL)CFPreferencesSynchronize((CFStringRef)self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
@end
