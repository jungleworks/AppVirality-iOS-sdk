//
//  AVQRCodeViewController.h
//  AppVirality
//
//  Copyright (c) 2026 AppVirality. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/* The ready-made referral QR popup behind +[AppVirality showQRCodeFromViewController:completion:].
   Call that method instead of presenting this class directly. Never records a social action:
   displaying a QR shares nothing, the scan is recorded server-side at the landing page. */
@interface AVQRCodeViewController : UIViewController
- (instancetype)initWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
