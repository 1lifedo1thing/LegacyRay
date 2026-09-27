#ifndef LEGACYRAY_GEO_CTL_H
#define LEGACYRAY_GEO_CTL_H

/* the daemon side of geo routing: which categories the rules name, keeping
   their extracted lists on disk, and the database the dns proxy consults */

#include <stddef.h>

#include "core/rules.h"
#include "settings.h"

#ifdef __cplusplus
extern "C" {
#endif

/* fetch a url into buf; the daemon passes its tunnel-aware fetch */
typedef int (*geo_fetch_fn)(void *ctx, const char *url, unsigned char *buf,
                            size_t cap, size_t *len, int timeout_ms);

/* load what the rules name from the extracted lists, extracting from a kept
   .dat when a list is missing, and publish it. msg gets a one line summary.
   returns the number of named categories that have no data */
int geo_ctl_reload(const ruleset_t *rules, char *msg, size_t cap);

/* download the geosite .dat and the geoip data the rules need, then reload */
int geo_ctl_update(geo_fetch_fn fetch, void *ctx, const daemon_settings_t *s,
                   const ruleset_t *rules, char *msg, size_t cap);

/* "GEO site <code> <count|missing>" per named category, then the kept files */
size_t geo_ctl_status(const ruleset_t *rules, char *buf, size_t cap);

#ifdef __cplusplus
}
#endif

#endif
