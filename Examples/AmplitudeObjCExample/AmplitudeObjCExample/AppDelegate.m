#import "AppDelegate.h"
@import AmplitudeSwift;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSString* apiKey = @"API-KEY";
    AMPConfiguration* configuration = [AMPConfiguration initWithApiKey:apiKey];
    configuration.logLevel = AMPLogLevelLOG;
    configuration.serverZone = AMPServerZoneUS;
    AMPAutocaptureOptions* autocaptureOptions = [AMPAutocaptureOptions new];
    autocaptureOptions.sessions = YES;
    autocaptureOptions.appLifecycles = YES;
    autocaptureOptions.screenViews = YES;
    autocaptureOptions.elementInteractions = YES;
    configuration.autocapture = autocaptureOptions;
    configuration.loggerProvider = ^(NSInteger logLevel, NSString* _Nonnull message) {
        NSLog(@"%@", message);
    };
    Amplitude* amplitude = [Amplitude initWithConfiguration:configuration];
    
    [amplitude add:[AMPPlugin initWithType:AMPPluginTypeBefore execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [event.eventProperties set:@"plugin-prop" value:@234];
        event.locationLat = 34;
        event.locationLng = 78;
        return event;
    }]];
    
    NSMutableArray<AMPBaseEvent*>* collectedEvents = [NSMutableArray array];
    [amplitude add:[AMPPlugin initWithType:AMPPluginTypeDestination execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [collectedEvents addObject:event];
        return nil;
    } flush:^() {
        NSLog(@"Plugin Flush: %lu events", (unsigned long)collectedEvents.count);
        [collectedEvents removeAllObjects];
    }]];
    
    [amplitude setUserId:@"User-ObjC"];
    
    AMPIdentify* identify = [AMPIdentify new];
    [identify set:@"user-prop-1" value:@"value-1"];
    [identify set:@"user-prop-2" value:@123];
    [amplitude identify:identify];
    
    [amplitude setGroup:@"orgName" groupName:@"Test Org"];
    
    AMPIdentify* groupIdentify = [AMPIdentify new];
    [groupIdentify set:@"group-prop-1" value:@"value-A"];
    [groupIdentify set:@"group-prop-2" value:@true];
    [amplitude groupIdentify:@"orgName" groupName:@"Test Org" identify:groupIdentify];

    [amplitude track:@"Event-A" eventProperties:@{
        @"prop-string": @"value-A",
        @"prop-int": @111,
        @"prop-string-array": @[@"item-1", @"item-2"]
    }];
    
    AMPBaseEvent* event = [AMPBaseEvent initWithEventType:@"Event-B"];
    event.appVersion = @"1.2.3";
    
    [amplitude track:event callback:^(AMPBaseEvent* _Nonnull event, NSInteger code, NSString* _Nonnull message) {
        NSLog(@"%@ - %@", event.eventType, message);
    }];
    
    AMPBaseEvent* deepLinkOpenedEvent = [AMPDeepLinkOpenedEvent initWithUrl:@"http://example.com" referrer:@"https://referrer.com"];
    [amplitude track:deepLinkOpenedEvent];
    
    AMPBaseEvent* screenViewedEvent = [AMPScreenViewedEvent initWithScreenName:@"Settings"];
    [amplitude track:screenViewedEvent];
    
    [amplitude flush];
    
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
