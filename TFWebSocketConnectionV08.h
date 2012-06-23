//
//  TFWebSocketConnectionV08.h
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-07-03.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnection.h"

typedef int TFWebSocketOpcode;

enum {
	TFWebSocketOpcodeInvalid = -1,
	
    TFWebSocketOpcodeContinuation = 0x0,
    TFWebSocketOpcodeText = 0x1,
    TFWebSocketOpcodeBinary = 0x2,
	
    TFWebSocketOpcodeClose = 0x8,
    TFWebSocketOpcodePing = 0x9,
    TFWebSocketOpcodePong = 0xA,
};

typedef struct {uint8_t bytes[4];} TFWebSocketMaskingKey;

typedef struct {
    BOOL FIN;
    BOOL RSV[3];
    TFWebSocketOpcode opcode;
    BOOL masked;
    uint64_t payloadLength;
    TFWebSocketMaskingKey maskingKey;
} TFWebSocketFrameHeader;


// draft-ietf-hybi-thewebsocketprotocol-10
@interface TFWebSocketConnectionV08 : TFWebSocketConnection
@end
