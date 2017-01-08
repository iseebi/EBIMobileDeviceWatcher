# EBIMobileDeviceWatcher

Observe iOS/Android device connect/disconnect on macOS.

## How to use

```
self.watcher = [[EBIMobileDeviceWatcher alloc] init];
self.watcher.delegate = self;
[self.watcher startWatcing];
```
