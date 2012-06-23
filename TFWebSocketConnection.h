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
	TFWebSocketCloseCodeInvalidData = 1007,
	TFWebSocketCloseCodePolicyViolation = 1008,
	TFWebSocketCloseCodeMessageTooBig = 1009,
	TFWebSocketCloseCodeUnsuitableExtension = 1010,
	TFWebSocketCloseCodeUnexpectedCondition = 1011,
};

typedef uint16_t TFWebSocketCloseCode;

@interface TFWebSocketConnection : NSObject

@property(readonly) NSString *origin;
@property(readonly, copy) NSString *subprotocol;

@property(readonly) BOOL supportsPing;
@property(readonly) BOOL supportsDataMessages;

@property(copy) void(^textMessageHandler)(NSString *text);
@property(copy) void(^dataMessageHandler)(NSData *data);
@property(copy) void(^closeHandler)(TFWebSocketCloseCode code, NSString *reason);
@property(copy) void(^pongHandler)();

@property(strong) WARequest *request;
@property(strong) WAResponse *response;
@property(strong) GCDAsyncSocket *socket;

- (void)close;
- (void)closeWithCode:(TFWebSocketCloseCode)code;
- (void)closeWithCode:(TFWebSocketCloseCode)code reason:(NSString*)reason;

- (void)sendTextMessage:(NSString*)text;
- (void)sendDataMessage:(NSData*)data;
- (void)ping;

@property(copy) void(^handshakeHandler)(BOOL success);

@end