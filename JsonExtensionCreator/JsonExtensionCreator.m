//
//  JsonExtensionCreator.m
//  JsonExtensionCreator
//
//  Created by mac-246 on 12.02.16.
//  Copyright © 2016 mac-246. All rights reserved.
//

#import "JsonExtensionCreator.h"
#import "NSMutableString+Join.h"

static NSString *sourceDirectory = @"/Users/mac-246/Documents/Projects/rockspoon-pos/android-sdk/src/main/java/com/rockspoon/swift-models";
static NSString *outputDirectory = @"/Users/mac-246/Documents/Projects/rockspoon-ios/Models/Models";
static const NSString *propertyTypeKey = @"propertyType";
static const NSString *propertyNameKey = @"propertyName";
static const NSString *propertyJsonNameKey = @"propertyJsonName";
static const NSString *propertyUnavailableKey = @"propertyUnavailable";

@interface JsonExtensionCreator ()
@property (nonatomic) NSMutableSet *allIntEnumsNames;
@property (nonatomic) NSMutableSet *allStringEnumsNames;
@property (nonatomic) NSMutableSet *allClassesNames;
@end

@implementation JsonExtensionCreator

- (instancetype)init {
    if (!(self = [super init])) return nil;
    
    [self getEnumsNames];
    [self getClassesNames];
    [self createDirrectories];
    [self createExtensions];
    
    return self;
}

- (void)getEnumsNames {
    _allIntEnumsNames = [NSMutableSet set];
    _allStringEnumsNames = [NSMutableSet set];
    
    NSURL *baseUrl = [NSURL URLWithString:sourceDirectory];
    NSArray *files = [self getFilesUrls:baseUrl];
    for (NSURL *currentUrl in files) {
        NSError *error = nil;
        NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:currentUrl encoding:NSASCIIStringEncoding error:&error];
        NSArray *components = [stringFromFileAtURL componentsSeparatedByString:@" enum "];
        for (NSInteger i = 1; i < components.count; i++) {
            NSString *currentComponent = components[i];
            NSArray *components = [currentComponent componentsSeparatedByString:@": "];
            NSString *currentEnumName = components[0];
            NSString *currentEnumType = components[1];
            currentEnumType = [currentEnumType componentsSeparatedByString:@", "][0];
            if ([currentEnumType isEqualToString:@"String"]) {
                [_allStringEnumsNames addObject:currentEnumName];
            } else {
                [_allIntEnumsNames addObject:currentEnumName];
            }
        }
    }
}

- (void)getClassesNames {
    _allClassesNames = [NSMutableSet set];
    
    NSURL *baseUrl = [NSURL URLWithString:sourceDirectory];
    NSArray *files = [self getFilesUrls:baseUrl];
    for (NSURL *currentUrl in files) {
        NSError *error = nil;
        NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:currentUrl encoding:NSASCIIStringEncoding error:&error];
        NSArray *components = [stringFromFileAtURL componentsSeparatedByString:@" class "];
        for (NSInteger i = 1; i < components.count; i++) {
            NSString *currentComponent = components[i];
            NSString *currentEnumName = [currentComponent componentsSeparatedByString:@": "][0];
            [_allClassesNames addObject:currentEnumName];
        }
    }
}

- (void)createExtensions {
    NSURL *baseUrl = [NSURL URLWithString:sourceDirectory];
    NSArray *files = [self getFilesUrls:baseUrl];
    for (NSURL *currentUrl in files) {
        if (![self isClassFileUrl:currentUrl]) { continue; }
        
        // Class name
        NSString *className = [self getClassName:currentUrl];
        // Properties
        NSArray *propertiesArray = [self exctractPropertiesFromFile:currentUrl];
        // Json file string
        NSString *currentJsonFileString = [self createJsonFileStringFromPropertiesArray:propertiesArray className:className];
        // Path to file
        NSURL *currentFileOutputUrl = [self changeBaseUrlForUrl:currentUrl basePath:sourceDirectory newBasePath:outputDirectory];
        // Add postfix
        currentFileOutputUrl = [self addPostfixToFileName:currentFileOutputUrl postfix:@"+JSON"];
        // Write
        [self writeString:currentJsonFileString file:currentFileOutputUrl];
    }
}

- (NSString *)createJsonFileStringFromPropertiesArray:(NSArray *)propertiesArray className:(NSString *)className {
    NSMutableString *jsonFileString = [NSMutableString string];
    
    NSString *titleString = [self titleStringWithName:className];
    [jsonFileString addNextPart:titleString with:@"\n\n"];
  
    NSString *swiftlintDisableString = @"// swiftlint:disable line_length";
    [jsonFileString addNextPart:swiftlintDisableString with:@"\n"];
  
    [jsonFileString addNextPart:@"import SwiftyJSON" with:@"\n\n"];
    
    NSString *classDeclarationString = [NSString stringWithFormat:@"extension %@: JSONInitializable {\n\n  public convenience init?(json: JSON) {\n    guard !json.isEmpty else { return nil }\n    self.init()", className];
    [jsonFileString addNextPart:classDeclarationString with:@"\n\n"];
    
    NSString *propertySetString = [self propertySetStringFromPropertiesArray:propertiesArray];
    [jsonFileString addNextPart:propertySetString with:@""];
    
    [jsonFileString addNextPart:@"  }" with:@"\n\n"];
    [jsonFileString addNextPart:@"  public func toJSON() -> JSON {" with:@"\n"];
    [jsonFileString addNextPart:@"    var json: JSON = [:]" with:@"\n"];
    
    NSString *jsonSetString = [self jsonSetStringFromPropertiesArray:propertiesArray];
    [jsonFileString addNextPart:jsonSetString with:@"\n"];
    
    [jsonFileString addNextPart:@"    return json" with:@"\n"];
    [jsonFileString addNextPart:@"  }" with:@"\n"];
    [jsonFileString addNextPart:@"}" with:@"\n"];
  
    return jsonFileString;
}

- (NSString *)propertySetStringFromPropertiesArray:(NSArray *)propertiesArray {
    NSMutableString *propertySetString = [NSMutableString string];
    for (NSDictionary *currentPropertyDictionary in propertiesArray) {
        NSString *currentPropertyName = currentPropertyDictionary[propertyNameKey];
        NSString *currentPropertyType = currentPropertyDictionary[propertyTypeKey];
        NSString *currentPropertyJsonName = currentPropertyDictionary[propertyJsonNameKey] ?: currentPropertyName;
        NSString *currentJsonProperty = [self getJsonProperty:currentPropertyType];
        NSString *currentPropertySetString = nil;
        if (currentJsonProperty) {
            NSString *jsonPropertyString = [NSString stringWithFormat:@"json[\"%@\"]", currentPropertyJsonName];
            if (currentJsonProperty) {
                jsonPropertyString = [NSString stringWithFormat:@"%@%@", jsonPropertyString, currentJsonProperty];
            }
            if ([self isEnumPropertyType:currentPropertyType]) {
                jsonPropertyString = [NSString stringWithFormat:@"%@(%@)", currentPropertyType, jsonPropertyString];
            } else if ([self isEnumArrayPropertyType:currentPropertyType]) {
                jsonPropertyString = [NSString stringWithFormat:@"enumsFromJSONArray(%@)", jsonPropertyString];
            } else if ([self isClassPropertyType:currentPropertyType]) {
                jsonPropertyString = [NSString stringWithFormat:@"%@(json: %@)", currentPropertyType, jsonPropertyString];
            } else if ([self isClassArrayPropertyType:currentPropertyType]) {
                jsonPropertyString = [NSString stringWithFormat:@"modelsFromJSONArray(%@)", jsonPropertyString];
            }
            currentPropertySetString = [NSString stringWithFormat:@"    %@ = %@", currentPropertyName, jsonPropertyString];
            if ([self isCastingNecessaryForJsonProperty:currentJsonProperty propertyType:currentPropertyType]) {
                currentPropertySetString = [NSString stringWithFormat:@"%@ as? %@", currentPropertySetString, currentPropertyType];
            }
        } else {
            currentPropertySetString = [NSString stringWithFormat:@"    %@ = json[\"%@\"].%@", currentPropertyName, currentPropertyJsonName, currentPropertyType];
            currentPropertySetString = [self commentString:currentPropertySetString];
            NSLog(@"%@", currentPropertyType);
        }
        [propertySetString addNextPart:currentPropertySetString with:@"\n"];
    }
    
    return propertySetString;
}

- (NSString *)jsonSetStringFromPropertiesArray:(NSArray *)propertiesArray {
    NSMutableString *propertySetString = [NSMutableString string];
    for (NSDictionary *currentPropertyDictionary in propertiesArray) {
        NSString *currentPropertyName = currentPropertyDictionary[propertyNameKey];
        NSString *currentPropertyType = currentPropertyDictionary[propertyTypeKey];
        NSString *currentPropertyJsonName = currentPropertyDictionary[propertyJsonNameKey] ?: currentPropertyName;
        NSString *currentJsonProperty = [self getJsonProperty:currentPropertyType];
        NSString *currentJsonSetString = nil;
        if (currentJsonProperty) {
            NSString *jsonPropertyString = [NSString stringWithFormat:@"json[\"%@\"]", currentPropertyJsonName];
            if (currentJsonProperty) {
                jsonPropertyString = [NSString stringWithFormat:@"%@%@", jsonPropertyString, currentJsonProperty];
            }

            NSString *convertedValue = currentPropertyName;
            if ([self isEnumPropertyType:currentPropertyType]) {
                convertedValue = [NSString stringWithFormat:@"%@.rawValue", currentPropertyName];
            } else if ([self isClassPropertyType:currentPropertyType]) {
                convertedValue = [NSString stringWithFormat:@"%@.toJSON()", currentPropertyName];
            }

            NSString *expressionToUnwrap = currentPropertyName;
            if ([self isClassArrayPropertyType:currentPropertyType]) {
                expressionToUnwrap = [NSString stringWithFormat:@"JSONArrayFromModels(%@)", currentPropertyName];
            } else if ([self isEnumArrayPropertyType:currentPropertyType]) {
                expressionToUnwrap = [NSString stringWithFormat:@"JSONArrayFromEnums(%@)", currentPropertyName];
            }

            currentJsonSetString = [NSString stringWithFormat:@"    if let %@ = %@ { %@ = %@ }", currentPropertyName, expressionToUnwrap, jsonPropertyString, convertedValue];
        } else {
            currentJsonSetString = [NSString stringWithFormat:@"    json[\"%@\"].%@ = %@", currentPropertyJsonName, currentPropertyName, currentPropertyName];
            currentJsonSetString = [self commentString:currentJsonSetString];
        }
        [propertySetString addNextPart:currentJsonSetString with:@"\n"];
    }
    
    return propertySetString;
}

- (NSString *)getJsonProperty:(NSString *)propertyType {
    // Base
    if ([propertyType isEqualToString:@"String"]) {
        return @".forceString";
    }
    if ([propertyType isEqualToString:@"Int"]) {
        return @".forceInt";
    }
    if ([propertyType isEqualToString:@"Double"]) {
        return @".forceDouble";
    }
    if ([propertyType isEqualToString:@"Bool"]) {
        return @".bool";
    }
    
    // Base dictionaries
    if ([self isDictionaryPropertyType:propertyType]) {
        return @".dictionaryObject";
    }

    // Class array
    if ([self isClassArrayPropertyType:propertyType]) {
      return @"";
    }

    // Enum array
    if ([self isEnumArrayPropertyType:propertyType]) {
      return @"";
    }

    // Base arrays
    if ([self isArrayPropertyType:propertyType]) {
        return @".arrayObject";
    }
    
    // Extension
    if ([propertyType isEqualToString:@"NSDate"]) {
        return @".date";
    }
    
    if ([propertyType isEqualToString:@"NSUUID"]) {
        return @".uuid";
    }
    
    // Extension Set
    if ([self isSetPropertyType:propertyType]) {
        return @".set";
    }
    
    // Enum Int
    if ([self isIntEnumPropertyType:propertyType]) {
        return @".forceInt";
    }
    
    // Enum String
    if ([self isStringEnumPropertyType:propertyType]) {
        return @".forceString";
    }
    
    // Class
    if ([self isClassPropertyType:propertyType]) {
        return @"";
    }
    
    return nil;
}

- (BOOL)isDictionaryPropertyType:(NSString *)propertyType {
    NSInteger openingBracket = 0;
    NSInteger closingBracket = 0;
    for (NSInteger i = 0; i < propertyType.length; i++) {
        NSString *characterString = [propertyType substringWithRange:NSMakeRange(i, 1)];
        
        if ([characterString isEqualToString:@"["]) {
            openingBracket++;
        } else if ([characterString isEqualToString:@"]"]) {
            closingBracket++;
        } else if ([characterString isEqualToString:@":"]) {
            if (openingBracket - closingBracket == 1) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)isArrayPropertyType:(NSString *)propertyType {
    if ([self isDictionaryPropertyType:propertyType]) { return NO; }
    
    NSString *firstCharacter = [propertyType substringWithRange:NSMakeRange(0, 1)];
    NSString *lastCharacter = [propertyType substringWithRange:NSMakeRange(propertyType.length - 1, 1)];
    
    if ([firstCharacter isEqualToString:@"["] && [lastCharacter isEqualToString:@"]"]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isEnumPropertyType:(NSString *)propertyType {
    if ([self isIntEnumPropertyType:propertyType]) {
        return YES;
    }
    if ([self isStringEnumPropertyType:propertyType]) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isIntEnumPropertyType:(NSString *)propertyType {
    for (NSString *enumName in _allIntEnumsNames) {
        if ([propertyType isEqualToString:enumName]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isStringEnumPropertyType:(NSString *)propertyType {
    for (NSString *enumName in _allStringEnumsNames) {
        if ([propertyType isEqualToString:enumName]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isIntEnumArrayPropertyType:(NSString *)propertyType {
  for (NSString *enumName in _allIntEnumsNames) {
    if ([propertyType isEqualToString:[NSString stringWithFormat:@"[%@]", enumName]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isStringEnumArrayPropertyType:(NSString *)propertyType {
  for (NSString *enumName in _allStringEnumsNames) {
    if ([propertyType isEqualToString:[NSString stringWithFormat:@"[%@]", enumName]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isEnumArrayPropertyType:(NSString *)propertyType {
  return [self isStringEnumArrayPropertyType:propertyType] || [self isIntEnumArrayPropertyType:propertyType];
}

- (BOOL)isClassPropertyType:(NSString *)propertyType {
    for (NSString *currentClassName in _allClassesNames) {
        if ([propertyType isEqualToString:currentClassName]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isClassArrayPropertyType:(NSString *)propertyType {
  for (NSString *className in _allClassesNames) {
    if ([propertyType isEqualToString:[NSString stringWithFormat:@"[%@]", className]]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)isSetPropertyType:(NSString *)propertyType {
    if ([propertyType rangeOfString:@"Set<"].location == 0) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isCastingNecessaryForJsonProperty:(NSString *)jsonProperty propertyType:(NSString *)propertyType {
    if ([jsonProperty isEqualToString:@".arrayObject"]) {
        if ([propertyType isEqualToString:@"[AnyObject]"]) {
            return NO;
        }
        if ([self isEnumArrayPropertyType:propertyType]) {
            return NO;
        }
        return YES;
    }
    if ([jsonProperty isEqualToString:@".dictionaryObject"]) {
        if ([propertyType isEqualToString:@"[String: AnyObject]"]) {
            return NO;
        }
        return YES;
    }
    if ([jsonProperty isEqualToString:@".set"]) {
        return YES;
    }
    
    return NO;
}

- (void)createDirrectories {
    NSURL *directoryURL = [NSURL URLWithString:sourceDirectory];
    NSArray *dirrectories = [self getDirectoriesUrls:directoryURL];
    for (NSURL *currentUrl in dirrectories) {
        NSString *relativePath = [currentUrl.path stringByReplacingOccurrencesOfString:sourceDirectory withString:@""];
        NSString *outputPathString = [outputDirectory stringByAppendingPathComponent:relativePath];
        NSURL *directoryURL = [[NSURL alloc] initFileURLWithPath:outputPathString isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSArray *)exctractPropertiesFromFile:(NSURL *)fileUrl {
    NSError *error;
    NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:fileUrl encoding:NSUTF8StringEncoding error:&error];
    
    NSMutableArray *properties = [NSMutableArray array];
    NSArray *fileLines = [stringFromFileAtURL componentsSeparatedByString:@"\n"];
    for (NSString *currentLine in fileLines) {
        if (![currentLine containsString:@"public var "]) { continue; }
        if ([[currentLine substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"//"]) { continue; }
        
        NSMutableDictionary *property = [NSMutableDictionary dictionary];
        NSString *cuttedLine = [currentLine componentsSeparatedByString:@"public var "][1];
        // Property
        NSString *propertyName = [cuttedLine componentsSeparatedByString:@": "][0];
        [property setObject:propertyName forKey:propertyNameKey];
        cuttedLine = [cuttedLine componentsSeparatedByString:[NSString stringWithFormat:@"%@: ", propertyName]][1];
        NSArray *commentComponents = [cuttedLine componentsSeparatedByString:@" // "];
        // Type
        NSString *propertyType = commentComponents[0];
        propertyType = [propertyType stringByReplacingOccurrencesOfString:@"?" withString:@""];
        propertyType = [propertyType stringByReplacingOccurrencesOfString:@" : " withString:@": "];
        [property setObject:propertyType forKey:propertyTypeKey];
        // Comment
        if (commentComponents.count > 1 ) {
            NSString *propertyComment = commentComponents[1];
            [property setObject:propertyComment forKey:propertyJsonNameKey];
        }
        
        [properties addObject:property];
    }
    
    return properties;
}

#pragma mark Helpers
- (NSString *)getClassName:(NSURL *)fileUrl {
    NSError *error;
    NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:fileUrl encoding:NSUTF8StringEncoding error:&error];
    
    NSString *cuttedString = [stringFromFileAtURL componentsSeparatedByString:@"public final class "][1];
    NSString *className = [cuttedString componentsSeparatedByString:@": "][0];
    
    return className;
}

- (BOOL)isClassFileUrl:(NSURL *)fileUrl {
    NSError *error;
    NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:fileUrl encoding:NSUTF8StringEncoding error:&error];
    
    BOOL isClassString = [stringFromFileAtURL containsString:@" class "];
    
    return isClassString;
}

- (NSURL *)changeBaseUrlForUrl:(NSURL *)fullPathUrl basePath:(NSString *)basePath newBasePath:(NSString *)newBasePath {
    NSString *fullBasePathString = fullPathUrl.path;
    fullBasePathString = [fullBasePathString stringByReplacingOccurrencesOfString:basePath withString:newBasePath];
    
    return [NSURL fileURLWithPath:fullBasePathString];
}

- (NSURL *)addPostfixToFileName:(NSURL *)filePath postfix:(NSString *)postfix {
    NSString *oldFileName = filePath.lastPathComponent;
    NSString *oldFileNameWithoutExtension = [filePath URLByDeletingPathExtension].lastPathComponent;
    NSString *newFileName = [NSString stringWithFormat:@"%@%@.swift", oldFileNameWithoutExtension, postfix];
    NSString *oldPath = filePath.path;
    NSString *newPath = [oldPath stringByReplacingOccurrencesOfString:oldFileName withString:newFileName];
    NSURL *newUrl = [NSURL fileURLWithPath:newPath];
    
    return newUrl;
}

- (void)writeString:(NSString *)stringToWrite file:(NSURL *)fileUrl {
    NSError *error;
    BOOL ok = [stringToWrite writeToURL:fileUrl atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
        // an error occurred
        NSLog(@"Error writing file at %@\n%@", fileUrl, [error localizedFailureReason]);
    }
}

- (NSArray *)getFilesUrls:(NSURL *)baseUrl {
    NSArray *keys = [NSArray arrayWithObjects: NSURLIsDirectoryKey, NSURLIsPackageKey, NSURLLocalizedNameKey, nil];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:baseUrl includingPropertiesForKeys:keys options:(NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:^(NSURL *url, NSError *error) { return YES; }];
    
    NSMutableArray *filesUrls = [NSMutableArray array];
    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        
        if (![isDirectory boolValue]) {
            [filesUrls addObject:url];
        }
    }
    
    return filesUrls;
}

- (NSArray *)getDirectoriesUrls:(NSURL *)baseUrl {
    NSArray *keys = [NSArray arrayWithObjects: NSURLIsDirectoryKey, NSURLIsPackageKey, NSURLLocalizedNameKey, nil];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:baseUrl includingPropertiesForKeys:keys options:(NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles) errorHandler:^(NSURL *url, NSError *error) { return YES; }];
    
    NSMutableArray *directoriesUrl = [NSMutableArray array];
    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        
        if ([isDirectory boolValue]) {
            NSNumber *isPackage = nil;
            [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:NULL];
            
            if (![isPackage boolValue]) {
                [directoriesUrl addObject:url];
            }
        }
    }
    
    return directoriesUrl;
}

- (NSString *)intendString:(NSString *)string spaces:(NSString *)spaces {
    NSArray *components = [string componentsSeparatedByString:@"\n"];
    NSMutableArray *intentedComponents = [NSMutableArray arrayWithCapacity:components.count];
    
    for (NSString *currentComponent in components) {
        NSString *intendedComponent = [NSString stringWithFormat:@"%@%@", spaces, currentComponent];
        [intentedComponents addObject:intendedComponent];
    }
    
    NSString *intendedString = [intentedComponents componentsJoinedByString:@"\n"];
    
    return intendedString;
}

- (NSString *)titleStringWithName:(NSString *)name {
    NSString *titleSting = [NSString stringWithFormat:@"//\n//  %@.swift\n//  Models\n//\n//  Created by mac-246 on 10.02.16.\n//  Copyright © 2016 RockSpoon. All rights reserved.\n//", name];
    
    return titleSting;
}

- (NSString *)commentsWithText:(NSString *)commentsText spaces:(NSString *)spaces {
    NSString *commentsString = [NSString stringWithFormat:@"//-----------------------------------------------------------------------------\n// MARK: - %@\n//-----------------------------------------------------------------------------", commentsText];
    commentsString = [self intendString:commentsString spaces:spaces];
    
    return commentsString;
}

- (NSString *)commentString:(NSString *)stringToComment {
    return [NSString stringWithFormat:@"//%@", stringToComment];
}

- (BOOL)isUppercaseString:(NSString *)string {
    BOOL isUppercaseString = YES;
    for (NSInteger i = 0; i < string.length; i++) {
        unichar currentCharacter = [string characterAtIndex:i];
        BOOL isLowerCase = [[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:currentCharacter];
        if (isLowerCase) {
            isUppercaseString = NO;
            break;
        }
    }
    
    return isUppercaseString;
}

@end
