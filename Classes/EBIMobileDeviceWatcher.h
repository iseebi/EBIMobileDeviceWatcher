//
//  EBIMobileDeviceWatcher.h
//  EBIMobileDeviceWatcher
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017 Nobuhiro Ito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EBIMobileDevice.h"

@class EBIMobileDeviceWatcher;

@protocol EBIMobileDeviceWatcherDelegate <NSObject>

    - (void) mobileDeviceWatcherStarted:(EBIMobileDeviceWatcher *)watcher;
    - (void) mobileDeviceWatcherStopped:(EBIMobileDeviceWatcher *)watcher;

    - (void) mobileDeviceWatcher:(EBIMobileDeviceWatcher *)watcher
       didDiscoveredMobileDevice:(EBIMobileDevice *)device;

    - (void) mobileDeviceWatcher:(EBIMobileDeviceWatcher *)watcher
     didDisconnectedMobileDevice:(EBIMobileDevice *)device;

@end


@interface EBIMobileDeviceWatcher : NSObject

    @property (weak) id<EBIMobileDeviceWatcherDelegate> delegate;
    @property (readonly) NSArray<EBIMobileDevice *> *devices;
    @property (readonly, getter=isActive) BOOL active;
    
    - (void) startWatching;
    - (void) stopWatching;
    
    - (void) scan;
    
@end
