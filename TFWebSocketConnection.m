//
//  TFWebSocketConnection.m
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-06-30.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnection.h"
#import "TFWebSocketPrivate.h"
#import "GCDAsyncSocket.h"

const NSUInteger TFWebSocketMaxFramePayloadSize = 100000;
const NSUInteger TFWebSocketMaxMessageBodySize = 300000;

@interface TFWebSocketConnection ()
@property(copy, readwrite) NSString *subprotocol;
@end



@implementation TFWebSocketConnection
@synthesize subprotocol=_subprotocol;
@synthesize textMessageHandler=_textMessageHandler;
@synthesize dataMessageHandler=_dataMessageHandler;
@synthesize closeHandler=_closeHandler;
@synthesize pongHandler=_pongHandler;
@synthesize request=_request;
@synthesize response=_response;
@synthesize socket=_socket;
@synthesize handshakeHandler=_handshakeHandler;


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

- (id)initWithRequest:(WARequest*)request response:(WAResponse*)response socket:(GCDAsyncSocket*)socket {
	if(!(self = [super init])) return nil;
	
	self.request = request;
	self.response = response;
	self.socket = socket;
	[self.socket setDelegate:self];
	
	return self;
}


- (NSString*)origin {
	return nil;
}

- (NSArray*)clientSubprotocols {
	return nil;
}

- (NSString*)preferredSubprotocolAmong:(NSSet*)serverProtocols {
	if([[self clientSubprotocols] count] == 0) return nil;
	
	for(NSString *protocol in [self clientSubprotocols]) {
		if([serverProtocols containsObject:protocol]) return protocol;
	}
	return [serverProtocols anyObject];
}

- (void)startWithAvailableSubprotocols:(NSSet*)serverProtocols {
	serverProtocols = [serverProtocols valueForKey:@"lowercaseString"];
	self.subprotocol = [self preferredSubprotocolAmong:serverProtocols];
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