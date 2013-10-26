//
//  GMUserDefaults.m
//  GrowlMail
//
//  Created by Rudy Richter on 10/23/11.
//  Copyright (c) 2011 Rudy Richter. All rights reserved.
//

#import "GMUserDefaults.h"

@implementation GMUserDefaults

- (id)initWithPersistentDomainName:(NSString*)domain
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
    
    [_domain release];
    [_registeredDefaults release];

    [super dealloc];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName
{
    [self willChangeValueForKey:defaultName];
    CFPreferencesSetValue((CFStringRef)defaultName, value, (CFStringRef)self.domain,  kCFPreferencesCurrentUser,  kCFPreferencesAnyHost);
    [self didChangeValueForKey:defaultName];
    [self synchronize];
}

- (id)objectForKey:(NSString *)defaultName
{
    id result = [(id)CFPreferencesCopyValue((CFStringRef)defaultName, (CFStringRef)self.domain, kCFPreferencesCurrentUser,  kCFPreferencesAnyHost) autorelease];
    if(!result)
        result = [self.registeredDefaults objectForKey:defaultName];
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
    return CFPreferencesSynchronize((CFStringRef)self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
@end
