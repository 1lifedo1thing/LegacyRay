#import "LRStatusStream.h"
#import "LRDaemonClient.h"
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>

static int LRStreamWrite(int fd, const char *text, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, text + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

@implementation LRStatusStream

- (id)initWithDelegate:(id<LRStatusStreamDelegate>)delegate {
    if ((self = [super init])) {
        _delegate = delegate;
        _queue = dispatch_queue_create("com.legacyray.status", NULL);
        _fd = -1;
        _pending = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self close];
    dispatch_release(_queue);
    [_pending release];
    [super dealloc];
}

- (BOOL)isOpen {
    return _source != NULL;
}

- (void)open {
    if (_opening || _source) return;
    _opening = YES;
    NSUInteger generation = ++_generation;
    [self retain];
    dispatch_async(_queue, ^{
        int fd = [[LRDaemonClient shared] openControlSocket];
        if (fd >= 0) {
            static const char watch[] = "WATCH\n";
            int fl = fcntl(fd, F_GETFL, 0);
            if (LRStreamWrite(fd, watch, sizeof watch - 1) != 0 ||
                fl < 0 || fcntl(fd, F_SETFL, fl | O_NONBLOCK) != 0) {
                close(fd);
                fd = -1;
            }
        }
        [_pending setLength:0];
        _eof = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            _opening = NO;
            if (generation != _generation) {
                /* closed while the connect was in flight */
                if (fd >= 0) close(fd);
            } else if (fd < 0) {
                [_delegate statusStreamClosed:self];
            } else {
                [self attach:fd];
            }
            [self release];
        });
    });
}

- (void)attach:(int)fd {
    _fd = fd;
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, _queue);
    if (!_source) {
        close(fd);
        _fd = -1;
        [_delegate statusStreamClosed:self];
        return;
    }
    NSUInteger generation = _generation;
    /* the handler holds the stream; close cancels the source and so ends it */
    dispatch_source_set_event_handler(_source, ^{ [self drain:fd generation:generation]; });
    dispatch_source_set_cancel_handler(_source, ^{ close(fd); });
    dispatch_resume(_source);
}

/* on _queue */
- (void)drain:(int)fd generation:(NSUInteger)generation {
    if (_eof) return;
    char buf[2048];
    BOOL closed = NO;
    for (;;) {
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) { [_pending appendBytes:buf length:(NSUInteger)n]; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) break;
        closed = YES;
        break;
    }
    NSMutableArray *lines = nil;
    const char *bytes = (const char *)[_pending bytes];
    NSUInteger len = [_pending length], start = 0;
    for (NSUInteger i = 0; i < len; ++i) {
        if (bytes[i] != '\n') continue;
        NSString *line = [[NSString alloc] initWithBytes:bytes + start length:i - start
                                                encoding:NSUTF8StringEncoding];
        if (line) {
            if (!lines) lines = [NSMutableArray array];
            [lines addObject:line];
            [line release];
        }
        start = i + 1;
    }
    if (start) [_pending replaceBytesInRange:NSMakeRange(0, start) withBytes:NULL length:0];
    if ([_pending length] > 16384) [_pending setLength:0]; /* not a line protocol any more */
    if (closed) _eof = YES;
    if (!lines && !closed) return;
    NSArray *batch = [lines copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (generation == _generation) {
            for (NSString *line in batch) [_delegate statusStream:self line:line];
            if (closed) {
                [self close];
                [_delegate statusStreamClosed:self];
            }
        }
        [batch release];
    });
}

- (void)renew {
    if (!_source || _fd < 0) return;
    int fd = _fd;
    NSUInteger generation = _generation;
    dispatch_async(_queue, ^{
        if (generation != _generation || _eof) return;
        static const char watch[] = "WATCH\n";
        (void)LRStreamWrite(fd, watch, sizeof watch - 1);
    });
}

- (void)close {
    ++_generation;
    if (_source) {
        dispatch_source_cancel(_source);
        dispatch_release(_source);
        _source = NULL;
    }
    _fd = -1;
}

@end
