//
//  NSMutableString+Join.h
//  JsonExtensionCreator
//
//  Created by mac-246 on 12.02.16.
//  Copyright © 2016 mac-246. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableString (Join)

- (void)addNextPart:(NSString *)nextPartString with:(NSString *)withString;

@end
