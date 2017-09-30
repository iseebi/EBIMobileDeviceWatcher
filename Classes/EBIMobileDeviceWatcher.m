//
//  EBIMobileDeviceWatcher.m
//  EBIMobileDeviceWatcher
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017 Nobuhiro Ito. All rights reserved.
//

#import "EBIMobileDeviceWatcher.h"
#include <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

#define ADB_CLASS              0xff
#define ADB_SUBCLASS           0x42
#define ADB_PROTOCOL           0x1

@interface EBIMobileDeviceWatcher ()
    
    @property (readonly) NSMutableArray<EBIMobileDevice *> *mutableDevices;
    
    @property (readwrite) BOOL active;
    @property (assign) CFRunLoopRef runLoop;
    @property (assign) IONotificationPortRef notificationPort;
    @property (assign) CFRunLoopSourceRef notificationRunLoopSource;
    @property NSThread *runningThread;

    - (void) onIOSDeviceMatchedCallback:(io_iterator_t)iterator;
    - (void) onAndroidInterfaceMatchedCallback:(io_iterator_t)iterator;
    - (void) onDeviceTerminateCallback:(io_iterator_t)iterator;
    
@end

void EBIMobileDeviceWatcherIOSDeviceMatchedCallback(void* refcon, io_iterator_t iterator)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [(__bridge EBIMobileDeviceWatcher *)refcon onIOSDeviceMatchedCallback:iterator];
    });
}

void EBIMobileDeviceWatcherAndroidInterfaceMatchedCallback(void* refcon, io_iterator_t iterator)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [(__bridge EBIMobileDeviceWatcher *)refcon onAndroidInterfaceMatchedCallback:iterator];
    });
}

void EBIMobileDeviceWatcherDeviceTerminatedCallback(void* refcon, io_iterator_t iterator)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [(__bridge EBIMobileDeviceWatcher *)refcon onDeviceTerminateCallback:iterator];
    });
}

@implementation EBIMobileDeviceWatcher
    
    - (instancetype)init
    {
        self = [super init];
        if (self)
        {
            _mutableDevices = [NSMutableArray array];
            _devices = _mutableDevices;
        }
        return self;
    }
    
    - (void)dealloc
    {
        [self stopWatching];
    }

    //--------------------------------------------------------------------------------
    #pragma mark Waiting notification
    //--------------------------------------------------------------------------------

    -(void)startWatching
    {
        if (self.isActive)
        {
            return;
        }
        
        self.active = YES;
        
        self.runningThread = [[NSThread alloc] initWithTarget:self selector:@selector(watchingThreadAction) object:nil];
        [self.runningThread start];
    }

    - (void) watchingThreadAction
    {
        NSLog(@"Watching thread start");
        
        self.runLoop = CFRunLoopGetCurrent();
        self.notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
        self.notificationRunLoopSource = IONotificationPortGetRunLoopSource(self.notificationPort);
        CFRunLoopAddSource(self.runLoop, self.notificationRunLoopSource, kCFRunLoopDefaultMode);
        
        [self.mutableDevices removeAllObjects];
        [self.delegate mobileDeviceWatcherStarted:self];
        
        io_iterator_t iosDeviceMatchedIter;
        io_iterator_t androidInterfaceMatchedIter;
        io_iterator_t deviceTerminatedIter;
        
        // for iOS Device Matched
        {
            CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
            CFDictionaryAddValue(matchingDict, CFSTR(kIOPropertyMatchKey),
                                 (CFDictionaryRef) @{ @"SupportsIPhoneOS": @YES });
            
            IOServiceAddMatchingNotification(self.notificationPort,
                                             kIOMatchedNotification,
                                             matchingDict,
                                             EBIMobileDeviceWatcherIOSDeviceMatchedCallback,
                                             (__bridge void *)(self),
                                             &iosDeviceMatchedIter);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onIOSDeviceMatchedCallback:iosDeviceMatchedIter];
            });
        }
        
        // for Android Interface
        {
            IOServiceAddMatchingNotification(self.notificationPort,
                                             kIOMatchedNotification,
                                             IOServiceMatching(kIOUSBInterfaceClassName),
                                             EBIMobileDeviceWatcherAndroidInterfaceMatchedCallback,
                                             (__bridge void *)(self),
                                             &androidInterfaceMatchedIter);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onAndroidInterfaceMatchedCallback:androidInterfaceMatchedIter];
            });
        }
        
        // for Device Terminated
        {
            IOServiceAddMatchingNotification(self.notificationPort,
                                             kIOTerminatedNotification,
                                             IOServiceMatching(kIOUSBDeviceClassName),
                                             EBIMobileDeviceWatcherDeviceTerminatedCallback,
                                             (__bridge void *)(self),
                                             &deviceTerminatedIter);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onDeviceTerminateCallback:deviceTerminatedIter];
            });
        }
        
        CFRunLoopRun();
        NSLog(@"Watching thread stop");
        
        IOObjectRelease(iosDeviceMatchedIter);
        IOObjectRelease(androidInterfaceMatchedIter);
        IOObjectRelease(deviceTerminatedIter);
        
        CFRunLoopRemoveSource(self.runLoop, self.notificationRunLoopSource, kCFRunLoopDefaultMode);
        IONotificationPortDestroy(self.notificationPort);
        
        self.notificationRunLoopSource = NULL;
        self.notificationPort = NULL;
        self.runLoop = NULL;
        self.active = NO;
        self.runningThread = nil;
        
        [self.delegate mobileDeviceWatcherStopped:self];
    }
    
    - (void)stopWatching
    {
        if (!self.isActive)
        {
            return;
        }

        CFRunLoopStop(self.runLoop);
    }
    
    - (void) onIOSDeviceMatchedCallback:(io_iterator_t)iterator
    {
        io_object_t deviceObject;
        while ((deviceObject = IOIteratorNext(iterator)))
        {
            EBIMobileDevice *device = [self detectDevice:deviceObject];
            IOObjectRelease(deviceObject);
            
            [self onMatchedDevice:device];
        }
    }
    
    - (void) onAndroidInterfaceMatchedCallback:(io_iterator_t)iterator
    {
        io_object_t interfaceObject;
        while ((interfaceObject = IOIteratorNext(iterator)))
        {
            if ([self isAndroidInterface:interfaceObject]) {
                EBIMobileDevice *device = [self mobileDeviceFromADBInterface:interfaceObject];
                [self onMatchedDevice:device];
            }
            IOObjectRelease(interfaceObject);
        }
    }
    
    - (void) onDeviceTerminateCallback:(io_iterator_t)iterator
    {
        io_object_t deviceObject;
        while ((deviceObject = IOIteratorNext(iterator)))
        {
            EBIMobileDevice *device;
            if ([self isIPhoneOSDevice:deviceObject])
            {
                device = [self createDetectedDevice:deviceObject type:EBIMobileDeviceTypeIOS];
            }
            else
            {
                device = [self createDetectedDevice:deviceObject type:EBIMobileDeviceTypeAndroid];
            }
            IOObjectRelease(deviceObject);
            
            [self onTerminatedDevice:device];
        }
    }
    
    - (EBIMobileDevice *) mobileDeviceFromADBInterface:(io_object_t)adbInterfaceObject
    {
        io_object_t deviceObject;
        IORegistryEntryGetParentEntry(adbInterfaceObject, kIOServicePlane, &deviceObject);

        EBIMobileDevice *device = [self createDetectedDevice:deviceObject type:EBIMobileDeviceTypeAndroid];
        
        IOObjectRelease(deviceObject);
        
        return device;
    }
    
    - (void) onMatchedDevice:(EBIMobileDevice *)device
    {
        if (device == nil) { return; }
        
        NSUInteger index = [self.mutableDevices indexOfObject:device];
        if (index != NSNotFound) { return; }
        
        [self.mutableDevices addObject:device];
        [self.delegate mobileDeviceWatcher:self didDiscoveredMobileDevice:device];
    }

    - (void) onTerminatedDevice:(EBIMobileDevice *)device
    {
        if (device == nil) { return; }
        
        NSUInteger index = [self.mutableDevices indexOfObject:device];
        if (index == NSNotFound) { return; }
        
        EBIMobileDevice *disconnectDevice = [self.mutableDevices objectAtIndex:index];
        [self.mutableDevices removeObjectAtIndex:index];
        [self.delegate mobileDeviceWatcher:self didDisconnectedMobileDevice:disconnectDevice];
    }
    
    //--------------------------------------------------------------------------------
    #pragma mark Single scan
    //--------------------------------------------------------------------------------

    - (void) scan
    {
        if (self.isActive)
        {
            return;
        }

        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        
        io_iterator_t iterator;
        if (IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator) != KERN_SUCCESS) {
            return;
        }

        NSMutableSet *currentSet = [NSMutableSet setWithArray:self.mutableDevices];
        
        io_object_t deviceObject;
        while ((deviceObject = IOIteratorNext(iterator)))
        {
            EBIMobileDevice *device = [self detectDevice:deviceObject];
            IOObjectRelease(deviceObject);
            
            if (device == nil) { continue; }
            
            if ([currentSet containsObject:device])
            {
                [currentSet removeObject:device];
            }
            else
            {
                [self.mutableDevices addObject:device];
                [self.delegate mobileDeviceWatcher:self didDiscoveredMobileDevice:device];
            }
        }
        
        for (EBIMobileDevice *removedDevice in currentSet) {
            [self.mutableDevices removeObject:removedDevice];
            [self.delegate mobileDeviceWatcher:self didDisconnectedMobileDevice:removedDevice];
        }
    }
    
    //--------------------------------------------------------------------------------
    #pragma mark Device validations
    //--------------------------------------------------------------------------------

    - (EBIMobileDevice *) detectDevice:(io_object_t)deviceObject
    {
        if ([self isIPhoneOSDevice:deviceObject])
        {
            return [self createDetectedDevice:deviceObject type:EBIMobileDeviceTypeIOS];
        }
        else if ([self isAndroidDevice:deviceObject])
        {
            return [self createDetectedDevice:deviceObject type:EBIMobileDeviceTypeAndroid];
        }
        
        return nil;
    }
    
    - (EBIMobileDevice *) createDetectedDevice:(io_object_t)deviceObject type:(EBIMobileDeviceType)type
    {
        // TODO: DeviceName ほしい... iOS では lockdownd が必要らしくちょっと微妙っぽい
        NSString *deviceName = [self readStringProperty:@"USB Product Name" fromDevice:deviceObject];
        NSString *serialNumber = [self readStringProperty:@"USB Serial Number" fromDevice:deviceObject];
        
        return [[EBIMobileDevice alloc] initWithType:type deviceName:deviceName serialNumber:serialNumber];
    }
    
    - (BOOL) isIPhoneOSDevice:(io_object_t)object
    {
        CFNumberRef flag = IORegistryEntryCreateCFProperty(object, CFSTR("SupportsIPhoneOS"), kCFAllocatorDefault, 0);
        if (flag == NULL) {
            return NO;
        }
        BOOL result = [(__bridge NSNumber *)flag boolValue];
        return result;
    }
    
    - (BOOL) isAndroidDevice:(io_object_t)object
    {
        __block BOOL result = NO;
        __weak typeof(self) bself = self;
        [self enumerateUSBInterface:object enumerateBlock:^BOOL(io_object_t interfaceObject) {
            result = [bself isAndroidInterface:interfaceObject];
            return result;
        }];
        return result;
    }

    - (BOOL) isAndroidInterface:(io_object_t)interfaceObject
    {
        kern_return_t kr;
        HRESULT hr;
        IOCFPlugInInterface **plugInInterface = NULL;
        IOUSBInterfaceInterface220 **iface = NULL;
        SInt32 score;
        UInt8 if_class, subclass, protocol;
        
        kr = IOCreatePlugInInterfaceForService(interfaceObject,
                                               kIOUSBInterfaceUserClientTypeID,
                                               kIOCFPlugInInterfaceID,
                                               &plugInInterface,
                                               &score);
        if ((kr != KERN_SUCCESS) || (!plugInInterface))
        {
            return NO;
        }
        
        hr = (*plugInInterface)->QueryInterface(plugInInterface,
                                                CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
                                                (LPVOID*)&iface);
        (*plugInInterface)->Release(plugInInterface);
        if (hr || !iface)
        {
            return NO;
        }
        
        kr = (*iface)->GetInterfaceClass(iface, &if_class);
        kr = (*iface)->GetInterfaceSubClass(iface, &subclass);
        kr = (*iface)->GetInterfaceProtocol(iface, &protocol);
        
        if ((if_class != ADB_CLASS) || (subclass != ADB_SUBCLASS) || (protocol != ADB_PROTOCOL))
        {
            (*iface)->Release(iface);
            return NO;
        }
        
        (*iface)->Release(iface);
        return YES;
    }
    
    - (void) enumerateUSBInterface:(io_object_t)deviceObject enumerateBlock:(BOOL(^)(io_object_t interfaceObject))enumerateBlock
    {
        kern_return_t kr;
        io_iterator_t iter;
        io_object_t interfaceObject;
        
        kr = IORegistryEntryGetChildIterator(deviceObject, kIOServicePlane, &iter);
        if (kr != KERN_SUCCESS) {
            return;
        }

        while ((interfaceObject = IOIteratorNext(iter)))
        {
            NSString *className = nil;
            CFStringRef strRef = IORegistryEntryCreateCFProperty(interfaceObject, CFSTR("IOClassNameOverride"), kCFAllocatorDefault, 0);
            if (strRef != NULL) {
                className = [(__bridge NSString *)strRef copy];
                CFRelease(strRef);
            }
            
            if ([className isEqualToString:@"IOUSBInterface"])
            {
                BOOL stop = enumerateBlock(interfaceObject);
                IOObjectRelease(interfaceObject);
                if (stop) { break; }
            }
            else
            {
                IOObjectRelease(interfaceObject);
                interfaceObject = 0;
            }
        }
        IOObjectRelease(iter);
    }

    //--------------------------------------------------------------------------------
    #pragma mark Support methods
    //--------------------------------------------------------------------------------
    
    - (NSString *) readStringProperty:(NSString *)key fromDevice:(io_object_t)object
    {
        CFStringRef valueRef = IORegistryEntryCreateCFProperty(object, (__bridge CFStringRef)key, kCFAllocatorDefault, 0);
        if (valueRef == NULL) {
            return nil;
        }
        NSString *result = [(__bridge NSString *)valueRef copy];
        CFRelease(valueRef);
        return result;
    }
    
@end
