#import <XCTest/XCTest.h>
@import AmplitudeSwift;

@interface AmplitudeObjCExampleTests : XCTestCase

@end

@implementation AmplitudeObjCExampleTests

- (void)testTrack {
    Amplitude* amplitude = [self getAmplitude:@"track"];
    
    NSDictionary* eventProperties = @{
        @"prop-string": @"string-value",
        @"prop-int": @111,
        @"prop-number": @12.3,
        @"prop-boolean": @true,
        @"prop-string-array": @[@"item-1", @"item-2"],
        @"prop-int-array": @[@1, @2, @3],
        @"prop-number-array": @[@1.1, @2.2, @3.3],
        @"prop-bool-array": @[@true, @false, @true],
        @"prop-object": @{@"nested-prop-1": @555, @"nested-prop-2": @"nested-string"}
    };
    [amplitude track:@"Event-A" eventProperties:eventProperties];
    
    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"Event-A", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(eventProperties, [events[0] objectForKey:@"event_properties"]);
}

- (void)testTrack_Options {
    Amplitude* amplitude = [self getAmplitude:@"track_options"];
    
    AMPEventOptions* eventOptions = [AMPEventOptions new];
    eventOptions.locationLat = 12;
    eventOptions.locationLng = 34;
    NSDictionary* eventProperties = @{
        @"prop-string": @"string-value",
        @"prop-int": @111
    };
    [amplitude track:@"Event-A" eventProperties:eventProperties options:eventOptions];
    
    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"Event-A", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(eventProperties, [events[0] objectForKey:@"event_properties"]);
    XCTAssertEqualObjects(@12, [events[0] objectForKey:@"location_lat"]);
    XCTAssertEqualObjects(@34, [events[0] objectForKey:@"location_lng"]);
}

- (void)testIdentify {
    Amplitude* amplitude = [self getAmplitude:@"identify"];
    
    AMPIdentify* identify = [AMPIdentify new];
    [identify set:@"user-string-prop" value:@"string-value"];
    [identify setOnce:@"user-int-prop" value:@111];
    [identify append:@"user-number-prop" value:@123.4];
    [identify prepend:@"user-bool-prop" value:@true];
    [identify add:@"user-sum-prop" valueInt:7];
    [identify remove:@"user-agg-prop" value: @"item1"];
    [identify unset:@"user-deprecated-prop"];
    [amplitude identify:identify];
    
    NSDictionary* expectedUserProperties = @{
        @"$set": @{@"user-string-prop": @"string-value"},
        @"$set_once": @{@"user-int-prop": @111},
        @"$append": @{@"user-number-prop": @123.4},
        @"$prepend": @{@"user-bool-prop": @true},
        @"$add": @{@"user-sum-prop": @7},
        @"$remove": @{@"user-agg-prop": @"item1"},
        @"$unset": @{@"user-deprecated-prop": @"-"}
    };

    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"$identify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(expectedUserProperties, [events[0] objectForKey:@"user_properties"]);
}

- (void)testIdentify_ClearAll {
    Amplitude* amplitude = [self getAmplitude:@"identify-clearAll"];
    
    AMPIdentify* identify = [AMPIdentify new];
    [identify clearAll];
    [amplitude identify:identify];
    
    NSDictionary* expectedUserProperties = @{
        @"$clearAll": @"-"
    };

    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"$identify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(expectedUserProperties, [events[0] objectForKey:@"user_properties"]);
}

- (void)testIdentify_InterceptedIdentifies {
    Amplitude* amplitude = [self getAmplitude:@"identify-interceptedIdentifies"];
    
    AMPIdentify* identify1 = [AMPIdentify new];
    [identify1 set:@"user-string-prop" value:@"string-value"];
    [amplitude identify:identify1];
    
    AMPIdentify* identify2 = [AMPIdentify new];
    [identify2 set:@"user-int-prop" value:@111];
    [amplitude identify:identify2];

    NSDictionary* expectedUserProperties1 = @{
        @"$set": @{@"user-string-prop": @"string-value"}
    };

    NSDictionary* expectedUserProperties2 = @{
        @"$set": @{@"user-int-prop": @111}
    };

    NSArray<NSString*>* eventsStrings = [amplitude.storage getInterceptedIdentifiesStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 2);
    XCTAssertEqualObjects(@"$identify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(expectedUserProperties1, [events[0] objectForKey:@"user_properties"]);
    XCTAssertEqualObjects(@"$identify", [events[1] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(expectedUserProperties2, [events[1] objectForKey:@"user_properties"]);
}

- (void)testGroupIdentify {
    Amplitude* amplitude = [self getAmplitude:@"groupIdentify"];
    
    AMPIdentify* identify = [AMPIdentify new];
    [identify set:@"user-string-prop" value:@"string-value"];
    [identify setOnce:@"user-int-prop" value:@111];
    [identify append:@"user-number-prop" value:@123.4];
    [identify prepend:@"user-bool-prop" value:@true];
    [identify add:@"user-sum-prop" valueInt:7];
    [identify remove:@"user-agg-prop" value: @"item1"];
    [identify unset:@"user-deprecated-prop"];
    [amplitude groupIdentify:@"type-1" groupName:@"name-1" identify:identify];
    
    NSDictionary* expectedGroupProperties = @{
        @"$set": @{@"user-string-prop": @"string-value"},
        @"$set_once": @{@"user-int-prop": @111},
        @"$append": @{@"user-number-prop": @123.4},
        @"$prepend": @{@"user-bool-prop": @true},
        @"$add": @{@"user-sum-prop": @7},
        @"$remove": @{@"user-agg-prop": @"item1"},
        @"$unset": @{@"user-deprecated-prop": @"-"}
    };

    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"$groupidentify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(@{@"type-1": @"name-1"}, [events[0] objectForKey:@"groups"]);
    XCTAssertEqualObjects(expectedGroupProperties, [events[0] objectForKey:@"group_properties"]);
}

- (void)testSetGroup {
    Amplitude* amplitude = [self getAmplitude:@"setGroup"];
    
    NSString* groupName = @"name-1";
    [amplitude setGroup:@"type-1" groupName:groupName];
    
    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"$identify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(@{@"type-1": groupName}, [events[0] objectForKey:@"groups"]);
    XCTAssertEqualObjects(@{@"$set": @{@"type-1": groupName}}, [events[0] objectForKey:@"user_properties"]);
}

- (void)testSetGroup_Multiple {
    Amplitude* amplitude = [self getAmplitude:@"setGroup_Multiple"];
    
    NSArray<NSString*>* groupNames = @[@"name-1", @"name-2"];
    [amplitude setGroup:@"type-1" groupNames:groupNames];
    
    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"$identify", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(@{@"type-1": groupNames}, [events[0] objectForKey:@"groups"]);
    XCTAssertEqualObjects(@{@"$set": @{@"type-1": groupNames}}, [events[0] objectForKey:@"user_properties"]);
}

- (void)testPlugin {
    Amplitude* amplitude = [self getAmplitude:@"plugin"];
    [amplitude add:[AMPPlugin initWithType:AMPPluginTypeBefore execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [event.eventProperties set:@"plugin-prop" value:@"plugin-value"];
        event.locationLat = 12;
        event.locationLng = 34;
        return event;
    }]];
   
    [amplitude track:@"Event-A" eventProperties:@{
        @"prop-string": @"string-value",
        @"prop-int": @111
    }];
    
    NSDictionary* expectedEventProperties = @{
        @"prop-string": @"string-value",
        @"prop-int": @111,
        @"plugin-prop": @"plugin-value"
    };

    NSArray<NSString*>* eventsStrings = [amplitude.storage getEventsStrings];
    NSArray* events = [self parseEvents:eventsStrings];
    XCTAssertEqual(events.count, 1);
    XCTAssertEqualObjects(@"Event-A", [events[0] objectForKey:@"event_type"]);
    XCTAssertEqualObjects(expectedEventProperties, [events[0] objectForKey:@"event_properties"]);
    XCTAssertEqualObjects(@12, [events[0] objectForKey:@"location_lat"]);
    XCTAssertEqualObjects(@34, [events[0] objectForKey:@"location_lng"]);
}

- (void)testDestinationPlugin {
    XCTestExpectation* expectation = [self expectationWithDescription:@"flush"];
    NSMutableArray<AMPBaseEvent*>* collectedEvents = [NSMutableArray array];
    
    Amplitude* amplitude = [self getAmplitude:@"plugin"];
    [amplitude add:[AMPPlugin initWithType:AMPPluginTypeDestination execute:^AMPBaseEvent* _Nullable(AMPBaseEvent* _Nonnull event) {
        [collectedEvents addObject:event];
        return nil;
    } flush:^() {
        [expectation fulfill];
    }]];
   
    [amplitude track:@"Event-A" eventProperties:nil];
    [amplitude track:@"Event-B" eventProperties:nil];
    [amplitude track:@"Event-C" eventProperties:nil];
    
    [amplitude flush];
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError* error) {
        if (error) {
            XCTFail("Expectation failed with error: %@", error);
        }
    }];
    
    XCTAssertEqual(collectedEvents.count, 3);
    XCTAssertEqualObjects(@"Event-A", [collectedEvents objectAtIndex:0].eventType);
    XCTAssertEqualObjects(@"Event-B", [collectedEvents objectAtIndex:1].eventType);
    XCTAssertEqualObjects(@"Event-C", [collectedEvents objectAtIndex:2].eventType);
}

- (void)testEventProperties {
    AMPBaseEvent* event = [AMPBaseEvent initWithEventType:@"Event-A" eventProperties:@{@"prop-1": @"123"}];
    [event.eventProperties set:@"prop-2" value:@111];
    XCTAssertEqualObjects(@"123", [event.eventProperties get:@"prop-1"]);
    XCTAssertEqualObjects(@111, [event.eventProperties get:@"prop-2"]);
    [event.eventProperties remove:@"prop-1"];
    XCTAssertEqualObjects(nil, [event.eventProperties get:@"prop-1"]);
    XCTAssertEqualObjects(@111, [event.eventProperties get:@"prop-2"]);
}

- (Amplitude *)getAmplitude:(NSString *)instancePrefix {
    NSString* instanceName = [NSString stringWithFormat:@"%@-%f", instancePrefix, [[NSDate date] timeIntervalSince1970]];
    AMPConfiguration* configuration = [AMPConfiguration initWithApiKey:@"API-KEY" instanceName:instanceName];
    configuration.defaultTracking = AMPDefaultTrackingOptions.NONE;
    Amplitude* amplitude = [Amplitude initWithConfiguration:configuration];
    return amplitude;
}

- (NSArray *)parseEvents:(NSArray<NSString*>*)eventsStrings {
    XCTAssertEqual(1, eventsStrings.count);
    NSError* jsonError = nil;
    NSData* data = [eventsStrings[0] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* events = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
    XCTAssertNil(jsonError);
    return events;
}

@end
