//
//  AppVirality.h
//  AppVirality
//
//  Created by Ram Papineni on 18/06/15.
//  Copyright (c) 2015 AppVirality. All rights reserved.
//  Version 1.2.12

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    GrowthHackTypeWordOfMouth ,
    GrowthHackTypeCustomerRetention,
    GrowthHackTypeLoyalty,
    GrowthHackTypeAll
} GrowthHackType;

@interface AppVirality : NSObject
+(void)init;
/* If your App has Login/Logout, initialize the SDK after user login/signup and send user emailid and referrercode(if user enters) in dictionary.Otherwise send nil. You can also send user location details(city,state,country) in the dictionary along with user email, if you are targetting particular location */
+(void)initWithApiKey:(NSString *)apiKey WithParams:(NSDictionary*)userDetails OnCompletion:(void(^)(NSDictionary * referrerDetails,NSError *error))completion;
+(void)getReferrerDetails:(void(^)(NSDictionary * referrerDetails,NSError *error))completion;
+(void)getGrowthHack:(GrowthHackType)growthHack  completion:(void (^)(NSDictionary* campaignDetails,NSError *error))completion;
+(void)saveConversionEvent:(NSDictionary*)eventDetails  completion:(void (^)(NSDictionary* conversionResult,NSError *error))completion;
+(void)recordSocialActionForGrowthHack:(GrowthHackType)growthHack WithParams:(NSDictionary*)actionParams  completion:(void (^)(BOOL success,NSError *error))completion;
+(void)registerAsDebugDevice:(void (^)(BOOL success,NSError *error))completion;
+(void)getUserBalance:(GrowthHackType)growthHack  completion:(void (^)(NSDictionary* userInfo,NSError *error))completion;
+(void)getUserBalanceV2:(GrowthHackType)growthHack  completion:(void (^)(NSDictionary* userInfo,NSError *error))completion;
+(void)setUserDetails:(NSDictionary*)userDetails Oncompletion:(void (^)(BOOL success,NSError *error))completion ;
+(void)setCustomURL:(NSString*)customUrl  completion:(void (^)(BOOL success,NSError *error))completion;
+(void)getTerms:(GrowthHackType)growthHack  completion:(void (^)(NSDictionary* terms,NSError *error))completion;
+(void)setUserLocation:(NSDictionary*)userDetails  completion:(void (^)(BOOL success,NSError *error))completion;
+(BOOL)isDebug;
+(void)recordImpressionsForGrowthHack:(GrowthHackType)growthHackIndex WithParams:(NSDictionary*)actionParams  completion:(void (^)(NSDictionary* response,NSError *error))completion;
+(void)checkReferrerRewards:(void (^)(NSDictionary *rewards,NSError *error))completion;
+(void)redeemRewards:(NSArray*)rewards  completion:(void (^)(BOOL success,NSError *error))completion;
+(void)getUserRewards:(void (^)(NSDictionary *rewards,NSError *error))completion;
+(void)getUserCoupons:(void (^)(NSDictionary *coupons,NSError *error))completion;
+(void)logout;
+(void)attributeUserBasedonCookie:(NSString *)apiKey OnCompletion:(void(^)(BOOL success,NSError *error))completion;
+(void)getReferrerDetailsDirect:(void(^)(NSDictionary * referrerDetails,NSError *error))completion;
+(void)submitReferralCode:(NSString*)referralCode  completion:(void (^)(BOOL success,NSError *error))completion;
+(void)enableInitWithEmail;
+(void)checkAttribution:(NSString *)apiKey withReferrerCode:(NSString*)referrerCode OnCompletion:(void(^)(NSDictionary * referrerDetails,NSError *error))completion;
+(void)customizeReferralCode:(NSString*)newReferralCode  completion:(void (^)(BOOL success,NSError *error))completion;
+(void)getAllUrlData:(NSString *)emailId
               appId:(NSInteger)appId
          completion:(void (^)(NSDictionary *response, NSError *error))completion;

+ (void)submitUrlWithEmail:(NSString *)email
                      name:(NSString *)name
                     phone:(NSString *)phone
                       url:(NSString *)url
                campaignId:(NSInteger)campaignId
                     appId:(NSInteger)appId
                 completion:(void (^)(NSDictionary *response, NSError *error))completion;

/* Referral QR code for the Word of Mouth campaign. Safe to call any time after init: campaign data is
   fetched first if it is not loaded yet. None of these record a social action — the scan is recorded
   server-side at the landing page. Completion blocks run on the main thread. */

/* Opens a ready-made popup with the QR code, the referral code and a Share button. Errors are shown
   inside the popup; completion receives nil once the QR is shown, or the same error. */
+(void)showQRCodeFromViewController:(UIViewController*)viewController completion:(void (^)(NSError *error))completion;
/* Returns a square QR image, size in points, rendered at screen scale. For clients with their own layout. */
+(void)qrCodeImageWithSize:(CGFloat)size completion:(void (^)(UIImage *image,NSError *error))completion;
/* Saves a QR image to Photos. If the app's Info.plist has no NSPhotoLibraryAddUsageDescription,
   opens the share sheet instead, since a direct save without that key crashes the app. */
+(void)saveQRCodeImage:(UIImage*)image fromViewController:(UIViewController*)viewController;
/* Opens the share sheet with a QR image. */
+(void)shareQRCodeImage:(UIImage*)image fromViewController:(UIViewController*)viewController;
@end



