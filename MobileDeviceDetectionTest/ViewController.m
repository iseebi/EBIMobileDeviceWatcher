//
//  ViewController.m
//  MobileDeviceDetectionTest
//
//  Created by Nobuhiro Ito on 2017/01/06.
//  Copyright © 2017 Nobuhiro Ito. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController
    
    - (void)viewDidLoad {
        [super viewDidLoad];
        self.watcher = [[EBIMobileDeviceWatcher alloc] init];
        self.watcher.delegate = self;
    }
    
    - (IBAction)scanTapped:(id)sender
    {
        [self.watcher scan];
    }
    
    - (BOOL)watching
    {
        return self.watcher.isActive;
    }
    
    - (void)setWatching:(BOOL)watching
    {
        if (watching)
        {
            [self.watcher startWatching];
        }
        else
        {
            [self.watcher stopWatching];
        }
    }

    - (void)mobileDeviceWatcherStarted:(EBIMobileDeviceWatcher *)watcher
    {
        self.watching = self.watching;
    }
    
    - (void)mobileDeviceWatcherStopped:(EBIMobileDeviceWatcher *)watcher
    {
        self.watching = self.watching;
    }
    
    - (void)mobileDeviceWatcher:(EBIMobileDeviceWatcher *)watcher didDiscoveredMobileDevice:(EBIMobileDevice *)device
    {
        NSLog(@"Discovered: %@", device);
        [self.devicesArrayController rearrangeObjects];
    }
    
    - (void)mobileDeviceWatcher:(EBIMobileDeviceWatcher *)watcher didDisconnectedMobileDevice:(EBIMobileDevice *)device
    {
        NSLog(@"Terminated: %@", device);
        [self.devicesArrayController rearrangeObjects];
    }

@end
