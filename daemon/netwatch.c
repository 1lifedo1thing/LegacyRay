#include "netwatch.h"

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>

#include <string.h>

#if defined(__APPLE__)
/* the ios sdk ships without net/route.h; these are the xnu values, the same
   ones awg_pfroute.c spells out for the messages it writes */
#define NW_RTM_ADD      0x1
#define NW_RTM_DELETE   0x2
#define NW_RTM_CHANGE   0x3
#define NW_RTM_NEWADDR  0xc
#define NW_RTM_DELADDR  0xd
#define NW_RTM_IFINFO   0xe
#define NW_RTF_HOST     0x4
#define NW_RTF_LLINFO   0x400
#define NW_RTF_WASCLONED 0x20000

/* every routing message starts with length, version and type; the route
   messages carry their flags right after the interface index */
struct nw_rt_head {
    unsigned short msglen;
    unsigned char  version;
    unsigned char  type;
    unsigned short index;
    int            flags;
};
#endif

int netwatch_open(void) {
#if defined(__APPLE__)
    int fd = socket(PF_ROUTE, SOCK_RAW, 0);
    if (fd < 0) return -1;
    int fl = fcntl(fd, F_GETFL, 0);
    if (fl < 0 || fcntl(fd, F_SETFL, fl | O_NONBLOCK) != 0) {
        close(fd);
        return -1;
    }
    (void)fcntl(fd, F_SETFD, FD_CLOEXEC);
/* the daemon never writes routes through this socket, and without this every
   one it does write elsewhere would still be echoed back */
    int off = 0;
    (void)setsockopt(fd, SOL_SOCKET, SO_USELOOPBACK, &off, sizeof off);
    return fd;
#else
    return -1;
#endif
}

#if defined(__APPLE__)
static int message_moves_egress(const unsigned char *msg, size_t len) {
    struct nw_rt_head h;
    if (len < 4) return 0;
    memset(&h, 0, sizeof h);
    memcpy(&h, msg, len < sizeof h ? len : sizeof h);
    switch (h.type) {
        case NW_RTM_NEWADDR:
        case NW_RTM_DELADDR:
        case NW_RTM_IFINFO:
            return 1;
        case NW_RTM_ADD:
        case NW_RTM_DELETE:
        case NW_RTM_CHANGE:
/* every new destination clones a host route and every neighbour gets an
   arp entry; neither can move the default egress, and a busy phone makes
   hundreds of them */
            if (len < sizeof h) return 0;
            if (h.flags & (NW_RTF_HOST | NW_RTF_LLINFO | NW_RTF_WASCLONED))
                return 0;
            return 1;
        default:
            return 0;
    }
}
#endif

int netwatch_drain(int fd) {
    if (fd < 0) return -1;
#if defined(__APPLE__)
    int moved = 0;
    /* a routing message is well under a page; the aligned buffer keeps the
       header readable in place on armv7 */
    unsigned char buf[2048];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) {
            if (message_moves_egress(buf, (size_t)n)) moved = 1;
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) break;
        return -1; /* closed or broken */
    }
    return moved;
#else
    return 0;
#endif
}

void netwatch_close(int fd) {
    if (fd >= 0) close(fd);
}
