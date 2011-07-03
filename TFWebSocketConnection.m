//
//  TFWebSocketConnection.m
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-06-30.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnection.h"
#import "TFWebSocketPrivate.h"


const NSUInteger TFWebSocketMaxFramePayloadSize = 100000;
const NSUInteger TFWebSocketMaxMessageBodySize = 300000;


@implementation TFWebSocketConnection
@synthesize subprotocol;
@synthesize textMessageHandler, dataMessageHandler, closeHandler, pongHandler;


+ (NSArray*)valuesInHTTPTokenListString:(NSString*)string {
	if(!string) return nil;
	NSArray *components = [string componentsSeparatedByString:@","];
	NSMutableArray *values = [NSMutableArray array];
	for(NSString *component in components)
		[values addObject:[[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString]];
	return values;
}


+ (BOOL)validateRequest:(WARequest*)request {
	if(![[request valueForHeaderField:@"Upgrade"] isCaseInsensitiveLike:@"WebSocket"]) return NO;
	if(![[self valuesInHTTPTokenListString:[request valueForHeaderField:@"Connection"]] containsObject:@"upgrade"]) return NO;
	return YES;
}

- (id)initWithRequest:(WARequest*)req response:(WAResponse*)resp socket:(GCDAsyncSocket*)sock {
	if(!(self = [super init])) return nil;
	
	request = req;
	response = resp;
	socket = sock;
	[socket setDelegate:self];
	
	return self;
}


- (NSString*)origin {
	return nil;
}

- (NSArray*)clientSubprotocols {
	return nil;
}

- (NSString*)preferredSubprotocolAmong:(NSSet*)serverProtocols {
	for(NSString *protocol in [self clientSubprotocols]) {
		if([serverProtocols containsObject:protocol]) return protocol;
	}
	return [serverProtocols anyObject];
}

- (void)startWithAvailableSubprotocols:(NSSet*)serverProtocols {
	serverProtocols = [serverProtocols valueForKey:@"lowercaseString"];
	subprotocol = [[self preferredSubprotocolAmong:serverProtocols] copy];
}

- (BOOL)supportsPing {
	return NO;
}

- (BOOL)supportsDataMessages {
	return NO;
}

- (void)ping {};
- (void)sendDataMessage:(NSData*)data {};
- (void)sendTextMessage:(NSString*)text {};

- (void)close {
	[self closeWithCode:TFWebSocketCloseCodeNormal];
}


- (void)closeWithCode:(TFWebSocketCloseCode)code {
	[self closeWithCode:code reason:nil];
}

- (void)closeWithCode:(TFWebSocketCloseCode)code reason:(NSString*)reason {};

@end







