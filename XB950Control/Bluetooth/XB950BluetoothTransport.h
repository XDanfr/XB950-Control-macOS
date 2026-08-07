#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^XB950DataHandler)(NSData *data);
typedef void (^XB950DisconnectHandler)(NSError *_Nullable error);
typedef void (^XB950ConnectCompletion)(NSError *_Nullable error);

/// A small Swift-facing wrapper around Apple's Bluetooth Classic APIs.
/// All callbacks are delivered on the main queue.
@interface XB950BluetoothTransport : NSObject

@property (nonatomic, copy, nullable) XB950DataHandler dataHandler;
@property (nonatomic, copy, nullable) XB950DisconnectHandler disconnectHandler;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)pairedSonyDevices;

- (void)connectToAddress:(NSString *)address
              completion:(XB950ConnectCompletion)completion NS_SWIFT_NAME(connect(to:completion:));
- (BOOL)sendData:(NSData *)data error:(NSError **)error NS_SWIFT_NAME(send(_:));
- (void)disconnect;

@end

NS_ASSUME_NONNULL_END
