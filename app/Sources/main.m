#import <UIKit/UIKit.h>
#import "LRAppDelegate.h"
#include "crash_report.h"

int main(int argc, char *argv[]) {
    int rc;
    SenkoCrashInstall();
    @autoreleasepool {
        rc = UIApplicationMain(argc, argv, nil, NSStringFromClass([LRAppDelegate class]));
    }
    return rc;
}
