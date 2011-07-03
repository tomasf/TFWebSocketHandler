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

@implementation TFWebSocketHandler
@synthesize originHandler, connectionHandler;


- (id)initWithPath:(NSString*)requestPath subprotocols:(NSSet*)subprotocolNames {
	if(!(self = [super init])) return nil;

	path = [requestPath copy];
	subprotocols = [subprotocolNames copy];

	return self;
}


- (Class)connectionClassForRequest:(WARequest*)request {
	NSString *version = [request valueForHeaderField:@"Sec-Websocket-Version"];
	
	if([version isEqual:@"7"] || [version isEqual:@"8"]) return [TFWebSocketConnectionV08 class];
	else if(version == nil) return [TFWebSocketConnectionV00 class];
	else return Nil;
}


- (BOOL)canHandleRequest:(WARequest *)req {
	if(![req.method isEqual:@"GET"] || ![req.path isEqual:path]) return NO;
	Class connectionClass = [self connectionClassForRequest:req];
	if(!connectionClass) return NO;
	return [connectionClass validateRequest:req];	
}


- (void)handleRequest:(WARequest *)request response:(WAResponse *)response socket:(GCDAsyncSocket *)socket {
	Class connectionClass = [self connectionClassForRequest:request];
	TFWebSocketConnection *connection = [[connectionClass alloc] initWithRequest:request response:response socket:socket];
	
	if(originHandler) {
		NSString *origin = [connection origin];	
		BOOL accept = originHandler(origin);
		if(!accept) {
			response.statusCode = 403;
			[response finish];
			return;
		}
	}
	
	[connection startWithAvailableSubprotocols:subprotocols];
	if(connectionHandler) connectionHandler(connection);
}


@end