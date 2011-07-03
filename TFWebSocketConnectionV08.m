//
//  TFWebSocketConnectionV08.m
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-07-03.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnectionV08.h"
#import "TFWebSocketPrivate.h"
#import <openssl/sha.h>


NSString *const TFWebSocketConnectionV8HandshakeGUID = @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";


@interface TFWebSocketConnectionV08 ()
- (uint8)frameHeaderLengthFromFirstTwoBytes:(uint8_t*)buffer;
- (TFWebSocketFrameHeader)frameHeaderFromData:(NSData*)data;
- (NSData*)dataFromFrameHeader:(TFWebSocketFrameHeader)frame;
- (void)readNewFrame;
- (void)processFrameWithPayload:(NSData*)data;
- (void)pongWithPayload:(NSData*)payload;
- (void)closeAndNotifyForCode:(TFWebSocketCloseCode)code;
@end


enum TFWebSocketConnectionV08ReadTags {
	TFWebSocketTagFrameHeaderStart,
	TFWebSocketTagFrameHeaderRest,
	TFWebSocketTagFramePayload,
};



@implementation TFWebSocketConnectionV08


- (id)initWithRequest:(WARequest*)req response:(WAResponse*)resp socket:(GCDAsyncSocket*)sock {
	if(!(self = [super initWithRequest:req response:resp socket:sock])) return nil;
	bufferedPayloadData = [NSMutableData data];
	return self;
}


- (NSString*)origin {
	return [request valueForHeaderField:@"Sec-WebSocket-Origin"];
}



#pragma mark Socket


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
	if(!closing && closeHandler)
		closeHandler(TFWebSocketCloseCodeUnspecified, nil);
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	if(tag == TFWebSocketTagFrameHeaderStart) { // first two bytes of frame
		uint8_t frameHeaderLength = [self frameHeaderLengthFromFirstTwoBytes:(uint8_t*)[data bytes]];
		partialFrameHeader = [data copy];
		[socket readDataToLength:frameHeaderLength-2 withTimeout:-1 tag:TFWebSocketTagFrameHeaderRest];
	
	}else if(tag == TFWebSocketTagFrameHeaderRest) { // rest of frame header
		NSMutableData *header = [partialFrameHeader mutableCopy];
		[header appendData:data];
		incomingFrameHeader = [self frameHeaderFromData:header];
		if(incomingFrameHeader.payloadLength) {
			if(incomingFrameHeader.payloadLength > TFWebSocketMaxFramePayloadSize) {
				[self closeAndNotifyForCode:TFWebSocketCloseCodeFrameTooLarge];
				return;
			}
			[socket readDataToLength:incomingFrameHeader.payloadLength withTimeout:-1 tag:TFWebSocketTagFramePayload];
		}else{
			[self processFrameWithPayload:nil];
			[self readNewFrame];
		}
	
	}else if(tag == TFWebSocketTagFramePayload) {
		[self processFrameWithPayload:data];
		[self readNewFrame];
	}
}



#pragma mark Connection and handshake


+ (BOOL)validateRequest:(WARequest*)request {
	if(![super validateRequest:request]) return NO;
	if(![request valueForHeaderField:@"Sec-WebSocket-Key"]) return NO;
	return YES;
}


- (NSArray*)clientSubprotocols {
	return [[self class] valuesInHTTPTokenListString:[request valueForHeaderField:@"Sec-WebSocket-Protocol"]];
}


- (void)startWithAvailableSubprotocols:(NSSet*)serverProtocols {
	[super startWithAvailableSubprotocols:serverProtocols];
	
	NSString *key = [[request valueForHeaderField:@"Sec-WebSocket-Key"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *concat = [key stringByAppendingString:TFWebSocketConnectionV8HandshakeGUID];
	
	NSMutableData *hash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
	SHA1((uint8_t*)[concat UTF8String], [concat lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [hash mutableBytes]);
	NSString *acceptString = [hash base64String];
	
	response.statusCode = 101;
	response.hasBody = NO;
	[response setValue:@"websocket" forHeaderField:@"Upgrade"];
	[response setValue:@"Upgrade" forHeaderField:@"Connection"];
	[response setValue:acceptString forHeaderField:@"Sec-WebSocket-Accept"];
	[response setValue:self.subprotocol forHeaderField:@"Sec-WebSocket-Protocol"];
	[response sendHeader];
	
	[self readNewFrame];
}


- (void)peerClosedWithPayload:(NSData*)payload {
	if(closing) {
		[socket disconnect];
	}else{
		TFWebSocketCloseCode code = TFWebSocketCloseCodeUnspecified;
		NSString *reason = nil;
		
		if([payload length] >= 2) {
			[payload getBytes:&code range:NSMakeRange(0, 2)];
			code = NSSwapBigShortToHost(code);
			if([payload length] > 2)
				reason = [[NSString alloc] initWithData:[payload subdataWithRange:NSMakeRange(2, [payload length]-2)] encoding:NSUTF8StringEncoding];
		}
		
		[self closeWithCode:TFWebSocketCloseCodeNormal];
		[socket disconnectAfterWriting];
		if(closeHandler) closeHandler(code, reason);
	}
}


- (void)closeWithCode:(TFWebSocketCloseCode)code reason:(NSString*)reason {
	NSMutableData *payload = [NSMutableData data];
	
	if(code != TFWebSocketCloseCodeUnspecified) {
		code = NSSwapHostShortToBig(code);
		[payload appendBytes:&code length:2];
		if(reason)
			[payload appendData:[reason dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	TFWebSocketFrameHeader header = {
		.FIN = YES,
		.RSV = {0,0,0},
		.opcode = TFWebSocketOpcodeClose,
		.masked = NO,
		.payloadLength = [payload length],		
	};
	
	NSData *headerData = [self dataFromFrameHeader:header];
	[socket writeData:headerData withTimeout:-1 tag:0];
	if([payload length])
		[socket writeData:payload withTimeout:-1 tag:0];
	closing = YES;
}


- (void)closeAndNotifyForCode:(TFWebSocketCloseCode)code {
	[self closeWithCode:code];
	if(closeHandler) closeHandler(code, nil);
}



#pragma Framing and masking


- (uint8)frameHeaderLengthFromFirstTwoBytes:(uint8_t*)buffer {
	uint8_t headerLength = 2;
	uint8_t secondByte = buffer[1];
	
	if(secondByte & (1<<7)) headerLength += 4; // MASK bit. +32 bits
	uint8_t firstLength = (secondByte & 0x7F);
	if(firstLength == 126) headerLength += 2; // +16-bit length
	else if(firstLength == 127) headerLength += 8; // +64-bit length
	return headerLength;
}


- (TFWebSocketFrameHeader)frameHeaderFromData:(NSData*)data {
	uint8_t headerSize = [self frameHeaderLengthFromFirstTwoBytes:(uint8_t*)[data bytes]];
	NSAssert([data length] >= headerSize, @"Not enough data for header!");
	
	TFWebSocketFrameHeader header;
	uint8_t *buffer = (uint8_t*)[data bytes];
	
	uint8_t byte = buffer[0];
	header.FIN = !!(byte & (1<<7));
	header.RSV[0] = !!(byte & (1<<6));
	header.RSV[1] = !!(byte & (1<<5));
	header.RSV[2] = !!(byte & (1<<5));
	header.opcode = (byte & 0xF);
	
	buffer++;
	byte = buffer[0];
	header.masked = !!(byte & (1<<7));
	uint8_t length7 = byte & 0x7F;
	
	buffer++;
	
	if(length7 <= 125) {
		header.payloadLength = length7;
	}else if(length7 == 126) {
		header.payloadLength = NSSwapBigShortToHost(*(uint16_t*)buffer);
		buffer += 2;
	}else if(length7 == 127) {
		header.payloadLength = NSSwapBigLongLongToHost(*(uint64_t*)buffer);
		buffer += 8;
	}
	
	if(header.masked) {
		memcpy(header.maskingKey.bytes, buffer, 4);
		buffer += 4;
	}
	
	return header;	
}


- (NSData*)dataFromFrameHeader:(TFWebSocketFrameHeader)frame {
	uint8_t first = (!!frame.FIN << 7) | (!!frame.RSV[0] << 6) | (!!frame.RSV[1] << 5) | (!!frame.RSV[2] << 4) | (frame.opcode & 0xF);
	NSMutableData *data = [NSMutableData dataWithBytes:&first length:1];
	uint8_t second = (!!frame.masked << 7);
	
	if(frame.payloadLength <= 125) {
		second |= frame.payloadLength;
		[data appendBytes:&second length:1];
	}else if(frame.payloadLength > USHRT_MAX) {
		second |= 127;
		[data appendBytes:&second length:1];
		uint64_t length = NSSwapHostLongLongToBig(frame.payloadLength);
		[data appendBytes:&length length:8];
	}else{
		second |= 126;
		[data appendBytes:&second length:1];
		uint16_t length = NSSwapHostShortToBig(frame.payloadLength);
		[data appendBytes:&length length:2];
	}
	
	if(frame.masked)
		[data appendBytes:frame.maskingKey.bytes length:4];
	
	return data;
}


// Masking is symmetric - this method both masks and demasks data
+ (NSData*)dataByApplyingMask:(TFWebSocketMaskingKey)key toData:(NSData*)data {
	NSMutableData *result = [NSMutableData dataWithCapacity:[data length]];
	for(NSUInteger i = 0; i < [data length]; i++) {
		uint8_t byte = ((uint8_t*)[data bytes])[i];
		byte ^= key.bytes[i % 4];
		[result appendBytes:&byte length:1];
	}
	return result;
}



#pragma mark Reading


- (void)readNewFrame {
	[socket readDataToLength:2 withTimeout:-1 tag:TFWebSocketTagFrameHeaderStart];
}


- (void)processFrameWithPayload:(NSData*)data {
	if(incomingFrameHeader.masked)
		data = [[self class] dataByApplyingMask:incomingFrameHeader.maskingKey toData:data];
	
	if(incomingFrameHeader.opcode == TFWebSocketOpcodeClose) {
		[self peerClosedWithPayload:data];
		return;
	}else if(incomingFrameHeader.opcode == TFWebSocketOpcodePing) {
		[self pongWithPayload:data];
		return;
	}else if(incomingFrameHeader.opcode == TFWebSocketOpcodePong) {
		if(pongHandler) pongHandler();
		return;
	}
	
	
	if(data) {
		[bufferedPayloadData appendData:data];
		if([bufferedPayloadData length] > TFWebSocketMaxMessageBodySize) {
			[self closeAndNotifyForCode:TFWebSocketCloseCodeProtocolError];
			return;
		}
	}
	
	if(incomingFrameHeader.opcode != TFWebSocketOpcodeContinuation)
		messageType = incomingFrameHeader.opcode;
	
	if(incomingFrameHeader.FIN) {
		NSData *messageData = [bufferedPayloadData copy];
		[bufferedPayloadData setLength:0];
		
		if(messageType == TFWebSocketOpcodeText) {
			NSString *text = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
			if(!text) return; // Invalid UTF-8. Explicitly undefined in spec.
			if(textMessageHandler) textMessageHandler(text);
			
		}else if(messageType == TFWebSocketOpcodeBinary) {
			if(dataMessageHandler) dataMessageHandler(messageData);
		}
	}
}



#pragma mark Writing


- (void)sendDataMessage:(NSData*)data {
	if(closing) return;
	
	TFWebSocketFrameHeader header = {
		.FIN = YES,
		.RSV = {0,0,0},
		.opcode = TFWebSocketOpcodeBinary,
		.masked = NO,
		.payloadLength = [data length],		
	};
	
	NSData *headerData = [self dataFromFrameHeader:header];
	[socket writeData:headerData withTimeout:-1 tag:0];
	[socket writeData:data withTimeout:-1 tag:0];
}


- (void)sendTextMessage:(NSString*)text {
	if(closing) return;
	
	NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
	
	TFWebSocketFrameHeader header = {
		.FIN = YES,
		.RSV = {0,0,0},
		.opcode = TFWebSocketOpcodeText,
		.masked = NO,
		.payloadLength = [data length],		
	};
	
	NSData *headerData = [self dataFromFrameHeader:header];
	[socket writeData:headerData withTimeout:-1 tag:0];
	[socket writeData:data withTimeout:-1 tag:0];
}



- (void)ping {
	TFWebSocketFrameHeader header = {
		.FIN = YES,
		.RSV = {0,0,0},
		.opcode = TFWebSocketOpcodePing,
		.masked = NO,
		.payloadLength = 0,		
	};
	
	NSData *headerData = [self dataFromFrameHeader:header];
	[socket writeData:headerData withTimeout:-1 tag:0];
}


- (void)pongWithPayload:(NSData*)payload {
	TFWebSocketFrameHeader header = {
		.FIN = YES,
		.RSV = {0,0,0},
		.opcode = TFWebSocketOpcodePong,
		.masked = NO,
		.payloadLength = [payload length],		
	};
	
	NSData *headerData = [self dataFromFrameHeader:header];
	[socket writeData:headerData withTimeout:-1 tag:0];
	if([payload length])
		[socket writeData:payload withTimeout:-1 tag:0];
}


- (void)pong {
	[self pongWithPayload:nil];
}


- (BOOL)supportsPing {
	return YES;
}


- (BOOL)supportsDataMessages {
	return YES;
}


@end