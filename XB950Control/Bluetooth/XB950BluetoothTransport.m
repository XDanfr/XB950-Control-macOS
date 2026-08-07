#import "XB950BluetoothTransport.h"

#import <IOBluetooth/IOBluetooth.h>

static NSString *const XB950ErrorDomain = @"me.xdan.XB950ControlMac.Bluetooth";

typedef NS_ENUM(NSInteger, XB950BluetoothError) {
    XB950BluetoothErrorDeviceNotFound = 1,
    XB950BluetoothErrorSDPFailed,
    XB950BluetoothErrorServiceNotFound,
    XB950BluetoothErrorChannelOpenFailed,
    XB950BluetoothErrorNotConnected,
    XB950BluetoothErrorWriteFailed,
};

@interface XB950BluetoothTransport () <IOBluetoothRFCOMMChannelDelegate>
@property (nonatomic, strong, nullable) IOBluetoothDevice *device;
@property (nonatomic, strong, nullable) IOBluetoothRFCOMMChannel *channel;
@property (nonatomic, copy, nullable) XB950ConnectCompletion connectCompletion;
@property (nonatomic, readwrite, getter=isConnected) BOOL connected;
@end

@implementation XB950BluetoothTransport

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedSonyDevices {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray array];
    for (id object in [IOBluetoothDevice pairedDevices]) {
        if (![object isKindOfClass:[IOBluetoothDevice class]]) {
            continue;
        }
        IOBluetoothDevice *device = object;
        NSString *name = device.name ?: @"";
        if ([name rangeOfString:@"MDR-XB950N1" options:NSCaseInsensitiveSearch].location == NSNotFound) {
            continue;
        }
        NSString *address = device.addressString ?: @"";
        if (address.length > 0) {
            [result addObject:@{ @"name": name.length > 0 ? name : @"MDR-XB950N1",
                                 @"address": address }];
        }
    }
    return result;
}

- (void)connectToAddress:(NSString *)address completion:(XB950ConnectCompletion)completion {
    [self disconnect];
    self.connectCompletion = completion;
    self.device = [IOBluetoothDevice deviceWithAddressString:address];
    if (!self.device) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorDeviceNotFound
                                         message:@"The paired Bluetooth device could not be found."]];
        return;
    }

    IOReturn status = [self.device performSDPQuery:self];
    if (status != kIOReturnSuccess) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorSDPFailed
                                         message:[NSString stringWithFormat:@"Sony service discovery could not start (0x%08x).", status]]];
    }
}

- (void)sdpQueryComplete:(IOBluetoothDevice *)device status:(IOReturn)status {
    if (status != kIOReturnSuccess) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorSDPFailed
                                         message:[NSString stringWithFormat:@"Sony service discovery failed (0x%08x).", status]]];
        return;
    }

    const uint8_t bytes[16] = {
        0x96, 0xCC, 0x20, 0x3E, 0x50, 0x68, 0x46, 0xAD,
        0xB3, 0x2D, 0xE3, 0x16, 0xF5, 0xE0, 0x69, 0xBA
    };
    IOBluetoothSDPUUID *uuid = [IOBluetoothSDPUUID uuidWithBytes:bytes length:sizeof(bytes)];
    IOBluetoothSDPServiceRecord *record = [device getServiceRecordForUUID:uuid];
    BluetoothRFCOMMChannelID channelID = 0;
    if (!record || [record getRFCOMMChannelID:&channelID] != kIOReturnSuccess || channelID == 0) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorServiceNotFound
                                         message:@"The MDR control service was not found. Make sure the headphones are on, then reconnect them in Bluetooth settings."]];
        return;
    }

    IOBluetoothRFCOMMChannel *channel = nil;
    IOReturn openStatus = [device openRFCOMMChannelAsync:&channel
                                            withChannelID:channelID
                                                 delegate:self];
    self.channel = channel;
    if (openStatus != kIOReturnSuccess) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorChannelOpenFailed
                                         message:[NSString stringWithFormat:@"The Sony control channel could not be opened (0x%08x).", openStatus]]];
    }
}

- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel *)rfcommChannel
                            status:(IOReturn)error {
    if (error != kIOReturnSuccess) {
        [self finishConnectWithError:[self error:XB950BluetoothErrorChannelOpenFailed
                                         message:[NSString stringWithFormat:@"The Sony control channel failed to open (0x%08x).", error]]];
        return;
    }
    self.channel = rfcommChannel;
    self.connected = YES;
    [self finishConnectWithError:nil];
}

- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel *)rfcommChannel
                     data:(void *)dataPointer
                   length:(size_t)dataLength {
    if (dataLength == 0 || !self.dataHandler) {
        return;
    }
    NSData *data = [NSData dataWithBytes:dataPointer length:dataLength];
    XB950DataHandler handler = self.dataHandler;
    dispatch_async(dispatch_get_main_queue(), ^{ handler(data); });
}

- (void)rfcommChannelClosed:(IOBluetoothRFCOMMChannel *)rfcommChannel {
    BOOL wasConnected = self.connected;
    self.connected = NO;
    self.channel = nil;
    if (wasConnected && self.disconnectHandler) {
        XB950DisconnectHandler handler = self.disconnectHandler;
        NSError *error = [self error:XB950BluetoothErrorNotConnected
                              message:@"The headphones closed the control connection."];
        dispatch_async(dispatch_get_main_queue(), ^{ handler(error); });
    }
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    IOBluetoothRFCOMMChannel *channel = self.channel;
    if (!self.connected || !channel) {
        if (error) {
            *error = [self error:XB950BluetoothErrorNotConnected
                         message:@"The headphones are not connected."];
        }
        return NO;
    }
    if (data.length > UINT16_MAX) {
        if (error) {
            *error = [self error:XB950BluetoothErrorWriteFailed message:@"Packet is too large."];
        }
        return NO;
    }
    IOReturn status = [channel writeSync:(void *)data.bytes length:(UInt16)data.length];
    if (status != kIOReturnSuccess) {
        if (error) {
            *error = [self error:XB950BluetoothErrorWriteFailed
                         message:[NSString stringWithFormat:@"Bluetooth write failed (0x%08x).", status]];
        }
        return NO;
    }
    return YES;
}

- (void)disconnect {
    self.connectCompletion = nil;
    self.connected = NO;
    IOBluetoothRFCOMMChannel *channel = self.channel;
    self.channel = nil;
    if (channel) {
        [channel closeChannel];
    }
    self.device = nil;
}

- (void)finishConnectWithError:(NSError *)error {
    XB950ConnectCompletion completion = self.connectCompletion;
    self.connectCompletion = nil;
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
}

- (NSError *)error:(XB950BluetoothError)code message:(NSString *)message {
    return [NSError errorWithDomain:XB950ErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

@end
