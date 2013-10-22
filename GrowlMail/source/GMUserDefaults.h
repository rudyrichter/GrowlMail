//
//  GMUserDefaults.h
//  GrowlMail
//
//  Created by Rudy Richter on 10/23/11.
//  Copyright (c) 2011 Rudy Richter. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GMUserDefaults : NSUserDefaults
{
    NSString *_domain;
    NSDictionary *_registeredDefaults;
}

@property (nonatomic, retain) NSString *domain;
@property (nonatomic, retain) NSDictionary *registeredDefaults;

- (id)initWithPersistentDomainName:(NSString*)domain;

@end
