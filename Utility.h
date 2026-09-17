//
//  Utility.h
//  AppVirality
//
//  Created by Ram on 11/04/15.
//  Copyright (c) 2015 AppVirality. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFHFKeychainUtils.h"

//////////////////////ADVANCED TRY CATCH SYSTEM////////////////////////////////////////
#ifndef UseTryCatch
#define UseTryCatch 1
#ifndef UsePTMName
#define UsePTMName 0  //USE 0 TO DISABLE AND 1 TO ENABLE PRINTING OF METHOD NAMES WHERE EVER TRY CATCH IS USED
#if UseTryCatch
#if UsePTMName
#define TCSTART @try{NSLog(@"\n%s\n",__PRETTY_FUNCTION__);
#else
#define TCSTART @try{
#endif
#define TCEND  }@catch(NSException *e){NSLog(@"\n\n\n\n\n\n\
\n\n|EXCEPTION FOUND HERE...PLEASE DO NOT IGNORE\
\n\n|FILE NAME         %s\
\n\n|LINE NUMBER       %d\
\n\n|METHOD NAME       %s\
\n\n|EXCEPTION REASON  %@\
\n\n\n\n\n\n\n",strrchr(__FILE__,'/'),__LINE__, __PRETTY_FUNCTION__,e);};
#else
#define TCSTART {
#define TCEND   }
#endif
#endif
#endif
//////////////////////ADVANCED TRY CATCH SYSTEM////////////////////////////////////////





#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define mainFont @"OpenSans"
#define baseFont @"OpenSans"
#define boldFont @"OpenSans-SemiBold"

#ifndef DEBUG_MODE
#define DEBUG_MODE 0
#if DEBUG_MODE
#define DLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DLog( s, ... )
#endif
#endif

#define SDK_VERSION @"1.2.12"
#define DEBUGKEY @"AppViralityDebug"
#define baseColor UIColorFromRGB(0xf79421)
#define iconColor UIColorFromRGB(0xababab)
#define barTintColor UIColorFromRGB(0xffffff)

#define fontColor UIColorFromRGB(0x6e6e6e)
#define fontColorLight UIColorFromRGB(0xadadad)
#define fontColorDark UIColorFromRGB(0x505050)

#define bgColor UIColorFromRGB(0xe5e5e5)

//#define SERVER_URL @"https://api1.appvirality.com/AVService.svc/v1_1_1"
//#define SERVER_URL_V2 @"https://api1.appvirality.com/AVService.svc/v1_1_2"
//#define SERVER_URL_V21 @"https://sdk.appvirality.com/sdk/v2_0"
//#define IMAGE_SERVER_URL @"https://growth1.appvirality.com"
//#define EMAIL_REGEX @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
//#define    PASSWORD_LENGTH 100
//#define RI_URL @"https://ri1.appvirality.com/RI.svc/v2/RI"
//#define SHARE_URL @"http://s.appvirality.com"

#define SERVER_URL @"https://api.appvirality.com/AVService.svc/v1_1_1"
#define SERVER_URL_V2 @"https://api.appvirality.com/AVService.svc/v1_1_2"
#define SERVER_URL_V21 @"https://sdk.appvirality.com/sdk/v2_0"
#define IMAGE_SERVER_URL @"https://growth.appvirality.com"
#define EMAIL_REGEX @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}"
#define    PASSWORD_LENGTH 100
#define RI_URL @"https://ri.appvirality.com/RI.svc/v2/RI"
#define SHARE_URL @"https://r.appvirality.com"
// The global QR channel (AppID IS NULL on the server), same for every app, campaign and user.
#define QR_SOCIAL_ACTION_ID @"1040"

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_RETINA ([[UIScreen mainScreen] scale] >= 2.0)

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define SCREEN_MAX_LENGTH (MAX(SCREEN_WIDTH, SCREEN_HEIGHT))
#define SCREEN_MIN_LENGTH (MIN(SCREEN_WIDTH, SCREEN_HEIGHT))

#define IS_IPHONE_4_OR_LESS (IS_IPHONE && SCREEN_MAX_LENGTH < 568.0)
#define IS_IPHONE_5 (IS_IPHONE && SCREEN_MAX_LENGTH == 568.0)
#define IS_IPHONE_6 (IS_IPHONE && SCREEN_MAX_LENGTH == 667.0)
#define IS_IPHONE_6P (IS_IPHONE && SCREEN_MAX_LENGTH == 736.0)

extern NSTimeInterval const NSURLConnectionDefaultTimeInterval;
extern NSString* _Nullable const NSAppViralityErrorDomain;


@interface Utility : NSObject
+ (nonnull NSOperationQueue *)connectionQueue;
+(nonnull NSString*)userAgentString;
+(void)userAgentStringWithCompletion:(void (^ _Nonnull)(NSString * _Nonnull agent))completion;
+(nonnull NSString*)GetDeviceID;
+(nonnull NSString*)GetTempUserKey;
+ (nonnull NSString *)GetUUID;
+ (BOOL)isSimulator;
+( NSDictionary* _Nullable )parseCampaignInfo:(NSDictionary* _Nullable)campaignInfo;
+(nonnull NSString*)shareBaseURLForCustomDomain:(nullable id)customDomain;
+(NSString* _Nullable)encodeToPercentEscapeString:(NSString * _Nullable)string ;
+(NSString* _Nullable)decodeFromPercentEscapeString:(NSString * _Nullable)string;
+(BOOL)checkRequiredKeys:(NSArray* _Nullable)requiredKeys WithGivenKeys:(NSArray* _Nullable)givenKeys;
+(NSDictionary* _Nullable)parseReferrerInfo:(NSDictionary*_Nullable)referrerDetails;
+(NSDictionary* _Nullable)parseReferrerInfov2:(NSDictionary*_Nullable)referrerDetails;
+ (NSString * _Nullable)getAdvertiserID;
+(NSString*_Nullable)decodeFromTerms:(NSString *_Nullable)string;
+(void)genericHTTPRequest:(NSURLRequest *_Nullable)request retryNumber:(NSInteger)retryNumber callback:(void (^_Nullable)(NSURLResponse*_Nullable response, NSData*_Nullable data, NSError*_Nullable connectionError))callback;
+(nullable NSData *)sendSynchronousRequest:(nonnull NSURLRequest *)request returningResponse:(NSURLResponse *_Nullable*_Nullable)response error:(NSError *_Nullable*_Nullable)error AndretryNumber:(NSInteger)retryNumber ;
@end

@interface NSMutableArray (Custom)
- (NSMutableArray *_Nullable)replaceNullsWithObject:(id _Nullable)object;
@end

@interface NSMutableDictionary (Custom)
- (NSMutableDictionary *_Nullable)replaceNullsWithObject:(id _Nullable)object;
@end


