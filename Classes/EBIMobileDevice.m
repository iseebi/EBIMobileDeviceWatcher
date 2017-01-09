//
//  EBIMobileDevice.m
//  EBIMobileDeviceWatcher
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017 Nobuhiro Ito. All rights reserved.
//

#import "EBIMobileDevice.h"

@interface EBIMobileDevice ()

    @property (assign) NSUInteger cachedHash;
    
@end

@implementation EBIMobileDevice

    - (instancetype) initWithType:(EBIMobileDeviceType)type deviceName:(NSString *)deviceType serialNumber:(NSString *)serialNumber
    {
        self = [super init];
        if (self)
        {
            _type = type;
            _deviceName = [deviceType copy];
            _serialNumber = [serialNumber copy];
            
            _cachedHash = [NSString stringWithFormat:@"%lu_%@", (unsigned long)type, serialNumber].hash;
        }
        return self;
    }
    
    - (NSString *)description
    {
        switch (self.type) {
            case EBIMobileDeviceTypeIOS:
            return [NSString stringWithFormat:@"[iOSDevice(%@) serial:%@]", self.deviceName, self.serialNumber ];
            case EBIMobileDeviceTypeAndroid:
            return [NSString stringWithFormat:@"[AndroidDevice(%@) serial:%@]", self.deviceName, self.serialNumber ];
            default:
            return [NSString stringWithFormat:@"[EBIMobileDevice UnknownDevice]"];
        }
    }
    
    -(BOOL)isEqual:(id)object
    {
        if (![object isKindOfClass:[EBIMobileDevice class]])
        {
            return false;
        }
        __typeof(self) other = object;
        return (self.type == other.type) && ([self.serialNumber isEqualToString:other.serialNumber]);
    }
    

    -(NSUInteger)hash
    {
        return self.cachedHash;
    }
    
@end
