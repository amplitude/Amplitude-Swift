#import "AppDelegate.h"
@import AmplitudeSwift;
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/ASIdentifierManager.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions3:(NSDictionary *)launchOptions {
    AMPConfiguration* configuration = [AMPConfiguration initWithApiKey:@"YOUR-API-KEY"];
    configuration.defaultTracking.sessions = true;
    Amplitude* amplitude = [Amplitude initWithConfiguration:configuration];
    
    NSString* eventType = @"Button Clicked";
    NSDictionary* eventProperties = @{@"key": @"value"};
    //AMPBaseEvent* event = [AMPBaseEvent initWithEventType:eventType eventProperties:eventProperties];
    //[amplitude track:event];
    
    NSNumber* timestamp = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
    //AMPBaseEvent* event = [AMPBaseEvent initWithEventType:eventType];
    //event.timestamp = [timestamp longLongValue];
    //[amplitude track:event];
    
    AMPBaseEvent* event = [AMPBaseEvent initWithEventType:eventType eventProperties:eventProperties];
    [event.groups set:@"orgId" value:@"10"];
    [amplitude track:event];
 
    [amplitude flush];
    
    NSString* userId = @"TEST-USER-ID";
    [amplitude setUserId:userId];
    
    NSString* deviceId = @"TEST-DEVICE-ID";
    [amplitude setDeviceId:deviceId];
 
    //[amplitude setSessionId:[timestamp longLongValue]];
    
    AMPIdentify* identify = [AMPIdentify new];
    [identify clearAll];
    [amplitude identify:identify];
    
    // AMPIdentify* identify = [AMPIdentify new];
    [identify set:@"membership" value:@"paid"];
    [identify set:@"payment" value:@"bank"];
    [amplitude identify:identify];
    
    [identify set:@"membership" value:@"paid"];
    [amplitude identify:identify];
    
    [amplitude groupIdentify:@"TEST-GROUP-TYPE" groupName:@"TEST-GROUP-NAME" identify:identify];
    
    AMPRevenue* revenue = [AMPRevenue new];
    revenue.productId = @"productidentifier";
    revenue.quantity = 3;
    revenue.price = 3.99;
    [amplitude revenue:revenue];
    
    configuration.callback = ^(AMPBaseEvent* _Nonnull event, NSInteger code, NSString* _Nonnull message) {
        NSLog(@"eventCallback: %@, code: %@, message: %@", event.eventType, @(code), message);
    };
   
    event.callback = ^(AMPBaseEvent* _Nonnull event, NSInteger code, NSString* _Nonnull message) {
        NSLog(@"eventCallback: %@, code: %@, message: %@", event.eventType, @(code), message);
    };
    
    [amplitude track:event callback:^(AMPBaseEvent* _Nonnull event, NSInteger code, NSString* _Nonnull message) {
        NSLog(@"eventCallback: %@, code: %@, message: %@", event.eventType, @(code), message);
    }];
    
    configuration.migrateLegacyData = false;
   
    
    [amplitude add:[AMPPlugin initWithType:AMPPluginTypeEnrichment execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        ATTrackingManagerAuthorizationStatus status = ATTrackingManager.trackingAuthorizationStatus;
 
        // fallback to the IDFV value.
        // this is also sent in event.context.device.id,
        // feel free to use a value that is more useful to you.
        NSUUID* idfaUUID = [UIDevice currentDevice].identifierForVendor;
        
        if (status == ATTrackingManagerAuthorizationStatusAuthorized) {
            idfaUUID = [ASIdentifierManager sharedManager].advertisingIdentifier;
        }
        
        NSString* idfa = (idfaUUID != nil) ? idfaUUID.UUIDString : nil;

        // The idfa on simulator is always 00000000-0000-0000-0000-000000000000
        event.idfa = idfa;
        // If you want to use idfa for the device_id
        event.deviceId = idfa;
        return event;
    }]];
    
    return true;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSString* apiKey = @"API-KEY";
    AMPConfiguration* configuration = [AMPConfiguration initWithApiKey:apiKey];
    configuration.logLevel = AMPLogLevelLOG;
    configuration.serverZone = AMPServerZoneUS;
    configuration.defaultTracking = AMPDefaultTrackingOptions.ALL;
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
