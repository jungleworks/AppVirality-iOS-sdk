//
//  AppVirality.m
//  AppViralityToolKit
//
//  Created by Ram on 14/04/15.
//  Copyright (c) 2015 AppVirality. All rights reserved.
//

#import "AppVirality.h"
#import "Utility.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
@import SafariServices;
#import <SafariServices/SafariServices.h>
#endif

static BOOL debug;
static BOOL isInitialising;
static BOOL cookieBasedAttribution;
static BOOL isCookieAttributionCompleted;
static BOOL initWithEmail;
static NSString* tempUserKey;
static NSDictionary* _Nullable userDetailsforInit = nil;

//@interface AppVirality2 : NSObject <SFSafariViewControllerDelegate>
//
//@end
//
//@implementation AppVirality2
//
//- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
//    NSLog(@"Safari Did load. Success: %d.", didLoadSuccessfully);   //  eDebug
//}
//@end

@implementation AppVirality



+(void)init
{
    TCSTART
    NSDictionary *dictRoot = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"]];
    [self initWithApiKey:[dictRoot valueForKey:@"AppViralityAppKey"] WithParams:nil OnCompletion:^(NSDictionary *referrerDetails,NSError *error) {
        
    }];
    TCEND
    
}

+(void)checkAttribution:(NSString *)apiKey withReferrerCode:(NSString*)referrerCode OnCompletion:(void (^)(NSDictionary *, NSError *))completion
{
    TCSTART
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        if(!apiKey.length){
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"AppVirality Appkey not found", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please provide Appkey", nil)
                                       };
            NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                                 code:-57
                                             userInfo:userInfo];
            completion(nil,error);
            return;
        }
        
        NSDictionary * args = [NSDictionary dictionaryWithObjectsAndKeys:
                               referrerCode ? referrerCode : @"", @"referrercode",
                               apiKey, @"apikey", nil];
        [self performSelectorInBackground:@selector(checkRIForAttributionStatus:) withObject:args];
        
        __block BOOL  dataExists = FALSE;
        
        [[NSNotificationCenter defaultCenter] addObserverForName:@"AV_AttributionDetails" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            if (dataExists) {
                return ;
            }else
                dataExists = TRUE;
            
            [[NSNotificationCenter defaultCenter]removeObserver:self name:@"AV_AttributionDetails" object:nil];
            
            NSError * error;
            NSDictionary * referrerDetails;
            if (note != nil)
            {
                TCSTART
                error =[note valueForKeyPath:@"userInfo.errorInfo"];
                referrerDetails = [note valueForKeyPath:@"userInfo.result"];
                TCEND
            }
            
            if (referrerDetails) {
                if ([[NSUserDefaults standardUserDefaults] valueForKey:@"AV_isExistingUser"] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AV_isExistingUser"] boolValue]) {
                    
                    [referrerDetails setValue:@"True" forKey:@"isExistingUser"];
                }
                completion([Utility parseReferrerInfov2:referrerDetails],error);
                return ;
            }
            else {
                completion(nil,error);
                return;
            }
        }];
        
    }
    else{
        //return referrer details
        NSMutableDictionary * referrerDetails = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"AV_ReferrerDetails"] mutableCopy];
        if (referrerDetails) {
            if ([[NSUserDefaults standardUserDefaults] valueForKey:@"AV_isExistingUser"] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"AV_isExistingUser"] boolValue]) {
                [referrerDetails setValue:@"True" forKey:@"isExistingUser"];
            }
            completion([Utility parseReferrerInfo:referrerDetails], nil);
            return ;
        }
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"no referrer details found", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Either AppVirality SDK initialization is in progress or no referrer details found", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please retry", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(nil, error);
        return ;

    }
    TCEND
    
}


+ (void)showGrowthHack:(GrowthHackType)growthHack  FromViewController:(UIViewController*)viewController completion:(void (^)(NSDictionary* campaignDetails,NSError *error))completion
{
    [self getGrowthHack:growthHack completion:^(NSDictionary *campaignDetails,NSError *error) {
        
    }];
}
+ (void)showLaunchBar:(GrowthHackType)growthHack  FromViewController:(UIViewController*)viewController completion:(void (^)(NSDictionary* campaignDetails,NSError *error))completion
{
    [self getGrowthHack:growthHack completion:^(NSDictionary *campaignDetails,NSError *error) {
        
    }];
}
+ (void)showLaunchPopup:(GrowthHackType)growthHack  FromViewController:(UIViewController*)viewController completion:(void (^)(NSDictionary* campaignDetails,NSError *error))completion
{
    [self getGrowthHack:growthHack completion:^(NSDictionary *campaignDetails,NSError *error) {
        
    }];
}
+ (void)initWithApiKey:(NSString *)apiKey WithParams:(NSDictionary*)userDetails OnCompletion:(void(^)(NSDictionary * referrerDetails,NSError *error))completion
{
    TCSTART
    
    userDetailsforInit = userDetails;
    if (initWithEmail && (userDetailsforInit == nil || [userDetailsforInit valueForKey:@"EmailId"] ==nil) ) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"EmailId is missing", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with Email.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(nil,error);
        return;
    }
    NSString * storedKey =  [[NSUserDefaults standardUserDefaults] valueForKey:@"AVapiKey"];
    
    if (![storedKey isEqualToString:apiKey])
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"userkey"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"campaignData"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentcampaigns"];
    }
    
    
    [[NSUserDefaults standardUserDefaults] setValue:apiKey forKey:@"AVapiKey"];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"firstLaunch"]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"firstLaunch"];
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"numberOfLaunches"]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:1] forKey:@"numberOfLaunches"];
    }else
    {
        NSInteger numberOfLaunches = [[[NSUserDefaults standardUserDefaults] valueForKey:@"numberOfLaunches"] integerValue]+1;
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:numberOfLaunches] forKey:@"numberOfLaunches"];
        
    }
    // [self checkRI:apiKey];
    [Utility userAgentString];
    [self performSelectorInBackground:@selector(checkRI:) withObject:apiKey];
    
    __block BOOL  dataExists = FALSE;
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"referrerDetails" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (dataExists) {
            return ;
        }else
            dataExists = TRUE;
        
        [[NSNotificationCenter defaultCenter]removeObserver:self name:@"referrerDetails" object:nil];
        NSString * userKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]?[[NSUserDefaults standardUserDefaults]valueForKey:@"userkey"]:@"";
        
        NSString * hasReferrer = [[NSUserDefaults standardUserDefaults] objectForKey:@"hasReferrer"]?[[NSUserDefaults standardUserDefaults] valueForKey:@"hasReferrer"]:@"";
        
        NSString * referrerCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"AV_ReferrerCode"]?[[NSUserDefaults standardUserDefaults] valueForKey:@"AV_ReferrerCode"]:@"";
        
        
        
        NSError * error;
        if (note != nil)
        {
            error =[note valueForKeyPath:@"userInfo.errorInfo"];
        }
        
        NSDictionary * referrerDetails = @{@"userkey":userKey, @"hasReferrer":hasReferrer,@"referrerCode":referrerCode};
        if (referrerDetails) {
            completion(referrerDetails,error);
            return ;
        }
        else {
            completion(nil,error);
            return;
        }
    }];
    TCEND
}

+(BOOL)isDebug
{
    TCSTART
    NSDictionary *dictRoot = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"]];
    if ([dictRoot objectForKey:DEBUGKEY]) {
        debug=[[dictRoot valueForKey:DEBUGKEY] boolValue];
    }else
        debug = FALSE;
    
    return debug;
    TCEND
}

+ (void)registerAsDebugDevice:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    if (![self isDebug]) {
        completion(NO,nil);
        return;
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(NO,error);
        return;
        
//        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
//            completion(NO,error);
//            return;
//        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        completion(NO,error);
        return;
        
//        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
//            completion(NO,error);
//            return;
//        }
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/debugregister",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    [userDictionary setValue:[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString] forKey:@"deviceId"];
    
    DLog(@"register debug device  request %@ %@",[NSString stringWithFormat:@"%@/debugregister",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             //                DLog(@"social response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 DLog(@"register debug response %@",response);
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
     }];
    TCEND
    
}

+ (void)checkReferrerRewards:(void (^)(NSDictionary *rewards,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/claimreferrerreward",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"check referrer rewards request %@ %@",[NSString stringWithFormat:@"%@/claimreferrerreward",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             //                DLog(@"social response %@",response);
             
             DLog(@"check referrer rewards response %@",response);
             completion(response,connectionError);
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    TCEND
    
}

+ (void)getUserRewards:(void (^)(NSDictionary *rewards,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getuserrewards",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"get user rewards request %@ %@",[NSString stringWithFormat:@"%@/getuserrewards",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             //                DLog(@"social response %@",response);
             
             DLog(@"get user rewards response %@",response);
             completion(response,connectionError);
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    TCEND
    
}

+ (void)getUserCoupons:(void (^)(NSDictionary *coupons,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getusercoupons",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"get user rewards request %@ %@",[NSString stringWithFormat:@"%@/getuserrewards",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             //                DLog(@"social response %@",response);
             
             DLog(@"get user rewards response %@",response);
             completion(response,connectionError);
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    TCEND
    
}
+ (void)recordSocialActionForGrowthHack:(GrowthHackType)growthHackIndex WithParams:(NSDictionary*)actionParams  completion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0 ;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if (campaignId==0) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No active campaigns found for this growth hack.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        //  DLog(@"No active campaigns found for this growth hack.");
        completion(NO,error);
        return;
    }
    
    if (![Utility checkRequiredKeys:@[@"shareMessage",@"socialActionId"] WithGivenKeys:[actionParams allKeys]]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Missing one or all of the required keys shareMessage/socialActionId.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        
        completion(NO,error);
        return;
    }
    
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd'T'HHmmssSSS"];
    NSDate *now = [[NSDate alloc] init];
    NSString *dateString = [format stringFromDate:now];
    NSString * socialActionString = [@"socialAction" stringByAppendingString:dateString];
    [self addSocialActionEventToQueue:socialActionString WithEventDetails:actionParams AndGrowthHack:growthHackIndex];
    
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/recordsocialactions",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:actionParams];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    [userDictionary setValue:[NSString stringWithFormat:@"%ld",(long)campaignId] forKey:@"campaignid"];
    if ([userDictionary objectForKey:@"shareMessage"]) {
        [userDictionary setValue:[Utility  encodeToPercentEscapeString:[userDictionary objectForKey:@"shareMessage"]] forKey:@"shareMessage"];
    }
    
    DLog(@"record social  request %@ %@",[NSString stringWithFormat:@"%@/recordsocialactions",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             if (response) {
                 [self removeSocialActionEventFromQueue:socialActionString];
                 
                 DLog(@"record social response %@",response);
                 
                 if ([response objectForKey:@"success"]) {
                     completion([[response valueForKey:@"success"] boolValue],connectionError);
                     return;
                 }
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
     }];
    
    TCEND
}

+ (void)recordImpressionsForGrowthHack:(GrowthHackType)growthHackIndex WithParams:(NSDictionary*)actionParams  completion:(void (^)(NSDictionary* response,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0 ;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if (campaignId==0) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No active campaigns found for this growth hack.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please Add some active campaigns.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        //  DLog(@"No active campaigns found for this growth hack.");
        completion(nil,error);
        return;
    }
    
    
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd'T'HHmmssSSS"];
    NSDate *now = [[NSDate alloc] init];
    NSString *dateString = [format stringFromDate:now];
    NSString * socialActionString = [@"socialAction" stringByAppendingString:dateString];
    [self addSocialActionEventToQueue:socialActionString WithEventDetails:actionParams AndGrowthHack:growthHackIndex];
    
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/recordimpressionsclicks",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:actionParams];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    [userDictionary setValue:[NSString stringWithFormat:@"%ld",(long)campaignId] forKey:@"CampaignId"];
    
    DLog(@"record impressions  request %@ %@",[NSString stringWithFormat:@"%@/recordimpressionsclicks",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             [self removeSocialActionEventFromQueue:socialActionString];
             DLog(@"record impressions response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 completion(response,connectionError);
                 return;
             }else
             {
                 completion(nil,connectionError);
                 return;
             }
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    
    TCEND
}




+ (void)setUserDetails:(NSDictionary*)userDetails Oncompletion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        DLog(@"Please initialize the SDK with a valid API Key.");
        //   completion(NO);
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            //    completion(NO);
            DLog(@"There are no active campaigns for this app.");
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI Check failed.", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                       };
            NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                                 code:-57
                                             userInfo:userInfo];
            completion(NO,error);
            return;
        }
    }
    
    NSDictionary * storedDetails =  [[NSUserDefaults standardUserDefaults] valueForKey:@"AVUserDetails"];
    
    if ([storedDetails isEqualToDictionary:userDetails])
    {
        
        completion(YES,nil);
        return;
    }
    
    if (!storedDetails) {
        [[NSUserDefaults standardUserDefaults] setValue:userDetails forKey:@"AVUserDetails"];
    }

    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd'T'HHmmssSSS"];
    NSDate *now = [[NSDate alloc] init];
    NSString *dateString = [format stringFromDate:now];
    NSString * userDetailsKey = [@"user" stringByAppendingString:dateString];
    
    [self addUserDetailsToQueue:userDetailsKey WithUserDetails:userDetails];

    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AVUserDetails"];

        //    completion(NO);
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Operation Queued.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(NO,error);

        return;
    }
    
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/updateappuserinfo",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:userDetails];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    if ([userDictionary objectForKey:@"AppUserName"]) {
        [userDictionary setValue:[Utility  encodeToPercentEscapeString:[userDictionary objectForKey:@"AppUserName"]] forKey:@"AppUserName"];
    }
    
    DLog(@"user details  request %@ %@",[NSString stringWithFormat:@"%@/updateappuserinfo",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             if(response)
                 [self removeUserDetailsFromQueue:userDetailsKey];
             else
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AVUserDetails"];

             DLog(@"user details response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AVUserDetails"];
             completion(NO,connectionError);
             return;
         }
     }];
    TCEND
}

+ (void)getUserBalance:(GrowthHackType)growthHackIndex  completion:(void (^)(NSDictionary* userInfo,NSError *error))completion
{
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0 ;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if (campaignId==0 && ![growthHack isEqualToString:@"All"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No active campaigns found for this growth hack.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        //DLog(@"No active campaigns found for this growth hack.");
        completion(nil,error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getuserdata",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    if(campaignId !=0)
    [userDictionary setValue:[NSString stringWithFormat:@"%ld",(long)campaignId] forKey:@"campaignid"];
    
    DLog(@"user balance  request %@ %@",[NSString stringWithFormat:@"%@/getuserdata",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"user balance response %@",response);
             
             if (response) {
                 NSMutableDictionary *userBalance  = [NSMutableDictionary dictionaryWithDictionary:response];
                 if ([userBalance objectForKey:@"userpoints"]) {
                     NSArray * userPoints = [userBalance valueForKey:@"userpoints"];
                     NSMutableArray * newuserPoints = [NSMutableArray array];
                     
                     if (![userPoints isEqual:[NSNull null]]&&(userPoints.count>0)) {
                         for (NSDictionary * userPoint in userPoints) {
                             NSMutableDictionary * newUserPoint = [NSMutableDictionary dictionaryWithDictionary:userPoint];
                             if (![[userPoint objectForKey:@"rewardtype"] isEqual:[NSNull null]]) {
                                 [newUserPoint setValue:[Utility decodeFromPercentEscapeString:[userPoint valueForKey:@"rewardtype"]] forKeyPath:@"rewardtype"];
                             }
                             [newuserPoints addObject:newUserPoint];
                         }
                     }
                     
                     [userBalance setValue:newuserPoints forKeyPath:@"userpoints"];
                 }
                 if ([userBalance objectForKey:@"referredusers"]) {
                     NSArray * referredusers = [userBalance valueForKey:@"referredusers"];
                     NSMutableArray * newreferredusers = [NSMutableArray array];
                     if (![referredusers isEqual:[NSNull null]]&& (referredusers.count>0)) {
                         for (NSDictionary * referreduser in referredusers) {
                             NSMutableDictionary * newReferreduser = [NSMutableDictionary dictionaryWithDictionary:referreduser];
                             if (![[referreduser objectForKey:@"name"] isEqual:[NSNull null]]) {
                                 [newReferreduser setValue:[Utility decodeFromPercentEscapeString:[referreduser valueForKey:@"name"]] forKeyPath:@"name"];
                             }
                             [newreferredusers addObject:newReferreduser];
                         }
                     }
                     
                     [userBalance setValue:newreferredusers forKeyPath:@"referredusers"];
                 }
                 completion(userBalance,connectionError);
                 return;
             }else
             {
                 completion(nil,connectionError);
                 return;
             }
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    
    TCEND
}

+ (void)getUserBalanceV2:(GrowthHackType)growthHackIndex  completion:(void (^)(NSDictionary* userInfo,NSError *error))completion
{
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0 ;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if (campaignId==0 && ![growthHack isEqualToString:@"All"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No active campaigns found for this growth hack.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        //DLog(@"No active campaigns found for this growth hack.");
        completion(nil,error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getuserbalance/%@",SERVER_URL_V21,[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    if(campaignId!=0)
    [userDictionary setValue:[NSString stringWithFormat:@"%ld",(long)campaignId] forKey:@"campaignid"];
    
    DLog(@"user balance  request %@ %@",[NSString stringWithFormat:@"%@/getuserbalance",SERVER_URL_V2],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forHTTPHeaderField:@"avsdk-clientkey"];

    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"user balance response %@",response);
             
             if (response) {
                 NSMutableDictionary *userBalance  = [NSMutableDictionary dictionaryWithDictionary:response];
                 completion(userBalance,connectionError);
                 return;
             }else
             {
                 completion(nil,connectionError);
                 return;
             }
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    
    TCEND
}


+(void)setCustomURL:(NSString*)customUrl  completion:(void (^)(BOOL success,NSError *error))completion
{
    
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/setcustomurl",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithObject:customUrl forKey:@"customUrlTag"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"custom url  request %@ %@",[NSString stringWithFormat:@"%@/setcustomurl",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"custom url response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
     }];
    TCEND
    
    
}

+ (void)setUserLocation:(NSDictionary*)userDetails  completion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/updateuserlocationinfo",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:userDetails];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"user location request %@ %@",[NSString stringWithFormat:@"%@/updateuserlocationinfo",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"user location response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
         
     }];
    TCEND
    
}

+(void)logout
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"userkey"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"hasReferrer"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"socialActionQueue"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"convQueue"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"userDetailsQueue"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentcampaigns"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"campaignData"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"firstLaunch"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"numberOfLaunches"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AVUserDetails"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AV_ReferrerCode"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AV_ReferrerDetails"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AV_isExistingUser"];

    userDetailsforInit = nil;
    tempUserKey = nil;

    
}

+ (void)redeemRewards:(NSArray*)rewards  completion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/redeemrewards",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithObject:rewards forKey:@"rewards"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"redeem rewards request %@ %@",[NSString stringWithFormat:@"%@/updateuserlocationinfo",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"redeem rewards response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
     }];
    TCEND
    
}


+(void)getTerms:(GrowthHackType)growthHackIndex  completion:(void (^)(NSDictionary* terms,NSError *error))completion
{
    
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0 ;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if (campaignId==0) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No active campaigns found for this growth hack.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        // DLog(@"No active campaigns found for this growth hack.");
        completion(nil,error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/campaignterms",SERVER_URL]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionary];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    [userDictionary setValue:[NSString stringWithFormat:@"%ld",(long)campaignId] forKey:@"campaignid"];
    
    DLog(@"get terms request %@ %@",[NSString stringWithFormat:@"%@/campaignterms",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"get terms response %@",response);
             
             if (response) {
                 NSMutableDictionary *campaignTerms  = [NSMutableDictionary dictionaryWithDictionary:response];
                 if ([campaignTerms objectForKey:@"message"]) {
                     [campaignTerms setValue:[Utility decodeFromTerms:[campaignTerms valueForKey:@"message"]] forKeyPath:@"message"];
                 }
                 completion(campaignTerms,connectionError);
                 return;
             }else
             {
                 completion(nil,connectionError);
                 return;
             }
         }else
         {
             completion(nil,connectionError);
             return;
         }
     }];
    
    TCEND
    
}


+ (void)saveConversionEvent:(NSDictionary*)eventDetails  completion:(void (^)(NSDictionary* conversionResult,NSError *error))completion
{
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    __block BOOL  dataExists = FALSE;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        [self registerConversionEventWithApiKey:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] ForEvent:eventDetails OnInstall:NO];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"conversionResult" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            if (dataExists) {
                return ;
            }else
                dataExists = TRUE;
            
            completion([note valueForKeyPath:@"userInfo.result"],nil);
            return ;
        }];
        
    }
    completion(nil,nil);
    return;
    TCEND
}

+(void)getReferrerDetails:(void(^)(NSDictionary * referrerDetails,NSError *error))completion
{
    
    TCSTART
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"hasReferrer"]) {
        if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"hasReferrer"] boolValue]) {
            completion(nil,nil);
            return;
        }
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"AV_ReferrerDetails"]) {
        NSDictionary * referrerDetails = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"AV_ReferrerDetails"];
        if (referrerDetails != nil) {
            completion([Utility  parseReferrerInfo:referrerDetails],nil);
            return ;
        }

    }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"referrerDetails" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSError * error =[note valueForKeyPath:@"userInfo.errorInfo"];
        
        NSDictionary * referrerDetails = [note valueForKeyPath:@"userInfo.referrerDetails"];
        if (referrerDetails) {
            completion([Utility  parseReferrerInfo:referrerDetails],error);
            return ;
        }
        else {
            completion(nil,error);
            return;
        }
    }];
    TCEND
}

+(void)getReferrerDetailsDirect:(void(^)(NSDictionary * referrerDetails,NSError *error))completion
{
    
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getreferrerdetails",SERVER_URL]];
    NSError *error = nil;
    
    
    
    NSMutableDictionary * userDictionary =[NSMutableDictionary dictionaryWithDictionary:@{@"apikey":[[NSUserDefaults standardUserDefaults]objectForKey:@"AVapiKey"],
                                                                                          @"userkey":[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"],
                                                                                          }];
    
    DLog(@"register user request %@ %@",[NSString stringWithFormat:@"%@/getreferrerdetails",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"getReferrerDetails Response %@",response);
             
             if (response && (![[response valueForKey:@"userkey"] isEqual:[NSNull null]])) {
                 
                 
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"userkey"] forKey:@"userkey"];
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"hasReferrer"] forKey:@"hasReferrer"];
                 id referrerDetails = nil;
                 
                 if ([[response valueForKey:@"hasReferrer"] boolValue]) {
                     
                     if ([response valueForKey:@"ReferrerCode"]) {
                         referrerDetails =[(id)response replaceNullsWithObject:@""];
                     }
                 }
                 
                 if (referrerDetails) {
                     completion([Utility  parseReferrerInfo:referrerDetails],error);
                     return ;
                 }
                 else {
                     completion(nil,error);
                     return;
                 }
                 
             }
         }else if(connectionError)
         {
             completion(nil,connectionError);
             return;
             
         }else
         {
             completion(nil,error);
             return;
         }
         
     }];

    
    TCEND
}

+(void)attributeUserBasedonCookie:(NSString *)apiKey OnCompletion:(void(^)(BOOL success,NSError *error))completion
{
    
    TCSTART
    cookieBasedAttribution = YES;
    isInitialising = TRUE;
    if (!apiKey.length) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        isInitialising = FALSE;
        completion(NO,error);
        return;
    }
    
    if(isCookieAttributionCompleted)
    {
        cookieBasedAttribution = NO;
    }

    
    //check the device OS version & check for cookie based attribution enabled
    if ([[UIDevice currentDevice] systemVersion].integerValue >= 9 && cookieBasedAttribution && ![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        
        NSString * storedKey =  [[NSUserDefaults standardUserDefaults] valueForKey:@"AVapiKey"];
        
        if (![storedKey isEqualToString:apiKey])
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"userkey"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"campaignData"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentcampaigns"];
            
            [[NSUserDefaults standardUserDefaults] setValue:apiKey forKey:@"AVapiKey"];

        }
        
        

    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
        //Hack to invoke SFSafariViewController from NSClassFromString
        Class myClass =[SFSafariViewController class];
        myClass = nil;
    #endif
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"doneCookieBasedAttribution" object:nil];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"doneCookieBasedAttribution" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        isCookieAttributionCompleted = YES;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"doneCookieBasedAttribution" object:nil];
        isInitialising = FALSE;
        completion([[note valueForKeyPath:@"userInfo.cookieAttributionAttempt"] boolValue],nil);
        return;

    }];
        [self performSelectorInBackground:@selector(attributeBasedonCookie:) withObject:apiKey];

        //[self attributeBasedonCookie:apiKey];
    }
    else{
        isInitialising = FALSE;
        completion(NO,nil);
        return;

    }
    
    TCEND
}

+ (void)getGrowthHack:(GrowthHackType)growthHackIndex  completion:(void (^)(NSDictionary* campaignDetails,NSError *error))completion
{
    TCSTART
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(nil,error);
        return;
    }
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(nil,error);
            return;
        }
    }
    
    NSArray * growthHacks = @[@"Word_of_Mouth",@"Customer_Retention",@"Loyalty_Program",@"All"];
    NSString * growthHack = [growthHacks objectAtIndex:growthHackIndex];
    __block  NSInteger campaignId = 0;
    __block BOOL  dataExists = FALSE;
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
            }
        }
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"campaignData"]) {
        dataExists = TRUE;
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No Campaign Data found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        for (NSDictionary * campaignInfo in [[NSUserDefaults standardUserDefaults] valueForKey:@"campaignData"]) {
            DLog(@"%@",[[NSUserDefaults standardUserDefaults] objectForKey:@"campaignData"]);
            
            if ([[campaignInfo valueForKey:@"CampaignId"] integerValue]==campaignId) {
                
                if (campaignInfo) {
                    completion([Utility parseCampaignInfo:campaignInfo],nil);
                }else
                    completion(nil,nil);
                return;
            }
        }
        completion(nil,error);
        return;
    }
    if (!isInitialising) {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]&&[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"])
        {
            [self getCampaings:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];
        }
        else{
            completion(nil,nil);
            return;

        }
    }
    
 __block id observer =    [[NSNotificationCenter defaultCenter] addObserverForName:@"campaignDetails" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
//        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"campaignDetails" object:nil];
     [[NSNotificationCenter defaultCenter] removeObserver:observer];
        if (dataExists) {
            return ;
        }
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No Campaign Data found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
            
            for (NSDictionary * campaign in [[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
                if ([[campaign valueForKey:@"growthhacktype"] isEqualToString:growthHack]) {
                    campaignId = [[campaign valueForKey:@"campaignid"] integerValue];
                }
            }
        }else
        {
            completion(nil,error);
            return;
            
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"campaignData"]) {
            for (NSDictionary * campaignInfo in [[NSUserDefaults standardUserDefaults] valueForKey:@"campaignData"]) {
                if ([[campaignInfo valueForKey:@"CampaignId"] integerValue]==campaignId) {
                    
                    if (campaignInfo) {
                        completion([Utility parseCampaignInfo:campaignInfo],nil);
                    }else
                        completion(nil,nil);
                    return;
                }
            }
        }
        completion(nil,error);
        return;
        
    }];
    
    TCEND
}

+(void)checkRIForAttributionStatus:(NSDictionary *)args
{
    TCSTART
    NSString *apiKey = [args objectForKey:@"apikey"];
    NSString *referrerCode = [args objectForKey:@"referrercode"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",RI_URL,apiKey]];
    NSURLResponse * response;
    NSError * error;
    DLog(@"check RI request %@",[NSString stringWithFormat:@"%@/%@",RI_URL,apiKey]);
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"GET"];
    NSData * data =  [Utility sendSynchronousRequest:request returningResponse:&response error:&error AndretryNumber:0];
    if (data.length > 0 && error == nil)
    {
        NSDictionary *responseString = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:NULL];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if ([response respondsToSelector:@selector(allHeaderFields)]) {
            NSDictionary *dictionary = [httpResponse allHeaderFields];
            if([dictionary objectForKey:@"x-version-av1.1"])
                [[NSUserDefaults standardUserDefaults] setValue:[dictionary valueForKey:@"x-version-av1.1"] forKey:@"x-version-av1.1"];
            else
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"x-version-av1.1"];
        }
        DLog(@"check RI response  %@",responseString);
        
        if ([responseString objectForKey:@"success"]&&[[responseString valueForKey:@"success"] boolValue]&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
            [self checkAttributionStatus:apiKey withReferrerCode:referrerCode];
        }else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil userInfo:@{@"result":[[NSUserDefaults standardUserDefaults] objectForKey:@"AV_ReferrerDetails"]}];
        }else{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil];
        }
        
    }else{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil];
    }
    TCEND
}

+(void)checkAttributionStatus:(NSString*)apiKey withReferrerCode:(NSString*)referrerCode
{
    TCSTART
    NSURL *url;
    NSError *error = nil;
    NSString *adId = [Utility getAdvertiserID];
    
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:@{@"apikey":apiKey,
                                                                                          @"deviceId":[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString],
                                                                                          @"DeviceModel":[UIDevice currentDevice].model,
                                                                                          @"OSVersion":[UIDevice currentDevice].systemVersion,
                                                                                          @"DeviceOSName":@"iOS",
                                                                                          @"UserAgent":[Utility userAgentString],
                                                                                          @"referrerCode":referrerCode
                                                                                              }];
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/checkforattribution/%@",SERVER_URL_V21,apiKey]];
    
    if (adId) {
        [userDictionary setValue:adId forKey:@"AdvertiserId"];
    }
    
    DLog(@"checkforattribution request %@ %@",[NSString stringWithFormat:@"%@/checkforattribution/%@",SERVER_URL_V21,apiKey],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:apiKey forHTTPHeaderField:@"avsdk-clientkey"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"register user response %@",response);
             
             if (response) {
                 id referrerDetails = nil;
                 referrerDetails =[(id)response replaceNullsWithObject:@""];
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil userInfo:@{@"result":referrerDetails}];

             }
             else{
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil];
             }
             
         }else
         {
             if(connectionError)
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil userInfo:[NSDictionary dictionaryWithObject:connectionError forKey:@"errorInfo"]];
             else
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"AV_AttributionDetails" object:nil];
         }
     }];
    TCEND
}


+(BOOL)checkRI:(NSString*)apiKey
{
    TCSTART
    BOOL success = FALSE;
    isInitialising = TRUE;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",RI_URL,apiKey]];
    NSURLResponse * response;
    NSError * error;
    DLog(@"check RI request %@",[NSString stringWithFormat:@"%@/%@",RI_URL,apiKey]);
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"GET"];
    NSData * data =  [Utility sendSynchronousRequest:request returningResponse:&response error:&error AndretryNumber:0];
    if (data.length > 0 && error == nil)
    {
        NSDictionary *responseString = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:NULL];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if ([response respondsToSelector:@selector(allHeaderFields)]) {
            NSDictionary *dictionary = [httpResponse allHeaderFields];
            //    DLog(@"%d",[httpResponse statusCode]);
            if([dictionary objectForKey:@"x-version-av1.1"])
            [[NSUserDefaults standardUserDefaults] setValue:[dictionary valueForKey:@"x-version-av1.1"] forKey:@"x-version-av1.1"];
            else
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"x-version-av1.1"];
        }
        DLog(@"check RI response  %@",responseString);
        if ([responseString objectForKey:@"success"]&&[[responseString valueForKey:@"success"] boolValue])
            success = TRUE;
        
        if ([responseString objectForKey:@"success"]&&[[responseString valueForKey:@"success"] boolValue]&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
            [self registerUser:apiKey];
        }else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil];
            [self getCampaings:apiKey];
            [self recordUserStats:apiKey];
            [self checkUserDetailsQueue];
            [self checkConversionQueue:apiKey];
            [self checkSocialActionQueue:apiKey];
        }
        if (!responseString) {
            isInitialising = FALSE;
        }
        
    }else
        isInitialising=FALSE;

    
    return success;
    
    TCEND
}


+(void)checkConversionQueue:(NSString*)apiKey
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"convQueue"]) {
        convQueue = [[NSUserDefaults standardUserDefaults] valueForKeyPath:@"convQueue"];
        for (NSString * convKey in [convQueue allKeys] ) {
            NSDictionary * convDetails = [convQueue valueForKey:convKey];
            [self registerConversionEventWithApiKey:apiKey ForEvent:[convDetails valueForKey:@"eventDetails"] OnInstall:[[convDetails valueForKey:@"isInstall"] boolValue]];
            [self removeConversionEventFromQueue:convKey];
        }
    }
    
}

+(void)checkUserDetailsQueue
{
    NSMutableDictionary * userDetailsQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userDetailsQueue"]) {
        userDetailsQueue = [[NSUserDefaults standardUserDefaults] valueForKeyPath:@"userDetailsQueue"];
        for (NSString * userDetailsKey in [userDetailsQueue allKeys] ) {
            NSDictionary * userDetails = [userDetailsQueue valueForKey:userDetailsKey];
            [self setUserDetails:userDetails Oncompletion:^(BOOL success, NSError *error) {
                
            }];
            [self removeUserDetailsFromQueue:userDetailsKey];
        }
    }
    
}

+(UIWindow*)keyWindow {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(UIApplicationClass){
    UIWindow *keyWindow = [UIApplicationClass sharedApplication].keyWindow;
    if (keyWindow) return keyWindow;
    }
    return nil;
}

+(void)attributeBasedonCookie:(NSString*)apiKey
{
    TCSTART
    if ([[UIDevice currentDevice] systemVersion].integerValue >= 9 && cookieBasedAttribution)
    {
        Class SFSafariViewControllerClass = NSClassFromString(@"SFSafariViewController");
        if (SFSafariViewControllerClass) {
        dispatch_sync(dispatch_get_main_queue(), ^{

        id safController = [[SFSafariViewControllerClass alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/attr/ios/clk/%@/%@?%@",SHARE_URL,apiKey,[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString],[NSString stringWithFormat:@"%d", rand()]]]];
        
        UIViewController *windowRootController = [[UIViewController alloc] init];
//        UIWindow *primaryWindow = [self keyWindow];
        UIWindow* secondWindow;
        secondWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 0.5, 0.5)];

//            if (primaryWindow) {
//                secondWindow = [[UIWindow alloc] initWithFrame:primaryWindow.bounds];
//            } else {
//                secondWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 0.5, 0.5)];
//            }
        secondWindow.rootViewController = windowRootController;
        [secondWindow makeKeyAndVisible];
        [secondWindow setAlpha:1.0];
//            AppVirality2* av2=[[AppVirality2 alloc] init];
//            safController.delegate = av2;
        [windowRootController presentViewController:safController animated:YES completion:^{
            //NSLog(@"Cookie based attribution completed");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"cookieAttributionAttempt"]];
            [secondWindow.rootViewController dismissViewControllerAnimated:NO completion:NULL];
            secondWindow.rootViewController = nil;
        }];
            
            });

        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"cookieAttributionAttempt"]];
        }
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"cookieAttributionAttempt"]];
    }
    
    TCEND
}





+(void)registerUser:(NSString*)apiKey
{
    TCSTART
    NSURL *url;
    NSMutableDictionary * userInitDetailsDict = nil;
    if(userDetailsforInit != nil)
    userInitDetailsDict = [NSMutableDictionary dictionaryWithDictionary:userDetailsforInit];

    
    
    NSError *error = nil;
    NSString *adId = [Utility getAdvertiserID];
    
    if(!tempUserKey.length)
    {
        tempUserKey = [[[Utility GetTempUserKey] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    }
    
    NSMutableDictionary * userDictionary =[NSMutableDictionary dictionaryWithDictionary:@{@"apikey":apiKey,
                                                                                          @"userkey":tempUserKey,
                                                                                          @"deviceId":[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString],
                                                                                          @"DeviceModel":[UIDevice currentDevice].model,
                                                                                          @"OSVersion":[UIDevice currentDevice].systemVersion,
                                                                                          @"DeviceOSName":@"iOS",
                                                                                          @"UserAgent":[Utility userAgentString],
                                                                                          @"isSimulator":[NSNumber numberWithBool:[Utility isSimulator]],
                                                                                          }];

    if((initWithEmail && userInitDetailsDict == nil) || (initWithEmail && (userInitDetailsDict != nil && [userInitDetailsDict valueForKey:@"EmailId"] == nil)))
    {
        isInitialising = FALSE;
        return;
    }
    
    if (initWithEmail && userInitDetailsDict != nil && [userInitDetailsDict valueForKey:@"EmailId"] != nil) {
        
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getuseronsignup",SERVER_URL]];
        
        [userDictionary setValue:[userInitDetailsDict valueForKey:@"EmailId"] forKey:@"EmailId"];
        if (![[userInitDetailsDict valueForKey:@"ReferrerCode"] isEqual:[NSNull null]]) {
            [userDictionary setValue:[userInitDetailsDict valueForKey:@"ReferrerCode"] forKey:@"ReferrerCode"];

        }
        if (![[userInitDetailsDict valueForKey:@"isExistingUser"] isEqual:[NSNull null]]) {
            [userDictionary setValue:[userInitDetailsDict valueForKey:@"isExistingUser"] forKey:@"isExistingUser"];
            
        }
        if (![[userInitDetailsDict valueForKey:@"city"] isEqual:[NSNull null]]) {
            [userDictionary setValue:[userInitDetailsDict valueForKey:@"city"] forKey:@"city"];
            
        }
        if (![[userInitDetailsDict valueForKey:@"state"] isEqual:[NSNull null]]) {
            [userDictionary setValue:[userInitDetailsDict valueForKey:@"state"] forKey:@"state"];
            
        }
        if (![[userInitDetailsDict valueForKey:@"country"] isEqual:[NSNull null]]) {
            [userDictionary setValue:[userInitDetailsDict valueForKey:@"country"] forKey:@"country"];
            
        }
    }
    else
    {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getuser",SERVER_URL]];
    }
    
    if (adId) {
        [userDictionary setValue:adId forKey:@"AdvertiserId"];
    }
    
    DLog(@"register user request %@ %@",[NSString stringWithFormat:@"%@/getuser",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"register user response %@",response);
             
             if (response&&(![[response valueForKey:@"userkey"] isEqual:[NSNull null]])) {
                 
        
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"userkey"] forKey:@"userkey"];
                 tempUserKey = [response valueForKey:@"userkey"];
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"hasReferrer"] forKey:@"hasReferrer"];
                 if(![[response valueForKey:@"ReferrerCode"] isEqual:[NSNull null]]){
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"ReferrerCode"] forKey:@"AV_ReferrerCode"];
                 }

                 id referrerDetails = nil;
                 //This is required for init callback
                 if (referrerDetails) {
                     
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil userInfo:[NSDictionary dictionaryWithObject:referrerDetails forKey:@"referrerDetails"]];
                 }else
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil];
                 
                 
                 [self getCampaings:apiKey];
                 [self recordUserStats:apiKey];
                 [self checkUserDetailsQueue];
                 [self checkConversionQueue:apiKey];
                 [self checkSocialActionQueue:apiKey];
                 if ([[response valueForKey:@"hasReferrer"] boolValue]) {
                     
                     if ([response valueForKey:@"ReferrerCode"]) {
                         referrerDetails =[(id)response replaceNullsWithObject:@""];
                         
                         //save referrerDetails in userdefaults
                         [[NSUserDefaults standardUserDefaults] setObject:referrerDetails forKey:@"AV_ReferrerDetails"];
                         
                         if (![[response valueForKey:@"isExistingUser"] boolValue]) {
                             //[[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"isExistingUser"] forKey:@"AV_isExistingUser"];
                             [self registerConversionEventWithApiKey:apiKey ForEvent:@{@"eventName":@"Install"} OnInstall:YES];
                         }
                     }
                 }
                 
                 
                 //This is required for getreferrerdetails callback
                 if (referrerDetails) {
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil userInfo:[NSDictionary dictionaryWithObject:referrerDetails forKey:@"referrerDetails"]];
                 }else
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil];
             }else
             {
                 isInitialising=FALSE;
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"campaignDetails" object:nil];

             }
             
         }else
         {
             isInitialising=FALSE;
             if(connectionError)
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil userInfo:[NSDictionary dictionaryWithObject:connectionError forKey:@"errorInfo"]];
             else
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"referrerDetails" object:nil];

             
         }
     }];
    TCEND
}

+(void)recordUserStats:(NSString*)apiKey
{
    TCSTART
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/recordappuserstats",SERVER_URL]];
    NSError *error = nil;
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MMM-dd HH:mm:ss";
    
    NSString * dateString = [dateFormatter stringFromDate:[NSDate date]];
    NSMutableDictionary * userDictionary =[NSMutableDictionary dictionaryWithDictionary:@{@"osversion":[[UIDevice currentDevice] systemVersion],
                                                                                          @"devicewidth":[NSString stringWithFormat:@"%d",(int)SCREEN_WIDTH],                                                                                          @"deviceheight":[NSString stringWithFormat:@"%d",(int)SCREEN_HEIGHT],
                                                                                          @"devicename":[[UIDevice currentDevice] name],
                                                                                          @"applicationversion":[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                                                                                          @"recordeddatetime":dateString,
                                                                                          @"sdkversion":SDK_VERSION
                                                                                          }];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forKey:@"apikey"];
    [userDictionary setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] forKey:@"userkey"];
    
    DLog(@"record user stats request %@ %@",[NSString stringWithFormat:@"%@/recordappuserstats",SERVER_URL],userDictionary);
    
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             if (response) {
                 
             }
             
             DLog(@"record user stats response %@",response);
             
         }
     }];
    TCEND
}




+(void)checkSocialActionQueue:(NSString*)apiKey
{
    NSMutableDictionary * socialActionQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"socialActionQueue"]) {
        socialActionQueue = [[NSUserDefaults standardUserDefaults] valueForKeyPath:@"socialActionQueue"];
        for (NSString * socialActionKey in [socialActionQueue allKeys] ) {
            NSDictionary * socialActionDetails = [socialActionQueue valueForKey:socialActionKey];
            [self recordSocialActionForGrowthHack:[[socialActionDetails valueForKey:@"growthHackIndex"] integerValue] WithParams:[socialActionDetails valueForKey:@"actionParams"] completion:^(BOOL success,NSError*error) {
                
            }];
            [self removeSocialActionEventFromQueue:socialActionKey];
        }
    }
    
}

+(void)removeSocialActionEventFromQueue:(NSString*)convKey
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"socialActionQueue"]) {
        convQueue = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"socialActionQueue"]];
        [convQueue removeObjectForKey:convKey];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:convQueue forKey:@"socialActionQueue"];
    
}

+(void)addSocialActionEventToQueue:(NSString*)socialActionKey WithEventDetails:(NSDictionary*)actionParams AndGrowthHack:(GrowthHackType)growthHackIndex
{
    NSMutableDictionary * socialActionQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"socialActionQueue"]) {
        socialActionQueue =[NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"socialActionQueue"]];
    }
    
    [socialActionQueue setValue:[NSDictionary dictionaryWithObjectsAndKeys:actionParams,@"actionParams",[NSNumber numberWithInt:growthHackIndex],@"growthHackIndex",nil] forKey:socialActionKey];
    
    [[NSUserDefaults standardUserDefaults] setValue:socialActionQueue forKey:@"socialActionQueue"];
    
}



+(void)removeConversionEventFromQueue:(NSString*)convKey
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"convQueue"]) {
        convQueue = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"convQueue"]];
        [convQueue removeObjectForKey:convKey];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:convQueue forKey:@"convQueue"];
    
}

+(void)addConversionEventToQueue:(NSString*)convKey WithEventDetails:(NSDictionary*)eventDetails AndOnInstall:(BOOL)isInstall
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"convQueue"]) {
        convQueue = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"convQueue"]];
    }
    
    [convQueue setValue:[NSDictionary dictionaryWithObjectsAndKeys:eventDetails,@"eventDetails",[NSNumber numberWithBool:isInstall],@"isInstall", nil] forKey:convKey];
    
    [[NSUserDefaults standardUserDefaults] setValue:convQueue forKey:@"convQueue"];
    
}

+(void)removeUserDetailsFromQueue:(NSString*)userDetailsKey
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userDetailsQueue"]) {
        convQueue = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"userDetailsQueue"]];
        [convQueue removeObjectForKey:userDetailsKey];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:convQueue forKey:@"userDetailsQueue"];
    
}

+(void)addUserDetailsToQueue:(NSString*)userDetailsKey WithUserDetails:(NSDictionary*)userDetails
{
    NSMutableDictionary * convQueue = [NSMutableDictionary dictionary];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userDetailsQueue"]) {
        convQueue = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] valueForKeyPath:@"userDetailsQueue"]];
    }
    
    [convQueue setValue:userDetails forKey:userDetailsKey];
    
    [[NSUserDefaults standardUserDefaults] setValue:convQueue forKey:@"userDetailsQueue"];
    
}

+(void)registerConversionEventWithApiKey:(NSString*)apiKey ForEvent:(NSDictionary*)eventDetails OnInstall:(BOOL)isInstall
{
    TCSTART
    
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd'T'HHmmssSSS"];
    NSDate *now = [[NSDate alloc] init];
    NSString *dateString = [format stringFromDate:now];
    NSString * convString = [@"conv" stringByAppendingString:dateString];
    
    [self addConversionEventToQueue:convString WithEventDetails:eventDetails AndOnInstall:isInstall];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/saveconversionevent/%@",SERVER_URL_V21,apiKey]];
    NSError *error = nil;
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:eventDetails];
    [userDictionary setValue:apiKey forKey:@"apikey"];
    NSString * userkey = [[NSUserDefaults standardUserDefaults] valueForKey:@"userkey"];
    [userDictionary setValue:userkey forKey:@"userkey"];
   
    if (![[NSUserDefaults standardUserDefaults]objectForKey:@"userkey"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"conversionSuccess" object:nil];
        return;
    }
    [userDictionary setValue:isInstall?@"1":[NSNull null] forKey:@"onlyref"];
    if ([userDictionary objectForKey:@"transactionUnit"]) {
        [userDictionary setValue:[Utility  encodeToPercentEscapeString:[userDictionary objectForKey:@"transactionUnit"]] forKey:@"transactionUnit"];
    }
    if ([userDictionary objectForKey:@"extrainfo"]) {
        [userDictionary setValue:[Utility  encodeToPercentEscapeString:[userDictionary objectForKey:@"extrainfo"]] forKey:@"extrainfo"];
    }
    
    DLog(@"register conversions request %@ %@",[NSString stringWithFormat:@"%@/saveconversionevent",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:apiKey forHTTPHeaderField:@"avsdk-clientkey"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             if (response) {
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"conversionSuccess" object:nil];
                 
                 [self removeConversionEventFromQueue:convString];
                 DLog(@"register conversions response %@",response);
                 [[NSNotificationCenter defaultCenter] postNotificationName:@"conversionResult" object:nil userInfo:@{@"result":response}];
             }
        
         }
     }];
    TCEND
}


+(void)getCampaings:(NSString*)apiKey
{
    TCSTART
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/getcampaign",SERVER_URL_V2]];
    NSError *error = nil;
    NSMutableDictionary * campaignDictionary = [NSMutableDictionary dictionaryWithObject:apiKey forKey:@"apikey"];
    
    [campaignDictionary setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"userkey"] forKey:@"userkey"];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"currentcampaigns"]) {
        [campaignDictionary setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"currentcampaigns"] forKey:@"currentcampaigns"];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"remindlatercampaigns"]) {
        [campaignDictionary setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"remindlatercampaigns"] forKey:@"remindlatercampaigns"];
    }
    
    DLog(@"get campaigns request %@ %@",[NSString stringWithFormat:@"%@/getcampaign",SERVER_URL_V2],campaignDictionary);
    
    // DLog(@"%@",campaignDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:campaignDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         isInitialising = FALSE;
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"get campaigns response %@",response);
             id  campaignData = [response valueForKey:@"campaigndata"];
             if ([response objectForKey:@"currentcampaigns"]) {
                 [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"currentcampaigns"] forKey:@"currentcampaigns"];
             }
             if (![campaignData isEqual:[NSNull null]]) {
                 [[NSUserDefaults standardUserDefaults] setValue:[campaignData replaceNullsWithObject:@""] forKey:@"campaignData"];
             }
             
         }
         [[NSNotificationCenter defaultCenter] postNotificationName:@"campaignDetails" object:nil];

     }];
    TCEND
}

+ (void)submitReferralCode:(NSString*)referralCode  completion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(NO,error);
        return;

    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/setreferrercode",SERVER_URL]];
    NSError *error = nil;
    
    NSMutableDictionary * userDictionary =[NSMutableDictionary dictionaryWithDictionary:@{@"apikey":[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"],
                                                                                          @"userkey":[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"],
                                                                                          @"UserAgent":[Utility userAgentString],
                                                                                          @"ReferrerCode":referralCode
                                                                                          }];

    
    DLog(@"Submit referral code request %@ %@",[NSString stringWithFormat:@"%@/setreferrercode",SERVER_URL],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"submit referral code response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 
                 if([[response valueForKey:@"success"] boolValue])
                 {
                     id referrerDetailsOnSubmitReferrerCode = nil;
                     [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"hasReferrer"] forKey:@"hasReferrer"];
                     if(![[response valueForKey:@"ReferrerCode"] isEqual:[NSNull null]]){
                         [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"ReferrerCode"] forKey:@"AV_ReferrerCode"];
                     }
                     
                     if ([response valueForKey:@"ReferrerCode"]) {
                         referrerDetailsOnSubmitReferrerCode =[(id)response replaceNullsWithObject:@""];
                         
                         //save referrerDetails in userdefaults
                         [[NSUserDefaults standardUserDefaults] setObject:referrerDetailsOnSubmitReferrerCode forKey:@"AV_ReferrerDetails"];
                     }

                 }
                 
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
         
     }];
    TCEND
    
}

+ (void)customizeReferralCode:(NSString*)newReferralCode completion:(void (^)(BOOL success,NSError *error))completion
{
    TCSTART
    
    NSCharacterSet *refcodeChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"];
    refcodeChars = [refcodeChars invertedSet];
    NSRange r = [newReferralCode rangeOfCharacterFromSet:refcodeChars];
    
    if (!newReferralCode.length || r.location != NSNotFound || newReferralCode.length > 10) {
        
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Invalid Referral code", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please provide valid referral code.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please provide valid referral code.");
        completion(NO,error);
        return;
    }
    
    
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"API key is missing.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Please initialize the SDK with a valid API Key.", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        DLog(@"Please initialize the SDK with a valid API Key.");
        completion(NO,error);
        return;
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"RI check failed.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (!isInitialising&&![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        
        if (![self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]) {
            completion(NO,error);
            return;
        }
    }
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User Key not found.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"", nil)
                                   };
        NSError *error = [NSError errorWithDomain:NSAppViralityErrorDomain
                                             code:-57
                                         userInfo:userInfo];
        completion(NO,error);
        return;
        
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/customizereferralcode/%@",SERVER_URL_V21,[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]]];
    NSError *error = nil;
    
    NSMutableDictionary * userDictionary = [NSMutableDictionary dictionaryWithDictionary:@{@"userkey":[[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"],@"customUrlTag":newReferralCode }];
    
    DLog(@"Submit referral code request %@ %@",[NSString stringWithFormat:@"%@/customizereferralcode",SERVER_URL_V21],userDictionary);
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:userDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    
    NSMutableURLRequest *request=[NSMutableURLRequest
                                  requestWithURL:url
                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"] forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] forHTTPHeaderField:@"avsdk-clientkey"];
    [request setHTTPBody:jsonData];
    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:0
                                                                        error:NULL];
             
             DLog(@"submit referral code response %@",response);
             
             if ([response objectForKey:@"success"]) {
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"campaignData"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentcampaigns"];
                 completion([[response valueForKey:@"success"] boolValue],connectionError);
                 return;
             }else
             {
                 completion(NO,connectionError);
                 return;
             }
         }else
         {
             completion(NO,connectionError);
             return;
         }
         
     }];
    TCEND
    
}

+(void)enableInitWithEmail
{
    initWithEmail = YES;
}

+(void)getAllUrlData:(NSString *)emailId
               appId:(NSInteger)appId
{
    TCSTART

    // Create URL safely with query parameters
    NSURLComponents *components =
    [NSURLComponents componentsWithString:
     [NSString stringWithFormat:@"%@/getallurl", SERVER_URL_V21]];

    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"emailid" value:emailId],
        [NSURLQueryItem queryItemWithName:@"appid"
                                    value:[NSString stringWithFormat:@"%ld",(long)appId]]
    ];

    NSURL *url = components.URL;

    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:url
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:30];

    [request setHTTPMethod:@"GET"];

    DLog(@"getAllUrlData GET request %@", url);

    [Utility genericHTTPRequest:request retryNumber:0 callback:
     ^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *responseDict =
             [NSJSONSerialization JSONObjectWithData:data
                                             options:0
                                               error:NULL];

             DLog(@"getAllUrlData response %@", responseDict);

             // Handle response here if needed
         }
         else
         {
             DLog(@"Error %@", connectionError);
         }
     }];

    TCEND
}


+ (void)getAllUrlData:(NSString *)emailId
                appId:(NSInteger)appId
           completion:(void (^)(NSDictionary *response, NSError *error))completion
{
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] ?: @"";
    NSString *xVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"] ?: @"";
    NSString *encodedEmail = [Utility encodeToPercentEscapeString:emailId];
    NSString *urlString = [NSString stringWithFormat:@"%@/getallurl/%@?emailId=%@&appId=%ld",
                           SERVER_URL_V21, apiKey, encodedEmail, (long)appId];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:apiKey forHTTPHeaderField:@"avsdk-clientkey"];
    [request setValue:xVersion forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[Utility userAgentString] forHTTPHeaderField:@"User-Agent"];
    // If you need to set cookies, do so here.

    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSDictionary *json = nil;
        NSError *jsonError = nil;
        if (data) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        }
        if (completion) {
            completion(json, connectionError ?: jsonError);
        }
    }];
}

+ (void)submitUrlWithEmail:(NSString *)email
                      name:(NSString *)name // kept for compatibility; not used
                     phone:(NSString *)phone
                       url:(NSString *)url
                campaignId:(NSInteger)campaignId // kept for compatibility; not used
                     appId:(NSInteger)appId
                completion:(void (^)(NSDictionary *response, NSError *error))completion
{
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"] ?: @"";
    NSString *xVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"] ?: @"";
    NSString *appuserid = [[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"] ?: @"";
    
    // API endpoint as per requirements
    NSString *endpoint = [NSString stringWithFormat:@"%@/submit/%@", SERVER_URL_V21, apiKey];
    NSURL *requestURL = [NSURL URLWithString:endpoint];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (email)      [params setObject:email forKey:@"emailId"];
    if (phone)      [params setObject:phone forKey:@"phone"];
    if (url)        [params setObject:url forKey:@"url"];
    [params setObject:@(appId) forKey:@"appId"];
    if (appuserid)  [params setObject:appuserid forKey:@"appuserid"];

    NSError *error = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    if (error) {
        if (completion) completion(nil, error);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:xVersion forHTTPHeaderField:@"x-version-av1.1"];
    [request setValue:apiKey forHTTPHeaderField:@"avsdk-clientkey"];
    [request setValue:[Utility userAgentString] forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBody:bodyData];

    [Utility genericHTTPRequest:request retryNumber:0 callback:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSDictionary *json = nil;
        NSError *jsonError = nil;
        if (data) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        }
        if (completion) {
            completion(json, connectionError ?: jsonError);
        }
    }];
}

@end
