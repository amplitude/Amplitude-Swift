#import "AppDelegate.h"
@import AmplitudeSwift;
@import AmplitudeCore;

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSString* apiKey = @"API-KEY";
    AMPConfiguration* configuration = [AMPConfiguration initWithApiKey:apiKey];
    configuration.logLevel = AMPLogLevelLOG;
    configuration.serverZone = AMPServerZoneUS;
    NSArray<AMPAutocaptureOptions *> *autocaptureOptions = @[
        AMPAutocaptureOptions.sessions,
        AMPAutocaptureOptions.appLifecycles,
        AMPAutocaptureOptions.screenViews,
        AMPAutocaptureOptions.networkTracking,
        AMPAutocaptureOptions.frustrationInteractions,
    ];
    configuration.autocapture = [[AMPAutocaptureOptions alloc] initWithOptionsToUnion:autocaptureOptions];
    configuration.loggerProvider = ^(NSInteger logLevel, NSString* _Nonnull message) {
        NSLog(@"%@", message);
    };

    AMPNetworkTrackingOptions *networkTrackingOptions = AMPNetworkTrackingOptions.defaultOptions;
    NSMutableArray<AMPNetworkTrackingCaptureRule *> *rules = [networkTrackingOptions.captureRules mutableCopy];
    [rules addObject:[[AMPNetworkTrackingCaptureRule alloc] initWithHosts:@[@"httpstat.us"] statusCodeRange:@"0,400-599"]];
    networkTrackingOptions.captureRules = rules;
    configuration.networkTrackingOptions = networkTrackingOptions;

    AMPRageClickOptions *rageClickOptions = [[AMPRageClickOptions alloc] initWithEnabled:YES];
    AMPDeadClickOptions *deadClickOptions = [[AMPDeadClickOptions alloc] initWithEnabled: NO];
    AMPInteractionsOptions *interactionsOptions = [[AMPInteractionsOptions alloc] initWithRageClick:rageClickOptions deadClick:deadClickOptions];
    configuration.interactionsOptions = interactionsOptions;

    self.amplitude = [Amplitude initWithConfiguration:configuration];

    [self.amplitude add:[AMPPlugin initWithType:AMPPluginTypeBefore execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [event.eventProperties set:@"plugin-prop" value:@234];
        event.locationLat = 34;
        event.locationLng = 78;
        return event;
    }]];
    
    NSMutableArray<AMPBaseEvent*>* collectedEvents = [NSMutableArray array];
    [self.amplitude add:[AMPPlugin initWithType:AMPPluginTypeDestination execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [collectedEvents addObject:event];
        return nil;
    } flush:^() {
        NSLog(@"Plugin Flush: %lu events", (unsigned long)collectedEvents.count);
        [collectedEvents removeAllObjects];
    }]];
    
    [self.amplitude setUserId:@"User-ObjC"];

    AMPIdentify* identify = [AMPIdentify new];
    [identify set:@"user-prop-1" value:@"value-1"];
    [identify set:@"user-prop-2" value:@123];
    [self.amplitude identify:identify];

    [self.amplitude setGroup:@"orgName" groupName:@"Test Org"];
    
    AMPIdentify* groupIdentify = [AMPIdentify new];
    [groupIdentify set:@"group-prop-1" value:@"value-A"];
    [groupIdentify set:@"group-prop-2" value:@true];
    [self.amplitude groupIdentify:@"orgName" groupName:@"Test Org" identify:groupIdentify];

    [self.amplitude track:@"Event-A" eventProperties:@{
        @"prop-string": @"value-A",
        @"prop-int": @111,
        @"prop-string-array": @[@"item-1", @"item-2"]
    }];
    
    AMPBaseEvent* event = [AMPBaseEvent initWithEventType:@"Event-B"];
    event.appVersion = @"1.2.3";
    
    [self.amplitude track:event callback:^(AMPBaseEvent* _Nonnull event, NSInteger code, NSString* _Nonnull message) {
        NSLog(@"%@ - %@", event.eventType, message);
    }];
    
    AMPBaseEvent* deepLinkOpenedEvent = [AMPDeepLinkOpenedEvent initWithUrl:@"http://example.com" referrer:@"https://referrer.com"];
    [self.amplitude track:deepLinkOpenedEvent];
    
    AMPBaseEvent* screenViewedEvent = [AMPScreenViewedEvent initWithScreenName:@"Settings"];
    [self.amplitude track:screenViewedEvent];
    
    [self.amplitude flush];
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
