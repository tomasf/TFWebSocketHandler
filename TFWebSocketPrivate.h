/*
 *  TFWebSocketPrivate.h
 *  TFWebSocketHandler
 *
 *  Created by Tomas Franzén on 2011-06-30.
 *  Copyright 2011 Lighthead Software. All rights reserved.
 *
 */

#import "TFWebSocketConnection.h"

@interface TFWebSocketConnection (Private)
+ (BOOL)validateRequest:(WARequest*)request;
- (id)initWithRequest:(WARequest*)req response:(WAResponse*)resp socket:(GCDAsyncSocket*)sock;
- (void)startWithAvailableSubprotocols:(NSSet*)serverProtocols;
+ (NSArray*)valuesInHTTPTokenListString:(NSString*)string;
@end


@interface WAResponse (TFWSPrivate)
- (void)sendHeader;
- (id)initWithRequest:(WARequest*)req socket:(GCDAsyncSocket*)sock completionHandler:(void(^)(BOOL keepAlive))handler;
@end


const NSUInteger TFWebSocketMaxFramePayloadSize;
const NSUInteger TFWebSocketMaxMessageBodySize;