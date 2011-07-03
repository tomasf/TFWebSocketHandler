//
//  TFWebSocketConnection.h
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-06-30.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	TFWebSocketCloseCodeUnspecified = 0,
	
	TFWebSocketCloseCodeNormal = 1000,
	TFWebSocketCloseCodeGoingAway = 1001,
	TFWebSocketCloseCodeProtocolError = 1002,
	TFWebSocketCloseCodeUnsupportedData = 1003,
	TFWebSocketCloseCodeFrameTooLarge = 1004,
	TFWebSocketCloseCodeNoStatusReceived = 1005,
	TFWebSocketCloseCodeAbnormal = 1006,
};

typedef uint16_t TFWebSocketCloseCode;

@interface TFWebSocketConnection : NSObject {
	WARequest *request;
	WAResponse *response;
	GCDAsyncSocket *socket;
	
	NSString *subprotocol;
	
	void(^textMessageHandler)(NSString *text);
	void(^dataMessageHandler)(NSData *data);
	void(^closeHandler)(TFWebSocketCloseCode code, NSString *reason);
	void(^pongHandler)();
}

@property(readonly) NSString *origin;
@property(readonly) NSString *subprotocol;

@property(readonly) BOOL supportsPing;
@property(readonly) BOOL supportsDataMessages;

@property(copy) void(^textMessageHandler)(NSString *text);
@property(copy) void(^dataMessageHandler)(NSData *data);
@property(copy) void(^closeHandler)(TFWebSocketCloseCode code, NSString *reason);
@property(copy) void(^pongHandler)();

- (void)close;
- (void)closeWithCode:(TFWebSocketCloseCode)code;
- (void)closeWithCode:(TFWebSocketCloseCode)code reason:(NSString*)reason;

- (void)sendTextMessage:(NSString*)text;
- (void)sendDataMessage:(NSData*)data;
- (void)ping;

@end