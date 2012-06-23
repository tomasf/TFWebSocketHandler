//
//  TFWebSocketHandler.h
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-06-30.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import <WebAppKit/WebAppKit.h>
#import "TFWebSocketConnection.h"


@interface TFWebSocketHandler : WARequestHandler
- (id)initWithPath:(NSString*)requestPath subprotocols:(NSSet*)subprotocolNames;

@property(copy) BOOL(^originHandler)(NSString *originString);
@property(copy) void(^connectionHandler)(TFWebSocketConnection *connection);
@end