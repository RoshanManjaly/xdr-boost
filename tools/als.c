// Read the Apple Silicon ambient light sensor (lux) via private IOHIDEventSystemClient API.
// usage: als <samples> <interval_ms>   prints "epoch_ms lux" per line
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <unistd.h>

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEvent *IOHIDEventRef;
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
extern void IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef, CFDictionaryRef);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
extern double IOHIDEventGetFloatValue(IOHIDEventRef, int32_t);

#define kALS 12

static CFNumberRef num(int v) { return CFNumberCreate(NULL, kCFNumberIntType, &v); }

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 10, ms = argc > 2 ? atoi(argv[2]) : 200;
    IOHIDEventSystemClientRef c = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    const void *k[] = {CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage")};
    const void *v[] = {num(0xff00), num(4)};
    CFDictionaryRef m = CFDictionaryCreate(NULL, k, v, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(c, m);
    CFArrayRef svcs = IOHIDEventSystemClientCopyServices(c);
    if (!svcs || CFArrayGetCount(svcs) == 0) { fprintf(stderr, "no ALS service\n"); return 2; }
    IOHIDServiceClientRef s = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(svcs, 0);
    for (int i = 0; i < n; i++) {
        IOHIDEventRef e = IOHIDServiceClientCopyEvent(s, kALS, 0, 0);
        struct timeval tv; gettimeofday(&tv, NULL);
        long long t = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
        if (e) { printf("%lld %.4f\n", t, IOHIDEventGetFloatValue(e, kALS << 16)); CFRelease(e); }
        else printf("%lld nan\n", t);
        fflush(stdout);
        usleep(ms * 1000);
    }
    return 0;
}
