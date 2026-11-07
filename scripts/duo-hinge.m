// Sets the hinge angle of the iPhone Duo simulator: 180 is open, 0 is closed.
// Neither simctl nor devicectl can fold the simulator. This runs inside the
// simulator through `xcrun simctl spawn` and posts the vendor-defined HID event
// that the hinge control in Device Hub sends.
// Mechanism from https://github.com/artemnovichkov/hinge (MIT).
//
//   duo-hinge <degrees>

#import <Foundation/Foundation.h>
#include <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventRef IOHIDEventCreateVendorDefinedEvent(CFAllocatorRef allocator, uint64_t timeStamp,
    uint32_t usagePage, uint32_t usage, uint32_t version, const uint8_t *data, CFIndex length, uint32_t options);
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreateWithType(CFAllocatorRef allocator, int type,
    CFDictionaryRef properties);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef client, IOHIDEventRef event);
extern CFDataRef IOCFSerialize(CFTypeRef object, CFOptionFlags options);

enum {
    kUsagePage = 0xFF61,
    kUsage = 0x5B,
    kClientTypeSimple = 4,
    kSerializeBinary = 1,
};

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: duo-hinge <degrees>\n");
        return 64;
    }

    @autoreleasepool {
        NSDictionary *payload = @{
            @"provider" : @"com.apple.Virtualization.VirtualMachines",
            @"source" : @"hinge-slider-control",
            @"type" : @"range",
            @"value" : @(atof(argv[1])),
        };
        CFDataRef data = IOCFSerialize((__bridge CFTypeRef)payload, kSerializeBinary);
        IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateWithType(NULL, kClientTypeSimple, NULL);
        IOHIDEventRef event = data ? IOHIDEventCreateVendorDefinedEvent(NULL, mach_absolute_time(), kUsagePage,
            kUsage, 0, CFDataGetBytePtr(data), CFDataGetLength(data), 0) : NULL;
        if (!client || !event) {
            fprintf(stderr, "duo-hinge: could not create the hinge event\n");
            return 1;
        }

        IOHIDEventSystemClientDispatchEvent(client, event);
        // Let the event leave before the process exits.
        usleep(20000);
    }
    return 0;
}
