//
//  Utility.m
//  AppVirality
//
//  Created by Ram on 11/04/15.
//  Copyright (c) 2015 AppVirality. All rights reserved.
//

#import "Utility.h"
#import "NSObject+BKBlockExecution.h"
#import <WebKit/WebKit.h>


@implementation Utility
NSTimeInterval const NSURLConnectionDefaultTimeInterval = 30.0;
NSString *const NSAppViralityErrorDomain = @"AppViralityError";
NSArray *codesArray;
static dispatch_once_t once;
static NSOperationQueue *connectionQueue;

+ (NSOperationQueue *)connectionQueue
{
    dispatch_once(&once, ^{
        connectionQueue = [[NSOperationQueue alloc] init];
        [connectionQueue setMaxConcurrentOperationCount:2];
        [connectionQueue setName:@"com.appvirality.connectionqueue"];
    });
    return connectionQueue;
}
+(BOOL)checkRequiredKeys:(NSArray*)requiredKeys WithGivenKeys:(NSArray*)givenKeys
{
    for (NSString * key in requiredKeys) {
        if (![givenKeys containsObject:key]) {
            NSLog(@"Please add the key \"%@\" in the params",key);
            return NO;
        }
    }
    return YES;
}

// Encode a string to embed in an URL.
+(NSString*)encodeToPercentEscapeString:(NSString *)string {
    return (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                              (CFStringRef) string,
                                                              NULL,
                                                              (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                                              kCFStringEncodingUTF8));
}

+ (NSString *)getAdvertiserID {
    NSString *uid = nil;
    
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        uid = [uuid UUIDString];
    }
    
    
    return uid;
}

+ (BOOL)adTrackingSafe {
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingEnabledSelector = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        BOOL enabled = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:advertisingEnabledSelector])(sharedManager, advertisingEnabledSelector);
        return enabled;
    }
    return YES;
}


// Decode a percent escape encoded string.
+(NSString*)decodeFromPercentEscapeString:(NSString *)string {
    string = [[string stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return string;
    /*return (NSString *)
    CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                              (CFStringRef) string,
                                                                              CFSTR(""),
                                                                              kCFStringEncodingUTF8));*/
}

+(NSString*)decodeFromTerms:(NSString *)string {
    string = [[string stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return string;
}


+ (NSString *)GetDeviceID {
    NSString *udidString;
    udidString = [self objectForKey:@"deviceID"];
    if(!udidString)
    {
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"AV_DeviceID"])
        {
            udidString = [[NSUserDefaults standardUserDefaults] valueForKey:@"AV_DeviceID"];
            [self setObject:udidString forKey:@"deviceID"];
            
        }
        else{
            CFUUIDRef cfuuid = CFUUIDCreate(kCFAllocatorDefault);
            udidString = (NSString*)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, cfuuid));
            CFRelease(cfuuid);
            [[NSUserDefaults standardUserDefaults] setValue:udidString forKey:@"AV_DeviceID"];
            [self setObject:udidString forKey:@"deviceID"];
        }
        
    }
    return udidString;
}

+ (NSString *)GetTempUserKey {
    NSString *tempUserKeyString;
    CFUUIDRef cfuuid = CFUUIDCreate(kCFAllocatorDefault);
    tempUserKeyString = (NSString*)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, cfuuid));
    CFRelease(cfuuid);
    return tempUserKeyString;
}

+(NSDictionary*)parseReferrerInfo:(NSDictionary*)referrerDetails
{
    NSMutableDictionary* newReferrerDetails = [NSMutableDictionary dictionaryWithDictionary:referrerDetails];
    [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"WelcomeMessage"]] forKeyPath:@"WelcomeMessage"];
    [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"FriendIncentiveDesc"]] forKeyPath:@"FriendIncentiveDesc"];
    [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"ReferrerName"]] forKeyPath:@"ReferrerName"];
    
    return newReferrerDetails;
    
}

+(NSDictionary*)parseReferrerInfov2:(NSDictionary*)referrerDetails
{
    NSMutableDictionary* newReferrerDetails = [NSMutableDictionary dictionaryWithDictionary:referrerDetails];
    if([newReferrerDetails objectForKey:@"welcomeMessage"]){
        [newReferrerDetails removeObjectForKey:@"welcomeMessage"];
        [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"welcomeMessage"]] forKeyPath:@"WelcomeMessage"];
    }
    if([newReferrerDetails objectForKey:@"referrerName"]){
        [newReferrerDetails removeObjectForKey:@"referrerName"];
        [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"referrerName"]] forKeyPath:@"ReferrerName"];
    }
    if([newReferrerDetails objectForKey:@"referrerCode"]){
        [newReferrerDetails removeObjectForKey:@"referrerCode"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"referrerCode"] forKeyPath:@"ReferrerCode"];
    }
    if([newReferrerDetails objectForKey:@"profileImage"]){
        [newReferrerDetails removeObjectForKey:@"profileImage"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"profileImage"] forKeyPath:@"ProfileImage"];
    }
    if([newReferrerDetails objectForKey:@"campaignBGColor"]){
        [newReferrerDetails removeObjectForKey:@"campaignBGColor"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"campaignBGColor"] forKeyPath:@"CampaignBGColor"];
    }
    if([newReferrerDetails objectForKey:@"friendIncentiveDesc"]){
        [newReferrerDetails removeObjectForKey:@"friendIncentiveDesc"];
        [newReferrerDetails setValue:[Utility decodeFromPercentEscapeString:[referrerDetails valueForKey:@"friendIncentiveDesc"]] forKeyPath:@"FriendIncentiveDesc"];
    }
    if([newReferrerDetails objectForKey:@"friendReward"]){
        [newReferrerDetails removeObjectForKey:@"friendReward"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"friendReward"] forKeyPath:@"FriendReward"];
    }
    if([newReferrerDetails objectForKey:@"friendRewardEvent"]){
        [newReferrerDetails removeObjectForKey:@"friendRewardEvent"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"friendRewardEvent"] forKeyPath:@"FriendRewardEvent"];
    }
    if([newReferrerDetails objectForKey:@"friendRewardUnit"]){
        [newReferrerDetails removeObjectForKey:@"friendRewardUnit"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"friendRewardUnit"] forKeyPath:@"FriendRewardUnit"];
    }
    if([newReferrerDetails objectForKey:@"offerDescriptionColor"]){
        [newReferrerDetails removeObjectForKey:@"offerDescriptionColor"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"offerDescriptionColor"] forKeyPath:@"OfferDescriptionColor"];
    }
    if([newReferrerDetails objectForKey:@"offerTitleColor"]){
        [newReferrerDetails removeObjectForKey:@"offerTitleColor"];
        [newReferrerDetails setValue:[referrerDetails valueForKey:@"offerTitleColor"] forKeyPath:@"OfferTitleColor"];
    }
    
    return newReferrerDetails;
    
}

+(NSDictionary*)parseCampaignInfo:(NSDictionary*)campaignInfo
{
    NSMutableDictionary * campaignDict = [NSMutableDictionary dictionary];
    for (NSString * key in [campaignInfo allKeys]) {
        if ([[campaignInfo valueForKey:key] isKindOfClass:[NSString class]]) {
            [campaignDict setValue:[self decodeFromPercentEscapeString:[campaignInfo valueForKey:key]] forKey:key];
        }else
            [campaignDict setValue:[campaignInfo valueForKey:key] forKey:key];
        
        if ([key isEqualToString:@"CampaignImage"]&&![[campaignInfo valueForKey:key] isEqualToString:@""]) {
            NSString * campaignImage = [NSString stringWithFormat:@"%@/Images/CampaignImage/%@",IMAGE_SERVER_URL,[campaignInfo valueForKey:key]];
            [campaignDict setValue:campaignImage forKey:key];
        }
        if ([key isEqualToString:@"CampaignBGImage"]&&![[campaignInfo valueForKey:key] isEqualToString:@""]) {
            NSString * campaignImage = [NSString stringWithFormat:@"%@/Images/GrowthHacksImages/%@",IMAGE_SERVER_URL,[campaignInfo valueForKey:key]];
            [campaignDict setValue:campaignImage forKey:key];
        }
        if ([key isEqualToString:@"referralcode"]&&![[campaignInfo valueForKey:key] isEqualToString:@""]) {
            [campaignDict setValue:[campaignInfo valueForKey:key] forKey:key];
        }
        
        
        if ([key isEqualToString:@"socialactions"]) {
            [campaignDict setValue:[NSString stringWithFormat:@"%@/%@",[[campaignInfo valueForKey:@"customdomain"] isEqualToString:@""]?SHARE_URL:[NSString stringWithFormat:@"http://%@",[campaignInfo valueForKey:@"customdomain"]],[campaignInfo valueForKey:@"shortcode"]] forKey:@"shareURL"];
            
            NSMutableArray * socialActions = [NSMutableArray array];
            for (NSDictionary * socialAction in [campaignInfo valueForKey:@"socialactions"]) {
                NSMutableDictionary * newSocialAction = [NSMutableDictionary dictionaryWithDictionary:socialAction];
                NSString *shareUrl = [NSString stringWithFormat:@"%@/%@/%@",[[campaignInfo valueForKey:@"customdomain"] isEqualToString:@""]?SHARE_URL:[NSString stringWithFormat:@"http://%@",[campaignInfo valueForKey:@"customdomain"]],[campaignInfo valueForKey:@"shortcode"],[socialAction valueForKey:@"socialActionId"]];
                [newSocialAction setValue:shareUrl forKey:@"shareUrl"];
                NSArray * socialKeys = @[@"campaignSocialActionId",@"displayOrder",@"shareImageUrl",@"shareMessage",@"shareTitle",@"shareUrl",@"socialActionId",@"socialActionName"];
                for (NSString * socialKey in [newSocialAction allKeys]) {
                    if ([[newSocialAction valueForKey:socialKey] isKindOfClass:[NSString class]]) {
                        [newSocialAction setValue:[self decodeFromTerms:[newSocialAction valueForKey:socialKey]] forKey:socialKey];
                    }
                    if (![socialKeys containsObject:socialKey]) {
                        [newSocialAction removeObjectForKey:socialKey];
                    }
                }
                if ([newSocialAction objectForKey:@"shareMessage"]) {
                    NSString * shareMessage = [newSocialAction valueForKey:@"shareMessage"];
                    shareMessage = [shareMessage stringByReplacingOccurrencesOfString:@"SHARE_URL" withString:shareUrl];
                    if (![[campaignInfo valueForKey:@"referralcode"] isEqualToString:@""]) {
                    shareMessage = [shareMessage stringByReplacingOccurrencesOfString:@"SHARE_CODE" withString:[campaignInfo valueForKey:@"referralcode"]];
                    }
                    [newSocialAction setValue:shareMessage forKey:@"shareMessage"];
                }
                [socialActions addObject:newSocialAction];
            }
            [campaignDict setValue:socialActions forKey:@"socialactions"];
        }
    }
    
    NSArray * keys = @[@"CampaignId",@"CampaignName",@"OfferTitle",@"OfferTitleColor",@"OfferDescription",@"OfferDescriptionColor",@"CampaignImage",@"CampaignBGImage",@"CampaignBGColor",@"LaunchMessage",@"LaunchButtonText",@"RemindButtonText",@"LaunchMsgColor",@"LaunchBGColor",@"LaunchButtonBGColor",@"EnableMini",@"EnablePopup",@"LaunchButtonTextColor",@"LaunchIconId",@"socialactions",@"shortcode",@"shareURL",@"referralcode"];
    
    for (NSString * campaignKey in [campaignDict allKeys]) {
        if (![keys containsObject:campaignKey]) {
            [campaignDict removeObjectForKey:campaignKey];
        }
    }
    
    return campaignDict;
}

+ (NSString *)GetUUID
{
    NSString *udidString;
    udidString = [self objectForKey:@"UUID"];
    if(!udidString)
    {
        CFUUIDRef theUUID = CFUUIDCreate(NULL);
        udidString = (NSString*)CFBridgingRelease(CFUUIDCreateString(NULL, theUUID));
        CFRelease(theUUID);
        [self setObject:udidString forKey:@"UUID"];
        
    }
    return udidString ;
}

+ (BOOL)isSimulator {
    UIDevice *currentDevice = [UIDevice currentDevice];
    return [currentDevice.model rangeOfString:@"Simulator"].location != NSNotFound;
}

+(void) setObject:(NSString*) object forKey:(NSString*) key
{
    NSString *objectString = object;
    NSError *error = nil;
    [SFHFKeychainUtils storeUsername:key
                         andPassword:objectString
                      forServiceName:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]?[[NSUserDefaults standardUserDefaults] valueForKey:@"AVapiKey"]:@"LIB"
                      updateExisting:YES
                               error:&error];
    
    if(error)
        NSLog(@"%@", [error localizedDescription]);
}

+(NSString*) objectForKey:(NSString*) key
{
    NSError *error = nil;
    NSString *object = [SFHFKeychainUtils getPasswordForUsername:key
                                                  andServiceName:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]?[[NSUserDefaults standardUserDefaults] valueForKey:@"AVapiKey"]:@"LIB"
                                                           error:&error];
    if(error)
        NSLog(@"%@", [error localizedDescription]);
    
    return object;
}

//+(nullable NSData *)sendSynchronousRequest:(nonnull NSURLRequest *)request returningResponse:(NSURLResponse *_Nullable*_Nullable)response error:(NSError *_Nullable*_Nullable)error AndretryNumber:(NSInteger)retryNumber {
//    NSData *data;
////#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
////    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
////    data = [session sendSynchronousDataTaskWithRequest:request returningResponse:response error:error];
////#else
//    data =  [NSURLConnection sendSynchronousRequest:request returningResponse:response error:error];
////#endif
//
//    NSInteger status = [(NSHTTPURLResponse *)*response statusCode];
//    BOOL isRetryableStatusCode = status >= 500;
//
//    // Retry the request if appropriate
//    if (retryNumber < 3 && isRetryableStatusCode) {
//        return [self sendSynchronousRequest:request returningResponse:response error:error AndretryNumber:(retryNumber+1)];
//    }
//
//    return data;
//}
+(nullable NSData *)sendSynchronousRequest:(nonnull NSURLRequest *)request
                         returningResponse:(NSURLResponse *_Nullable*_Nullable)response
                                     error:(NSError *_Nullable*_Nullable)error
                            AndretryNumber:(NSInteger)retryNumber
{
    // Prevent UI freeze
    if ([NSThread isMainThread]) {
        __block NSData *mainThreadData = nil;

        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            mainThreadData = [self sendSynchronousRequest:request returningResponse:response error:error AndretryNumber:retryNumber];
            dispatch_semaphore_signal(sema);
        });

        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        return mainThreadData;
    }

    __block NSData *responseData = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = NSURLConnectionDefaultTimeInterval;
    config.timeoutIntervalForResource = 2 * NSURLConnectionDefaultTimeInterval;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {

        if (response) *response = res;
        if (error) *error = err;
        responseData = data;

        NSInteger status = 0;
        if ([res isKindOfClass:[NSHTTPURLResponse class]]) {
            status = [(NSHTTPURLResponse *)res statusCode];
        }
        BOOL retryable = status >= 500;

        if (retryNumber < 3 && retryable) {
            responseData = [self sendSynchronousRequest:request returningResponse:response error:error AndretryNumber:(retryNumber+1)];
        }

        dispatch_semaphore_signal(sema);
    }];

    [task resume];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

    [session finishTasksAndInvalidate];
    return responseData;
}


+(void)genericHTTPRequest:(NSURLRequest *)request
              retryNumber:(NSInteger)retryNumber
                 callback:(void (^)(NSURLResponse* response, NSData* data, NSError* connectionError))callback
{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = NSURLConnectionDefaultTimeInterval;
    config.timeoutIntervalForResource = 2 * NSURLConnectionDefaultTimeInterval;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task =
    [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        NSInteger status = 0;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status = [(NSHTTPURLResponse *)response statusCode];
        }
        BOOL retryableStatus = status >= 500;

        // Retry on server error
        if (retryNumber < 3 && retryableStatus) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
                [self genericHTTPRequest:request retryNumber:retryNumber+1 callback:callback];
            });
            return;
        }

        // Retry on network errors
        if (error && [[self networkErrorCodes] containsObject:@(error.code)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
                [self genericHTTPRequest:request retryNumber:retryNumber+1 callback:callback];
            });
            return;
        }

        // Return response on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback) callback(response, data, error);
        });

    }];

    [task resume];
}


//+(void)genericHTTPRequest:(NSURLRequest *)request retryNumber:(NSInteger)retryNumber callback:(void (^)(NSURLResponse* response, NSData* data, NSError* connectionError))callback {
//#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
//    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
//
//    sessionConfig.timeoutIntervalForRequest = NSURLConnectionDefaultTimeInterval;
//    sessionConfig.timeoutIntervalForResource = 2*NSURLConnectionDefaultTimeInterval;
//    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
//    NSURLSessionDataTask *task = [session dataTaskWithRequest:request.copy completionHandler:^(NSData * _Nullable responseData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//#else
//        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
//#endif
//            NSInteger status = [(NSHTTPURLResponse *)response statusCode];
//            BOOL isRetryableStatusCode = status >= 500;
//
//            // Retry the request if appropriate
//            if (retryNumber < 3 && isRetryableStatusCode) {
//                dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, 0 * NSEC_PER_SEC);
//                dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
//                    DLog(@"Replaying request with url %@", request.URL.relativePath);
//
//                    // Create the next request
//                    [self genericHTTPRequest:request retryNumber:(retryNumber + 1) callback:callback];
//                });
//            }
//             else if (error) {
//                if ([[self networkErrorCodes] containsObject:[NSNumber
//                                                              numberWithInteger:[error code]]]){
//                    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, 0 * NSEC_PER_SEC);
//                    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
//                        DLog(@"Replaying request with url %@", request.URL.relativePath);
//
//                        // Create the next request
//                        [self genericHTTPRequest:request retryNumber:(retryNumber + 1) callback:callback];
//                    });
//
//                }
//            }
//             else if (callback) {
//                // Wrap up bad statuses w/ specific error messages
//                //            if (status >= 500) {
//                //                error = [NSError errorWithDomain:BNCErrorDomain code:BNCServerProblemError userInfo:@{ NSLocalizedDescriptionKey: @"Trouble reaching the servers, please try again shortly" }];
//                //            }
//                //            else if (status == 409) {
//                //                error = [NSError errorWithDomain:BNCErrorDomain code:BNCDuplicateResourceError userInfo:@{ NSLocalizedDescriptionKey: @"A resource with this identifier already exists" }];
//                //            }
//                //            else if (status >= 400) {
//                //                NSString *errorString = [serverResponse.data objectForKey:@"error"] ?: @"The request was invalid.";
//                //
//                //                error = [NSError errorWithDomain:BNCErrorDomain code:BNCBadRequestError userInfo:@{ NSLocalizedDescriptionKey: errorString }];
//                //            }
//
//
//#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    callback(response,responseData, error);
//                });
//            }
//        }];
//        [task resume];
//        [session finishTasksAndInvalidate];
//#else
//        callback(response,responseData, error);
//    }
//                                  }];
//#endif
//}

+(NSArray*)networkErrorCodes
{
//    static NSArray *codesArray;
    if (!codesArray && ![codesArray count]){
        const int codes[] = {
            //kCFURLErrorUnknown,     //-998
            //kCFURLErrorCancelled,   //-999
            //kCFURLErrorBadURL,      //-1000
            kCFURLErrorTimedOut,    //-1001
            //kCFURLErrorUnsupportedURL, //-1002
            //kCFURLErrorCannotFindHost, //-1003
            kCFURLErrorCannotConnectToHost,     //-1004
            kCFURLErrorNetworkConnectionLost,   //-1005
            kCFURLErrorDNSLookupFailed,         //-1006
            //kCFURLErrorHTTPTooManyRedirects,    //-1007
            kCFURLErrorResourceUnavailable,     //-1008
            kCFURLErrorNotConnectedToInternet,  //-1009
            //kCFURLErrorRedirectToNonExistentLocation,   //-1010
            kCFURLErrorBadServerResponse,               //-1011
            //kCFURLErrorUserCancelledAuthentication,     //-1012
            //kCFURLErrorUserAuthenticationRequired,      //-1013
            //kCFURLErrorZeroByteResource,        //-1014
            //kCFURLErrorCannotDecodeRawData,     //-1015
            //kCFURLErrorCannotDecodeContentData, //-1016
            //kCFURLErrorCannotParseResponse,     //-1017
            kCFURLErrorInternationalRoamingOff, //-1018
            kCFURLErrorCallIsActive,                //-1019
            //kCFURLErrorDataNotAllowed,              //-1020
            //kCFURLErrorRequestBodyStreamExhausted,  //-1021
            kCFURLErrorFileDoesNotExist,            //-1100
            //kCFURLErrorFileIsDirectory,             //-1101
            kCFURLErrorNoPermissionsToReadFile,     //-1102
            //kCFURLErrorDataLengthExceedsMaximum,     //-1103
            kCFNetServiceErrorTimeout
        };
        int size = sizeof(codes)/sizeof(int);
        NSMutableArray *array = [[NSMutableArray alloc] init];
        for (int i=0;i<size;++i){
            [array addObject:[NSNumber numberWithInt:codes[i]]];
        }
        codesArray = [array copy];
    }
    return codesArray;
}

+(void)userAgentStringWithCompletion:(void (^ _Nonnull)(NSString * _Nonnull agent))completion
{
    NSString *cachedAgent = [[NSUserDefaults standardUserDefaults] objectForKey:@"userAgent"];
    if (cachedAgent) {
        if (completion) completion(cachedAgent);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        __block WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];

        [webView evaluateJavaScript:@"navigator.userAgent"
                  completionHandler:^(id result, NSError *error) {

            NSString *secretAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X)";

            if (!error && [result isKindOfClass:[NSString class]]) {
                secretAgent = (NSString *)result;
                [[NSUserDefaults standardUserDefaults] setObject:secretAgent forKey:@"userAgent"];
            }

            if (completion) completion(secretAgent);

            // REAL release
            webView = nil;
        }];
    });
}

+(NSString*)userAgentString
{
    NSString *cachedAgent = [[NSUserDefaults standardUserDefaults] objectForKey:@"userAgent"];
    if (cachedAgent) return cachedAgent;

    __block NSString *agent = @"Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X)";
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    [self userAgentStringWithCompletion:^(NSString * _Nonnull ua) {
        agent = ua;
        dispatch_semaphore_signal(sema);
    }];

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return agent;
}


@end


@implementation NSArray (Custom)

- (NSMutableArray *)replaceNullsWithObject:(id)object
{
    NSMutableArray *tmp_array = [self mutableCopy];
    unsigned long count = tmp_array.count;
    for (int i = 0; i < count; ++i)
    {
        id tmp = [tmp_array objectAtIndex:i];
        if ([tmp isKindOfClass:[NSArray class]])
        {
            tmp = [tmp replaceNullsWithObject:object];
            [tmp_array replaceObjectAtIndex:i withObject:tmp];
        }
        else if ([tmp isKindOfClass:[NSDictionary class]])
        {
            tmp = [tmp replaceNullsWithObject:object];
            [tmp_array replaceObjectAtIndex:i withObject:tmp];
        }
        else if ([tmp isEqual:[NSNull null]])
        {
            [tmp_array replaceObjectAtIndex:i withObject:object];
        }
    }
    return tmp_array;
}

@end


@implementation NSDictionary (Custom)

- (NSMutableDictionary *)replaceNullsWithObject:(id)object
{
    NSMutableDictionary *tmp_dict = [self mutableCopy];
    for (NSString *key in [tmp_dict allKeys])
    {
        id tmp = [tmp_dict objectForKey:key];
        if ([tmp isKindOfClass:[NSArray class]])
        {
            tmp = [tmp replaceNullsWithObject:object];
            [tmp_dict setObject:tmp forKey:key];
        }
        else if ([tmp isKindOfClass:[NSDictionary class]])
        {
            tmp = [tmp replaceNullsWithObject:object];
            [tmp_dict setObject:tmp forKey:key];
        }
        else if ([tmp isEqual:[NSNull null]])
        {
            [tmp_dict setObject:object forKey:key];
        }
    }
    return tmp_dict;
}

@end


