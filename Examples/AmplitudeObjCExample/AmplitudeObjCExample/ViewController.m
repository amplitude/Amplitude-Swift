#import "ViewController.h"
#include "AppDelegate.h"
@import AmplitudeSwift;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Main View";

    // Setup Network Tracking Test UI
    [self setupNetworkTrackingTestUI];
}

- (void)setupNetworkTrackingTestUI {
    UILabel *sectionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.frame.size.width - 40, 30)];
    sectionLabel.text = @"NETWORK TRACKING TEST";
    sectionLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.view addSubview:sectionLabel];

    // Response Code Field
    UILabel *responseCodeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, 120, 30)];
    responseCodeLabel.text = @"Response Code:";
    [self.view addSubview:responseCodeLabel];

    self.responseCodeField = [[UITextField alloc] initWithFrame:CGRectMake(150, 140, 200, 30)];
    self.responseCodeField.borderStyle = UITextBorderStyleRoundedRect;
    self.responseCodeField.text = @"500";
    self.responseCodeField.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:self.responseCodeField];

    // Response Delay Field
    UILabel *responseDelayLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 180, 120, 30)];
    responseDelayLabel.text = @"Delay in ms:";
    [self.view addSubview:responseDelayLabel];

    self.responseDelayField = [[UITextField alloc] initWithFrame:CGRectMake(150, 180, 200, 30)];
    self.responseDelayField.borderStyle = UITextBorderStyleRoundedRect;
    self.responseDelayField.text = @"";
    self.responseDelayField.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:self.responseDelayField];

    // Request Network Button
    UIButton *requestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    requestButton.frame = CGRectMake(20, 220, self.view.frame.size.width - 40, 40);
    [requestButton setTitle:@"Request Network" forState:UIControlStateNormal];
    requestButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.46 blue:0.87 alpha:1.0];
    [requestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [requestButton addTarget:self action:@selector(requestNetworkButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:requestButton];

    // Flush Button
    UIButton *flushButton = [UIButton buttonWithType:UIButtonTypeSystem];
    flushButton.frame = CGRectMake(20, 280, self.view.frame.size.width - 40, 40);
    [flushButton setTitle:@"Flush All Events" forState:UIControlStateNormal];
    flushButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.46 blue:0.87 alpha:1.0];
    [flushButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [flushButton addTarget:self action:@selector(flushButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flushButton];
}

- (void)requestNetworkButtonTapped {
    NSString *responseCode = self.responseCodeField.text;
    NSString *responseDelay = self.responseDelayField.text;
    [self requestNetworkWithResponseCode:responseCode responseDelay:responseDelay];
}

- (void)flushButtonTapped {
    NSLog(@"Flushing all events");
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.amplitude flush];
}

- (void)requestNetworkWithResponseCode:(NSString *)responseCode responseDelay:(NSString *)responseDelay {
    NSString *delay = responseDelay.length > 0 ? responseDelay : @"0";
    NSString *urlString = [NSString stringWithFormat:@"https://httpstat.us/%@?sleep=%@#test", responseCode, delay];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 3.0;

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Response: %@", response);
        if (error) {
            NSLog(@"Error: %@", error);
        }
    }];

    [task resume];
    NSLog(@"Request sent: %@", url);
}

@end
