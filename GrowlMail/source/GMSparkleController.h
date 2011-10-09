//
//  SparkleController.h
//  GrowlMail
//
//  Created by Rudy Richter on 10/9/11.
//  Copyright 2011 Ambrosia Software, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GMSparkleController : NSObject
{
    Class sparkleClass;
    id sparkle;
}

+ (id)sharedController;
- (IBAction)checkForUpdates:(id)sender;
- (void)checkForUpdatesInBackground;

@end
