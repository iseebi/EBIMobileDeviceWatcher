//
//  EBIMobileDevice.h
//  EBIMobileDeviceWatcher
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017 Nobuhiro Ito. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    EBIMobileDeviceTypeIOS,
    EBIMobileDeviceTypeAndroid,
} EBIMobileDeviceType;

@interface EBIMobileDevice : NSObject

    @property (readonly) EBIMobileDeviceType type;
    @property (readonly) NSString *deviceName;
    @property (readonly) NSString *serialNumber;
    
    
    - (instancetype) initWithType:(EBIMobileDeviceType)type deviceName:(NSString *)deviceType serialNumber:(NSString *)serialNumber;
@end
