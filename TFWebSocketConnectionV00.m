//
//  TFWebSocketConnectionV00.m
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-07-03.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnectionV00.h"
#import "TFWebSocketPrivate.h"
#import "GCDAsyncSocket.h"


@interface TFWebSocketConnectionV00 ()
- (void)readNewFrame;
- (void)closeForError;
- (void)processClosingFrame;
- (void)handshakeWithChallenge:(NSData*)data;
@end


enum TFWebSocketConnectionV00ReadTags {
	TFWebSocketTagChallenge,
	TFWebSocketTagFrameFirstByte,
	TFWebSocketTagFramePayload,
	TFWebSocketTagDiscard,
};


@interface TFWebSocketConnectionV00 () <GCDAsyncSocketDelegate>
@property BOOL closing;
@end



@implementation TFWebSocketConnectionV00
@synthesize closing=_closing;


- (NSString*)origin {
	return [self.request valueForHeaderField:@"Origin"];
}



#pragma mark Socket


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
	if(!self.closing && self.closeHandler)
		self.closeHandler(TFWebSocketCloseCodeUnspecified, nil);
}


- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
	if(tag == TFWebSocketTagChallenge) {
		[self handshakeWithChallenge:data];
		
	}else if(tag == TFWebSocketTagFrameFirstByte) {
		uint8_t byte = *((uint8_t*)[data bytes]);
		
		if(byte == 0x00) { // Text
			[self.socket readDataToData:[NSData dataWithBytes:"\xFF" length:1] withTimeout:-1 maxLength:TFWebSocketMaxMessageBodySize tag:TFWebSocketTagFramePayload];
			
		}else if(byte == 0xFF) { // Close
			[self processClosingFrame];
			[self.socket readDataToLength:1 withTimeout:10 tag:TFWebSocketTagDiscard]; // skip 0x00
		}else{
			NSLog(@"Got unexpected initial message byte: 0x%X", byte);
		}
		
	}else if(tag == TFWebSocketTagFramePayload) {
		NSString *text = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, [data length]-1)] encoding:NSUTF8StringEncoding];
		if(!text) return; // Violates spec.
		
		[self readNewFrame];
		if(self.textMessageHandler) self.textMessageHandler(text);
	}
}



#pragma mark Connection and handshake


+ (BOOL)validateRequest:(WARequest*)request {
	if(![super validateRequest:request]) return NO;
	if(![request valueForHeaderField:@"Sec-WebSocket-Key1"]) return NO;
	if(![request valueForHeaderField:@"Sec-WebSocket-Key2"]) return NO;
	return YES;
}


- (NSArray*)clientSubprotocols {
	NSString *protocol = [self.request valueForHeaderField:@"Sec-WebSocket-Protocol"];
	return protocol ? [NSArray arrayWithObject:protocol] : nil;
}


- (void)startWithAvailableSubprotocols:(NSSet*)serverProtocols {
	[super startWithAvailableSubprotocols:serverProtocols];
	[self.socket readDataToLength:8 withTimeout:10 tag:TFWebSocketTagChallenge];
}


// Insane algorithm from draft 00, section 1.3
- (NSData*)dataFromKeyFieldValue:(NSString*)value {
	NSMutableString *numberString = [NSMutableString string];
	uint32_t spaceCount = 0;
	for(NSUInteger i=0; i<[value length]; i++) {
		unichar c = [value characterAtIndex:i];
		if(c >= '0' && c <= '9')
			[numberString appendFormat:@"%C", c];
		else if(c == ' ')
			spaceCount++;
	}
	
	if(spaceCount == 0) return nil;	
	long long number;
	[[NSScanner scannerWithString:numberString] scanLongLong:&number];
	uint32_t result = number / spaceCount;
	result = NSSwapHostIntToBig(result);
	return [NSData dataWithBytes:&result length:sizeof(result)];
}


- (void)handshakeWithChallenge:(NSData*)data {
	NSData *key1 = [self dataFromKeyFieldValue:[self.request valueForHeaderField:@"Sec-Websocket-Key1"]];
	NSData *key2 = [self dataFromKeyFieldValue:[self.request valueForHeaderField:@"Sec-Websocket-Key2"]];
	if(!key1 || !key2) { // wtf?
		[self closeForError];
		return;
	}
	
	NSMutableData *buffer = [key1 mutableCopy];
	[buffer appendData:key2];
	[buffer appendData:data];	
	NSData *hash = [buffer MD5Digest];
	
	NSString *scheme = @"ws"; // Fix: wss if SSL. Needs support from WAK
	NSString *location = [NSString stringWithFormat:@"%@://%@%@", scheme, self.request.host, self.request.path];
	if(self.request.query) location = [location stringByAppendingFormat:@"?%@", self.request.query];
	
	WAResponse *handshakeResponse = [[WAResponse alloc] initWithRequest:self.request socket:self.socket];
	handshakeResponse.completionHandler = ^(BOOL close){};
	handshakeResponse.statusCode = 101;
	if(self.origin) [handshakeResponse setValue:self.origin forHeaderField:@"Sec-WebSocket-Origin"];
	[handshakeResponse setValue:location forHeaderField:@"Sec-WebSocket-Location"];
	[handshakeResponse setValue:@"WebSocket" forHeaderField:@"Upgrade"];
	[handshakeResponse setValue:@"Upgrade" forHeaderField:@"Connection"];
	if(self.subprotocol) [handshakeResponse setValue:self.subprotocol forHeaderField:@"Sec-WebSocket-Protocol"];
	[handshakeResponse setValue:nil forHeaderField:@"Content-Type"];
	[handshakeResponse appendBodyData:hash];
	[handshakeResponse finish];
	
	[self readNewFrame];
	if(self.handshakeHandler) self.handshakeHandler(YES);
}


- (void)closeWithCode:(TFWebSocketCloseCode)code reason:(NSString*)reason {
	NSData *closeFrame = [NSData dataWithBytes:"\xFF\x00" length:2];
	[self.socket writeData:closeFrame withTimeout:-1 tag:0];
	[self.socket disconnectAfterWriting];
}


- (void)closeForError {
	[self.socket disconnect];
	if(self.closeHandler) self.closeHandler(TFWebSocketCloseCodeUnspecified, nil);
}


- (void)processClosingFrame {
	if(self.closing) {
		[self.socket disconnect];
	}else{
		[self close];
		if(self.closeHandler) self.closeHandler(TFWebSocketCloseCodeUnspecified, nil);
	}
}



#pragma mark Reading and writing


- (void)readNewFrame {
	[self.socket readDataToLength:1 withTimeout:-1 tag:TFWebSocketTagFrameFirstByte];
}


- (void)sendTextMessage:(NSString*)text {
	NSParameterAssert(text);
	[self.socket writeData:[NSData dataWithBytes:"\x00" length:1] withTimeout:-1 tag:0];
	[self.socket writeData:[text dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
	[self.socket writeData:[NSData dataWithBytes:"\xFF" length:1] withTimeout:-1 tag:0];
}


@end