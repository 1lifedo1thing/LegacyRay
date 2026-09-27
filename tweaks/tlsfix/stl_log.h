#ifndef stl_log_h
#define stl_log_h

void stl_log(const char *fmt, ...);

/* the same line, written only when the app's diagnostics switched verbose
   hook logging on. this code runs in every app on every connection, and an
   append to a log file each time costs flash writes and battery for a line
   nobody reads */
void stl_debug(const char *fmt, ...);

#endif