//
//  TFWebSocketConnectionV00.h
//  TFWebSocketHandler
//
//  Created by Tomas Franzén on 2011-07-03.
//  Copyright 2011 Lighthead Software. All rights reserved.
//

#import "TFWebSocketConnection.h"

// draft-ietf-hybi-thewebsocketprotocol-00
@interface TFWebSocketConnectionV00 : TFWebSocketConnection <GCDAsyncSocketDelegate> {
	BOOL closing;
}

@end
