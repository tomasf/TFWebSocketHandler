//
//  TFWebSocketHandler.m
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-06-30.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketHandler.h"
#import "TFWebSocketConnectionV00.h"
#import "TFWebSocketConnectionV08.h"
#import "TFWebSocketPrivate.h"


@interface TFWebSocketHandler ()
@property(copy) NSString *path;
@property(copy) NSSet *subprotocols;
@property(strong) NSMutableSet *pendingConnections;
@end



@implementation TFWebSocketHandler
@synthesize originHandler=_originHandler;
@synthesize connectionHandler=_connectionHandler;
@synthesize path=_path;
@synthesize subprotocols=_subprotocols;
@synthesize pendingConnections=_pendingConnections;


- (id)initWithPath:(NSString*)requestPath subprotocols:(NSSet*)subprotocolNames {
	if(!(self = [super init])) return nil;

	self.path = requestPath;
	self.subprotocols = subprotocolNames;
	self.pendingConnections = [NSMutableSet set];

	return self;
}


- (Class)connectionClassForRequest:(WARequest*)request {
	NSString *version = [request valueForHeaderField:@"Sec-Websocket-Version"];
	
	if([version isEqual:@"7"] || [version isEqual:@"8"] || [version isEqual:@"13"]) return [TFWebSocketConnectionV08 class];
	else if(version == nil) return [TFWebSocketConnectionV00 class];
	else return Nil;
}


- (BOOL)canHandleRequest:(WARequest *)req {
	if(![req.method isEqual:@"GET"] || ![req.path isEqual:self.path]) return NO;
	Class connectionClass = [self connectionClassForRequest:req];
	if(!connectionClass) return NO;
	return [connectionClass validateRequest:req];	
}


- (void)handleRequest:(WARequest *)request response:(WAResponse *)response socket:(GCDAsyncSocket *)socket {
	Class connectionClass = [self connectionClassForRequest:request];
	TFWebSocketConnection *connection = [[connectionClass alloc] initWithRequest:request response:response socket:socket];
	
	if(self.originHandler) {
		NSString *origin = [connection origin];	
		BOOL accept = self.originHandler(origin);
		if(!accept) {
			response.statusCode = 403;
			[response finish];
			return;
		}
	}
	
	[self.pendingConnections addObject:connection];
	__weak TFWebSocketHandler *weakSelf = self;
	__weak TFWebSocketConnection *weakConnection = connection;
	
	connection.handshakeHandler = ^(BOOL success){
		if(success) {
			weakSelf.connectionHandler(weakConnection);
		}
		[weakSelf.pendingConnections removeObject:weakConnection];
	};
	[connection startWithAvailableSubprotocols:self.subprotocols];
}


@end