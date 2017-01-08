//
//  ViewController.h
//  MobileDeviceDetectionTest
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017年 Nobuhiro Ito. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EBIMobileDeviceWatcher.h"

@interface ViewController : NSViewController<EBIMobileDeviceWatcherDelegate>

    @property (strong) IBOutlet NSArrayController *devicesArrayController;

    @property (nonatomic, strong) EBIMobileDeviceWatcher *watcher;

    @property (nonatomic, assign) BOOL watching;

@end

