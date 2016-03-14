//
//  NSMutableString+Join.m
//  JsonExtensionCreator
//
//  Created by mac-246 on 12.02.16.
//  Copyright © 2016 mac-246. All rights reserved.
//

#import "NSMutableString+Join.h"

@implementation NSMutableString (Join)
- (void)addNextPart:(NSString *)nextPartString with:(NSString *)withString {
    [self appendFormat:@"%@%@", nextPartString, withString];
}
@end
