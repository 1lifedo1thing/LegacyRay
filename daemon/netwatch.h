#ifndef NETWATCH_H
#define NETWATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* the kernel routing socket tells the daemon when an address, an interface
   or the default route changes, so noticing a wifi to cellular move costs
   nothing while the network stays put. before this the interface list was
   read every two seconds, which kept an idle phone waking up all day.

   netwatch_open returns a nonblocking descriptor for poll, or -1 where there
   is no routing socket (the host test build); the caller then falls back to
   looking now and then */
int netwatch_open(void);

/* read everything queued on the socket. returns 1 when at least one message
   could move the egress (addresses, interface state, a non-host route), 0
   when it was only per-destination clutter, -1 when the socket is gone */
int netwatch_drain(int fd);

void netwatch_close(int fd);

#ifdef __cplusplus
}
#endif

#endif
