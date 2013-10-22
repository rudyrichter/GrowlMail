//
//  GMUserDefaults.m
//  GrowlMail
//
//  Created by Rudy Richter on 10/23/11.
//  Copyright (c) 2011 Rudy Richter. All rights reserved.
//

#import "GMUserDefaults.h"

@implementation GMUserDefaults
@synthesize domain = _domain;
@synthesize registeredDefaults = _registeredDefaults;

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
    CFPreferencesSetAppValue((CFStringRef)defaultName, (CFPropertyListRef)value, (CFStringRef)self.domain);
}

- (id)objectForKey:(NSString *)defaultName
{
    id result = [(id)CFPreferencesCopyAppValue((CFStringRef)defaultName, (CFStringRef)self.domain) autorelease];
    if(!result)
        result = [self.registeredDefaults objectForKey:defaultName];
    return result;
}

- (void)removeObjectForKey:(NSString *)defaultName
{
    CFPreferencesSetAppValue((CFStringRef)defaultName, NULL, (CFStringRef)self.domain);
}

- (BOOL)synchronize
{
    return CFPreferencesSynchronize((CFStringRef)self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}
@end
