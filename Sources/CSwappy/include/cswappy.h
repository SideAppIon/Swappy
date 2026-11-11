#ifndef CSWAPPY_H
#define CSWAPPY_H

#include <stdint.h>
#include <sys/types.h>

/// Looks up the kernel ledger layout. Returns 0 on success.
int sw_ledger_init(void);

/// Reads compressed (compressor + swap) memory and physical footprint of a process, in bytes.
/// Works for every process without root. Returns 0 on success.
int sw_ledger_get(pid_t pid, int64_t *compressed, int64_t *footprint);

/// The app a helper process (renderer, XPC service…) belongs to, or `pid` itself.
pid_t sw_responsible_pid(pid_t pid);

/// Reads a numeric SMC sensor (power in W, temperature in °C, fan rpm). Returns 0 on success.
int sw_smc_read(const char *key, double *value);

#endif
