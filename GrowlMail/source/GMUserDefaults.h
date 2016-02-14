//
//  GMUserDefaults.h
//  GrowlMail
//
//  Created by Rudy Richter on 10/23/11.
//  Copyright (c) 2011-2014 Rudy Richter. All rights reserved.
//

@import Foundation;
@import AppKit;

@interface GMUserDefaults : NSUserDefaults

@property (nonatomic, strong) NSString *domain;
@property (nonatomic, strong) NSDictionary *registeredDefaults;

- (instancetype)initWithPersistentDomainName:(NSString*)domain;

@end
