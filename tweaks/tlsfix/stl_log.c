#define _DEFAULT_SOURCE

#include "stl_log.h"

#include <stdarg.h>
#include <stdio.h>
#include <time.h>
#include <unistd.h>

#define stl_log_path "/var/log/legacyraytlsfix.log"
#define stl_verbose_flag "/var/mobile/Library/Preferences/LegacyRay/tlsfix-verbose"

static void stl_vlog(const char *fmt, va_list ap) {
    FILE *f = fopen(stl_log_path, "a");
    if (!f) return;

    time_t now = time(NULL);
    struct tm tm;
    localtime_r(&now, &tm);
    fprintf(f, "%04d-%02d-%02d %02d:%02d:%02d ",
            tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
            tm.tm_hour, tm.tm_min, tm.tm_sec);
    fprintf(f, "[pid %d] ", (int)getpid());
    vfprintf(f, fmt, ap);
    fputc('\n', f);
    fclose(f);
}

void stl_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    stl_vlog(fmt, ap);
    va_end(ap);
}

void stl_debug(const char *fmt, ...) {
    static int verbose = -1; /* looked up once per process */
    if (verbose < 0) verbose = access(stl_verbose_flag, F_OK) == 0;
    if (!verbose) return;
    va_list ap;
    va_start(ap, fmt);
    stl_vlog(fmt, ap);
    va_end(ap);
}