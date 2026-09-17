//
//  AVQRCodeViewController.m
//  AppVirality
//
//  Copyright (c) 2026 AppVirality. All rights reserved.
//

#import "AVQRCodeViewController.h"
#import "AppVirality.h"

static const CGFloat AVQRCodeSize = 280;

static UIColor * AVQRColor(unsigned rgb)
{
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF)/255.0 green:((rgb >> 8) & 0xFF)/255.0 blue:(rgb & 0xFF)/255.0 alpha:1.0];
}

@interface AppVirality (AVQRCodeInternal)
+ (void)loadQRCodeWithSize:(CGFloat)size completion:(void (^)(UIImage *image, NSDictionary *campaignDetails, NSError *error))completion;
@end

@interface AVQRCodeViewController ()
@property (nonatomic, copy, nullable) void (^completion)(NSError * _Nullable error);
@property (nonatomic, strong, nullable) UIImage *qrImage;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *codeLabel;
@property (nonatomic, strong) UIButton *shareButton;
@end

@implementation AVQRCodeViewController

- (instancetype)initWithCompletion:(void (^)(NSError *))completion
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _completion = [completion copy];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];

    // Tapping outside the card closes the popup, like an Android Dialog.
    UIControl *dimmingControl = [[UIControl alloc] init];
    dimmingControl.translatesAutoresizingMaskIntoConstraints = NO;
    [dimmingControl addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dimmingControl];

    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.backgroundColor = [UIColor whiteColor];
    cardView.layer.cornerRadius = 12;
    [self.view addSubview:cardView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Scan to join";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = AVQRColor(0x212121);
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UIView *qrContainer = [[UIView alloc] init];
    qrContainer.translatesAutoresizingMaskIntoConstraints = NO;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = AVQRColor(0x757575);
    [self.spinner startAnimating];
    [qrContainer addSubview:self.spinner];

    self.qrImageView = [[UIImageView alloc] init];
    self.qrImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    // Aspect-fit may resample; keep module edges hard so the code still scans.
    self.qrImageView.layer.magnificationFilter = kCAFilterNearest;
    self.qrImageView.accessibilityLabel = @"Referral QR code";
    self.qrImageView.hidden = YES;
    [qrContainer addSubview:self.qrImageView];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.font = [UIFont systemFontOfSize:14];
    self.errorLabel.textColor = AVQRColor(0xB00020);
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [qrContainer addSubview:self.errorLabel];

    self.codeLabel = [[UILabel alloc] init];
    self.codeLabel.font = [UIFont boldSystemFontOfSize:16];
    self.codeLabel.textColor = AVQRColor(0x212121);
    self.codeLabel.textAlignment = NSTextAlignmentCenter;
    self.codeLabel.hidden = YES;

    self.shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.shareButton.backgroundColor = AVQRColor(0x2196F3);
    self.shareButton.layer.cornerRadius = 6;
    self.shareButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [self.shareButton setTitle:@"Share" forState:UIControlStateNormal];
    [self.shareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    self.shareButton.hidden = YES;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [closeButton setTitleColor:AVQRColor(0x757575) forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, qrContainer, self.codeLabel, self.shareButton, closeButton]];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    [stackView setCustomSpacing:16 afterView:titleLabel];
    [stackView setCustomSpacing:12 afterView:qrContainer];
    [stackView setCustomSpacing:16 afterView:self.codeLabel];
    [stackView setCustomSpacing:4 afterView:self.shareButton];
    [cardView addSubview:stackView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *preferredWidth = [cardView.widthAnchor constraintEqualToAnchor:safeArea.widthAnchor constant:-40];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [dimmingControl.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dimmingControl.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [dimmingControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dimmingControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [cardView.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [cardView.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
        [cardView.widthAnchor constraintLessThanOrEqualToConstant:400],
        [cardView.widthAnchor constraintLessThanOrEqualToAnchor:safeArea.widthAnchor constant:-40],
        preferredWidth,

        [stackView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:20],
        [stackView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-20],
        [stackView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [stackView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],

        [qrContainer.heightAnchor constraintEqualToConstant:AVQRCodeSize],
        [self.spinner.centerXAnchor constraintEqualToAnchor:qrContainer.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:qrContainer.centerYAnchor],
        [self.qrImageView.topAnchor constraintEqualToAnchor:qrContainer.topAnchor],
        [self.qrImageView.bottomAnchor constraintEqualToAnchor:qrContainer.bottomAnchor],
        [self.qrImageView.leadingAnchor constraintEqualToAnchor:qrContainer.leadingAnchor],
        [self.qrImageView.trailingAnchor constraintEqualToAnchor:qrContainer.trailingAnchor],
        [self.errorLabel.centerYAnchor constraintEqualToAnchor:qrContainer.centerYAnchor],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:qrContainer.leadingAnchor constant:12],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:qrContainer.trailingAnchor constant:-12],

        [self.shareButton.heightAnchor constraintEqualToConstant:44],
        [closeButton.heightAnchor constraintEqualToConstant:44],
    ]];

    [self loadQRCode];
}

- (void)loadQRCode
{
    __weak typeof(self) weakSelf = self;
    // Captured separately so the client still hears the outcome if the popup was closed first.
    void (^completion)(NSError *) = self.completion;
    self.completion = nil;
    [AppVirality loadQRCodeWithSize:AVQRCodeSize completion:^(UIImage *image, NSDictionary *campaignDetails, NSError *error) {
        [weakSelf showQRImage:image campaignDetails:campaignDetails error:error];
        if (completion) {
            completion(image ? nil : error);
        }
    }];
}

- (void)showQRImage:(UIImage *)image campaignDetails:(NSDictionary *)campaignDetails error:(NSError *)error
{
    [self.spinner stopAnimating];
    if (!image) {
        self.errorLabel.text = error.localizedFailureReason.length ? error.localizedFailureReason : @"Could not generate the QR code.";
        self.errorLabel.hidden = NO;
        return;
    }
    self.qrImage = image;
    self.qrImageView.image = image;
    self.qrImageView.hidden = NO;
    self.shareButton.hidden = NO;

    NSString *referralCode = [campaignDetails valueForKey:@"referralcode"];
    if ([referralCode isKindOfClass:[NSString class]] && referralCode.length > 0) {
        self.codeLabel.text = referralCode;
        self.codeLabel.hidden = NO;
    }
}

- (void)shareTapped
{
    [AppVirality shareQRCodeImage:self.qrImage fromViewController:self];
}

- (void)closeTapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
