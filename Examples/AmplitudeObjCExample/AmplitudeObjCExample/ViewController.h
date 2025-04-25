#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (nonatomic, strong) UITextField *responseCodeField;
@property (nonatomic, strong) UITextField *responseDelayField;

- (void)requestNetworkWithResponseCode:(NSString *)responseCode responseDelay:(NSString *)responseDelay;

@end

