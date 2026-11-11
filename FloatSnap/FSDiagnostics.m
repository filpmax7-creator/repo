#import "FSDiagnostics.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>

void FSLog(NSString *message) {
    NSLog(@"[FloatSnap] %@", message);
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("local.floatsnap.diagnostics", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(queue, ^{
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *path = [directory stringByAppendingPathComponent:@"FloatSnap.log"];
        int fd = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0600);
        if (fd < 0) return;
        struct stat info;
        if (fstat(fd, &info) == 0 && info.st_size > 65536) {
            if (ftruncate(fd, 0) != 0) { close(fd); return; }
        }
        NSData *line = [[NSString stringWithFormat:@"%@ %@\n", [NSDate date], message] dataUsingEncoding:NSUTF8StringEncoding];
        const char *bytes = line.bytes;
        size_t remaining = line.length;
        while (remaining) {
            ssize_t count = write(fd, bytes, remaining);
            if (count <= 0) break;
            bytes += count;
            remaining -= (size_t)count;
        }
        close(fd);
    });
}
