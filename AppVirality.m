//
//  AppVirality.m
//  AppViralityToolKit
//
//  Created by Ram on 14/04/15.
//  Copyright (c) 2015 AppVirality. All rights reserved.
//

#import "AppVirality.h"
#import "Utility.h"
#import "AVQRCodeViewController.h"
#import <CoreImage/CoreImage.h>
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

// FIX: completes the abandoned delegate stub above — attributeBasedonCookie: was firing
// "doneCookieBasedAttribution" from presentViewController's completion handler, which only
// signals the presentation ANIMATION finished, not that the tracking-pixel page inside the
// SFSafariViewController actually loaded. This delegate lets us wait for the real signal
// (didCompleteInitialLoad:) instead.
@interface AVCookieAttributionDelegate : NSObject <SFSafariViewControllerDelegate>
@property (nonatomic, copy) void (^onComplete)(BOOL didLoadSuccessfully);
@end

@implementation AVCookieAttributionDelegate
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    if (self.onComplete) {
        self.onComplete(didLoadSuccessfully);
    }
}
@end

static AVCookieAttributionDelegate *cookieAttributionDelegate;

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


#pragma mark - Referral QR code
// Nothing in this section records a social action. Displaying a QR shares nothing: the share
// happens only when someone else scans it, and the server records that at the landing page.
// Recording here would count every popup open as an invite, and invite counts never go down.

+ (NSError *)qrCodeErrorWithReason:(NSString *)reason
{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                               NSLocalizedFailureReasonErrorKey: reason,
                               NSLocalizedRecoverySuggestionErrorKey: @""
                               };
    return [NSError errorWithDomain:NSAppViralityErrorDomain code:-57 userInfo:userInfo];
}

// Shared by the public QR methods and AVQRCodeViewController. Fetches campaigns first if they
// are not cached (getGrowthHack does that); with campaigns cached it makes no network call.
// Always completes on the main thread.
+ (void)loadQRCodeWithSize:(CGFloat)size completion:(void (^)(UIImage *image, NSDictionary *campaignDetails, NSError *error))completion
{
    if (!completion) {
        return;
    }
    void (^finish)(UIImage *, NSDictionary *, NSError *) = ^(UIImage *image, NSDictionary *campaignDetails, NSError *error) {
        if ([NSThread isMainThread]) {
            completion(image, campaignDetails, error);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(image, campaignDetails, error);
            });
        }
    };
    if (size <= 0) {
        finish(nil, nil, [self qrCodeErrorWithReason:@"QR code size must be greater than zero."]);
        return;
    }
    [self getGrowthHack:GrowthHackTypeWordOfMouth completion:^(NSDictionary *campaignDetails, NSError *error) {
        if (!campaignDetails && error) {
            finish(nil, nil, error);
            return;
        }
        // Never fall back to a partial or alternative URL: a QR with the wrong URL still scans
        // and looks like success while crediting the wrong channel.
        NSString *qrShareURL = [campaignDetails valueForKey:@"qrShareURL"];
        if (![qrShareURL isKindOfClass:[NSString class]] || qrShareURL.length == 0) {
            finish(nil, campaignDetails, [self qrCodeErrorWithReason:@"Referral QR code is not available yet. Please try again after the user is registered."]);
            return;
        }
        DLog(@"QR share URL %@", qrShareURL);
        UIImage *image = [self qrCodeImageForString:qrShareURL size:size];
        if (!image) {
            finish(nil, campaignDetails, [self qrCodeErrorWithReason:@"Could not generate the QR code."]);
            return;
        }
        finish(image, campaignDetails, nil);
    }];
}

+ (UIImage *)qrCodeImageForString:(NSString *)string size:(CGFloat)size
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!data || !filter) {
        return nil;
    }
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *qrImage = filter.outputImage;
    if (!qrImage || CGRectIsEmpty(qrImage.extent)) {
        return nil;
    }

    // CIQRCodeGenerator emits one pixel per module. Scale by a whole number with nearest-neighbour
    // sampling so module edges stay hard; default interpolation blurs them and scanners struggle.
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat pixelSize = size * screenScale;
    CGFloat moduleScale = MAX(1, floor(pixelSize / CGRectGetWidth(qrImage.extent)));
    CIImage *scaledImage = [[qrImage imageBySamplingNearest] imageByApplyingTransform:CGAffineTransformMakeScale(moduleScale, moduleScale)];
    CGImageRef cgImage = [[CIContext contextWithOptions:nil] createCGImage:scaledImage fromRect:scaledImage.extent];
    if (!cgImage) {
        return nil;
    }

    // Centre it on a white square of exactly the requested size, drawn pixel for pixel.
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = screenScale;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
    UIImage *codeImage = [UIImage imageWithCGImage:cgImage scale:screenScale orientation:UIImageOrientationUp];
    CGFloat codePoints = CGImageGetWidth(cgImage) / screenScale;
    CGFloat origin = floor((pixelSize - CGImageGetWidth(cgImage)) / 2) / screenScale;
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor whiteColor] setFill];
        UIRectFill(CGRectMake(0, 0, size, size));
        CGContextSetInterpolationQuality(context.CGContext, kCGInterpolationNone);
        [codeImage drawInRect:CGRectMake(origin, origin, codePoints, codePoints)];
    }];
    CGImageRelease(cgImage);
    return image;
}

+ (void)showQRCodeFromViewController:(UIViewController *)viewController completion:(void (^)(NSError *error))completion
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showQRCodeFromViewController:viewController completion:completion];
        });
        return;
    }
    if (!viewController) {
        if (completion) {
            completion([self qrCodeErrorWithReason:@"A view controller is required to show the QR code."]);
        }
        return;
    }
    AVQRCodeViewController *qrViewController = [[AVQRCodeViewController alloc] initWithCompletion:completion];
    [viewController presentViewController:qrViewController animated:YES completion:nil];
}

+ (void)qrCodeImageWithSize:(CGFloat)size completion:(void (^)(UIImage *image, NSError *error))completion
{
    if (!completion) {
        return;
    }
    [self loadQRCodeWithSize:size completion:^(UIImage *image, NSDictionary *campaignDetails, NSError *error) {
        completion(image, error);
    }];
}

// iOS terminates the app on its first photo-library write if the host app's Info.plist lacks
// this key, so the SDK never attempts one unless the client declared it.
+ (BOOL)canAddToPhotoLibrary
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSPhotoLibraryAddUsageDescription"] != nil;
}

+ (void)shareQRCodeImage:(UIImage *)image fromViewController:(UIViewController *)viewController
{
    if (!image || !viewController) {
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self shareQRCodeImage:image fromViewController:viewController];
        });
        return;
    }
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image] applicationActivities:nil];
    if (![self canAddToPhotoLibrary]) {
        // The sheet's "Save Image" would hit the same missing-key crash.
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }
    UIPopoverPresentationController *popover = activityViewController.popoverPresentationController;
    if (popover) {
        CGRect bounds = viewController.view.bounds;
        popover.sourceView = viewController.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 0, 0);
        popover.permittedArrowDirections = 0;
    }
    [viewController presentViewController:activityViewController animated:YES completion:nil];
}

+ (void)saveQRCodeImage:(UIImage *)image fromViewController:(UIViewController *)viewController
{
    if (!image || !viewController) {
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveQRCodeImage:image fromViewController:viewController];
        });
        return;
    }
    if (![self canAddToPhotoLibrary]) {
        // Mirrors Android on API 24-28: no permission-free direct save, so hand over to the share
        // sheet, where the user can still send the image anywhere.
        [self shareQRCodeImage:image fromViewController:viewController];
        return;
    }
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(qrCodeImage:didFinishSavingWithError:contextInfo:), (__bridge_retained void *)viewController);
}

+ (void)qrCodeImage:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    UIViewController *viewController = (__bridge_transfer UIViewController *)contextInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showQRToast:error ? @"Could not save the QR image." : @"QR code saved to Photos" inView:viewController.view];
    });
}

+ (void)showQRToast:(NSString *)message inView:(UIView *)view
{
    UIView *hostView = view.window ?: view;
    if (!hostView) {
        return;
    }
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.text = message;
    toastLabel.font = [UIFont systemFontOfSize:14];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
    toastLabel.layer.cornerRadius = 8;
    toastLabel.layer.masksToBounds = YES;
    [toastLabel sizeToFit];
    CGFloat width = MIN(CGRectGetWidth(toastLabel.bounds) + 32, CGRectGetWidth(hostView.bounds) - 40);
    toastLabel.frame = CGRectMake(0, 0, width, 36);
    toastLabel.center = CGPointMake(CGRectGetMidX(hostView.bounds), CGRectGetMaxY(hostView.bounds) - 120);
    toastLabel.alpha = 0;
    [hostView addSubview:toastLabel];
    [UIView animateWithDuration:0.2 animations:^{
        toastLabel.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.5 options:0 animations:^{
            toastLabel.alpha = 0;
        } completion:^(BOOL done) {
            [toastLabel removeFromSuperview];
        }];
    }];
}

#pragma mark -

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
    [Utility userAgentStringWithCompletion:^(NSString *agent) {
        [self checkRI:apiKey];
    }];
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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
    
    if (!isInitialising && ![[NSUserDefaults standardUserDefaults] objectForKey:@"x-version-av1.1"]) {
        
        isInitialising = YES;
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];
        
        // DO NOT call completion here.
        // It will be triggered via notification when checkRI finishes.
        
        return;
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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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


+ (void)checkRI:(NSString *)apiKey
{
    TCSTART
    NSLog(@"🔎 userkey before checkRI decision = %@",
          [[NSUserDefaults standardUserDefaults] valueForKey:@"userkey"]);
    isInitialising = TRUE;

    // BUG (#5): this pre-check carried only the apikey, no deviceId, so server-side
    // correlation of "does this device have a pending referral click" had nothing to
    // go on but raw request IP — which is exactly what Private Relay/NAT degrade.
    // Original code, kept for reference:
    // NSURL *url = [NSURL URLWithString:
    //               [NSString stringWithFormat:@"%@/%@", RI_URL, apiKey]];

    // FIX (#5): include deviceId so the server has a stable identifier to match
    // against, independent of the client's current IP address.
    NSString *checkRIDeviceId = [[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    NSURL *url = [NSURL URLWithString:
                  [NSString stringWithFormat:@"%@/%@?deviceId=%@", RI_URL, apiKey, checkRIDeviceId]];

    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:url
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:30];
    
    [request setHTTPMethod:@"GET"];
    
    NSURLSessionDataTask *task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data,
                                                        NSURLResponse *response,
                                                        NSError *error)
    {
        if (error || data.length == 0) {
            NSLog(@"checkRI error: %@", error);

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:@"referrerDetails"
                    object:nil];
            });

            isInitialising = FALSE;
            return;
        }

        NSLog(@"Raw checkRI data: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSLog(@"HTTP Status: %ld", (long)((NSHTTPURLResponse *)response).statusCode);
        
        NSDictionary *responseDict =
        [NSJSONSerialization JSONObjectWithData:data
                                        options:0
                                          error:nil];
        
        if (!responseDict) {
            NSLog(@"JSON parsing failed.");

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:@"referrerDetails"
                    object:nil];
            });

            isInitialising = FALSE;
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if ([httpResponse respondsToSelector:@selector(allHeaderFields)]) {
            NSDictionary *headers = httpResponse.allHeaderFields;
            
            if (headers[@"x-version-av1.1"]) {
                [[NSUserDefaults standardUserDefaults]
                 setValue:headers[@"x-version-av1.1"]
                 forKey:@"x-version-av1.1"];
            } else {
                [[NSUserDefaults standardUserDefaults]
                 removeObjectForKey:@"x-version-av1.1"];
            }
            NSLog(@"✅ Saved x-version header = %@",
                  [[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"]);

        }
        
        NSLog(@"checkRI response: %@", responseDict);
        
        BOOL success =
        [responseDict[@"success"] boolValue];
        
        if (success && ![[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {

            dispatch_async(dispatch_get_main_queue(), ^{
                [self registerUser:apiKey];
            });

        } else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"]) {

            dispatch_async(dispatch_get_main_queue(), ^{

                   [[NSNotificationCenter defaultCenter]
                    postNotificationName:@"referrerDetails"
                    object:nil];

                   [self getCampaings:apiKey];
                   [self recordUserStats:apiKey];
                   [self checkUserDetailsQueue];
                   [self checkConversionQueue:apiKey];
                   [self checkSocialActionQueue:apiKey];
               });
        }
        // BUG (#2): no else here — if success == false AND there's no existing userkey
        // (invalid apikey, app disabled server-side, etc.), neither branch above runs,
        // so "referrerDetails" never posts, and initWithApiKey's OnCompletion (which
        // waits on that notification) hangs forever with no error surfaced.
        else {
            // FIX (#2): always post the notification so OnCompletion fires, even on failure.
            NSError *riError = [NSError errorWithDomain:NSAppViralityErrorDomain
                                                     code:-58
                                                 userInfo:@{NSLocalizedDescriptionKey: @"RI check failed and no existing userkey found"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:@"referrerDetails"
                    object:nil
                    userInfo:@{@"errorInfo": riError}];
            });
        }

        isInitialising = FALSE;
    }];
    
    [task resume];
    
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

+ (UIWindow *)activeWindow {
    UIWindow *activeWindow = nil;
    
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:UIWindowScene.class]) {
            
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            activeWindow = windowScene.windows.firstObject;
            break;
        }
    }
    
    return activeWindow;
}


+(void)attributeBasedonCookie:(NSString*)apiKey
{
    TCSTART
    DLog(@"attributeBasedonCookie called");
    if ([[UIDevice currentDevice] systemVersion].integerValue >= 9 && cookieBasedAttribution)
    {
        Class SFSafariViewControllerClass = NSClassFromString(@"SFSafariViewController");
        if (SFSafariViewControllerClass) {
        dispatch_sync(dispatch_get_main_queue(), ^{

        // BUG: two problems with the legacy window handling below (kept as a comment):
        // 1) secondWindow was never attached to a UIWindowScene, required since iOS 13 —
        //    on a modern multi-scene app this window can fail to become key/visible at
        //    all, so the SFSafariViewController presented on it may never actually render
        //    or let its network request complete.
        // 2) "doneCookieBasedAttribution" fired from presentViewController's completion
        //    handler, which only signals the presentation ANIMATION finished — not that
        //    the tracking-pixel page inside the SFSafariViewController actually loaded.
        //    The window was torn down immediately after, likely cancelling the in-flight
        //    attribution request before the server ever processed it.
        // Original code, kept for reference:
        // id safController = [[SFSafariViewControllerClass alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/attr/ios/clk/%@/%@?%@",SHARE_URL,apiKey,[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString],[NSString stringWithFormat:@"%d", rand()]]]];
        // UIViewController *windowRootController = [[UIViewController alloc] init];
        // UIWindow* secondWindow;
        // secondWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 0.5, 0.5)];
        // secondWindow.rootViewController = windowRootController;
        // [secondWindow makeKeyAndVisible];
        // [secondWindow setAlpha:1.0];
        // [windowRootController presentViewController:safController animated:YES completion:^{
        //     [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"cookieAttributionAttempt"]];
        //     [secondWindow.rootViewController dismissViewControllerAnimated:NO completion:NULL];
        //     secondWindow.rootViewController = nil;
        // }];

        // FIX: attach the overlay window to the app's real active scene, and wait for the
        // SFSafariViewController's actual page load (via its delegate) before tearing
        // anything down — with a bounded timeout as a safety net in case the delegate
        // callback never fires.
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/attr/ios/clk/%@/%@?%@",SHARE_URL,apiKey,[[[Utility GetDeviceID] stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString],[NSString stringWithFormat:@"%d", rand()]]];
        DLog(@"URL = %@", url);
        id safController = [[SFSafariViewControllerClass alloc] initWithURL:url];

        // BUG: secondWindow's frame was a near-zero 0.5x0.5 point rect, inherited from the
        // original code's attempt to keep it "invisible." On a real device this makes
        // SFSafariView's internal Auto Layout unsatisfiable (it reserves ~64pt at the top
        // for its own toolbar, which cannot fit in a 0.5pt-tall container), forcing iOS to
        // break a constraint to recover — confirmed via a real "Unable to simultaneously
        // satisfy constraints" warning on device — and didCompleteInitialLoad: never fired
        // as a result. FIX: give it a real, screen-sized frame so SFSafariView can lay out
        // correctly (see the alpha comment below for why this can't be hidden by size).
        UIWindow *activeWindow = [self activeWindow];
        UIViewController *windowRootController = [[UIViewController alloc] init];
        CGRect windowFrame = activeWindow ? activeWindow.bounds : [UIScreen mainScreen].bounds;
        UIWindow *secondWindow = [[UIWindow alloc] initWithFrame:windowFrame];
        if (@available(iOS 13.0, *)) {
            if (activeWindow.windowScene) {
                secondWindow.windowScene = activeWindow.windowScene;
            }
        }
        secondWindow.rootViewController = windowRootController;
        [secondWindow makeKeyAndVisible];
        // Alpha must stay at full opacity on secondWindow itself: WebKit deprioritizes/
        // throttles page loads for views it doesn't consider genuinely visible (near-zero
        // alpha included), which was silently preventing didCompleteInitialLoad: from ever
        // firing. So secondWindow/safController must remain full-size and fully opaque.
        // To keep this invisible to the user anyway, a separate opaque "curtain" window is
        // layered above it (below) — a different window, so it doesn't change secondWindow's
        // own frame/alpha and WebKit still treats the page as visible.
        [secondWindow setAlpha:1.0];

        UIWindow *curtainWindow = [[UIWindow alloc] initWithFrame:windowFrame];
        if (@available(iOS 13.0, *)) {
            if (activeWindow.windowScene) {
                curtainWindow.windowScene = activeWindow.windowScene;
            }
        }
        curtainWindow.windowLevel = UIWindowLevelStatusBar + 1;
        curtainWindow.rootViewController = [[UIViewController alloc] init];
        curtainWindow.rootViewController.view.backgroundColor = activeWindow.backgroundColor ?: [UIColor whiteColor];
        curtainWindow.hidden = NO;

        cookieAttributionDelegate = [[AVCookieAttributionDelegate alloc] init];
        __block BOOL attributionCompleted = NO;
        void (^finishAttribution)(BOOL) = ^(BOOL success) {
            if (attributionCompleted) return;
            attributionCompleted = YES;
            cookieAttributionDelegate = nil;
            DLog(@"doneCookieBasedAttribution");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:success] forKey:@"cookieAttributionAttempt"]];
            [windowRootController dismissViewControllerAnimated:NO completion:NULL];
            secondWindow.rootViewController = nil;
            curtainWindow.hidden = YES;
            curtainWindow.rootViewController = nil;
        };
        cookieAttributionDelegate.onComplete = ^(BOOL didLoadSuccessfully) {
            DLog(@"didCompleteInitialLoad = %d", didLoadSuccessfully);
            finishAttribution(didLoadSuccessfully);
        };
        if ([safController respondsToSelector:@selector(setDelegate:)]) {
            [safController setDelegate:cookieAttributionDelegate];
        }

        [windowRootController presentViewController:safController animated:YES completion:nil];
        DLog(@"Safari Presented");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            finishAttribution(NO);
        });

            });

        }
        else
        {
            DLog(@"doneCookieBasedAttribution");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"doneCookieBasedAttribution" object:nil userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"cookieAttributionAttempt"]];
        }
    }
    else
    {
        DLog(@"doneCookieBasedAttribution");
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
        tempUserKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"userkey"];
    }
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
                 NSLog(@"✅ Saved userkey = %@",
                       [[NSUserDefaults standardUserDefaults] valueForKey:@"userkey"]);
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

                         // BUG (#1): this gated the Install event on hasReferrer/ReferrerCode, so
                         // automatic attribution failures (common under ITP/ATT/Private Relay for
                         // link-based installs) silently dropped the Install event forever.
                         // Original code, kept for reference:
                         // if (![[response valueForKey:@"isExistingUser"] boolValue]) {
                         //     [[NSUserDefaults standardUserDefaults] setValue:[response valueForKey:@"isExistingUser"] forKey:@"AV_isExistingUser"];
                         //     [self registerConversionEventWithApiKey:apiKey ForEvent:@{@"eventName":@"Install"} OnInstall:YES];
                         // }
                     }
                 }

                 // FIX (#1): Install must fire for every new user regardless of whether automatic
                 // referrer attribution (hasReferrer) succeeded.
                 if (![[response valueForKey:@"isExistingUser"] boolValue]) {
                     [self registerConversionEventWithApiKey:apiKey ForEvent:@{@"eventName":@"Install"} OnInstall:YES];
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
    NSLog(@"🔥 getCampaings CALLED");
    NSLog(@"Current userkey = %@",
          [[NSUserDefaults standardUserDefaults] valueForKey:@"userkey"]);
    NSLog(@"Current x-version = %@",
          [[NSUserDefaults standardUserDefaults] valueForKey:@"x-version-av1.1"]);

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
        
        [self checkRI:[[NSUserDefaults standardUserDefaults] objectForKey:@"AVapiKey"]];

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
    NSString *endpoint = [NSString stringWithFormat:@"%@/submiturl/%@", SERVER_URL_V21, apiKey];
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
