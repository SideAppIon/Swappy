#include "cswappy.h"
#include <string.h>

// Private but long-stable Darwin interfaces (the same ones `footprint` and Activity Monitor rely on).
struct sw_template_info { char name[32]; char group[32]; char units[32]; };
struct sw_entry_info {
    int64_t balance, credit, debit, limit;
    uint64_t refill_period, last_refill;
};
extern int ledger(int cmd, caddr_t arg1, caddr_t arg2, caddr_t arg3);
extern pid_t responsibility_get_pid_responsible_for_pid(pid_t) __attribute__((weak_import));

#define SW_LEDGER_ENTRY_INFO 1
#define SW_LEDGER_TEMPLATE_INFO 2
#define SW_MAX_ENTRIES 256

static int64_t g_count = 0;
static int g_compressed = -1;
static int g_footprint = -1;

int sw_ledger_init(void) {
    static struct sw_template_info tmpl[SW_MAX_ENTRIES];
    int64_t n = SW_MAX_ENTRIES;
    if (ledger(SW_LEDGER_TEMPLATE_INFO, (caddr_t)tmpl, (caddr_t)&n, NULL) < 0) return -1;
    for (int i = 0; i < n; i++) {
        if (!strncmp(tmpl[i].name, "internal_compressed", 32)) g_compressed = i;
        else if (!strncmp(tmpl[i].name, "phys_footprint", 32)) g_footprint = i;
    }
    g_count = n;
    return (g_compressed >= 0 && g_footprint >= 0) ? 0 : -1;
}

int sw_ledger_get(pid_t pid, int64_t *compressed, int64_t *footprint) {
    if (g_count <= 0) return -1;
    struct sw_entry_info entries[SW_MAX_ENTRIES];
    int64_t n = g_count;
    if (ledger(SW_LEDGER_ENTRY_INFO, (caddr_t)(intptr_t)pid, (caddr_t)entries, (caddr_t)&n) < 0) return -1;
    if (g_compressed >= n || g_footprint >= n) return -1;
    *compressed = entries[g_compressed].balance;
    *footprint = entries[g_footprint].balance;
    return 0;
}

pid_t sw_responsible_pid(pid_t pid) {
    if (responsibility_get_pid_responsible_for_pid == NULL) return pid;
    pid_t r = responsibility_get_pid_responsible_for_pid(pid);
    return r > 0 ? r : pid;
}

// MARK: - SMC sensors

#include <IOKit/IOKitLib.h>

typedef struct { char major, minor, build, reserved[1]; UInt16 release; } sw_smc_vers_t;
typedef struct { UInt16 version, length; UInt32 cpuPLimit, gpuPLimit, memPLimit; } sw_smc_plimit_t;
typedef struct { UInt32 dataSize; UInt32 dataType; char dataAttributes; } sw_smc_keyinfo_t;
typedef struct {
    UInt32 key; sw_smc_vers_t vers; sw_smc_plimit_t pLimitData; sw_smc_keyinfo_t keyInfo;
    char result; char status; char data8; UInt32 data32; unsigned char bytes[32];
} sw_smc_param_t;

static io_connect_t g_smc = 0;
static int g_smc_failed = 0;

static int sw_smc_call(sw_smc_param_t *in, sw_smc_param_t *out) {
    size_t size = sizeof(*out);
    memset(out, 0, sizeof(*out));
    if (IOConnectCallStructMethod(g_smc, 2, in, sizeof(*in), out, &size) != kIOReturnSuccess) return -1;
    return out->result ? -1 : 0;
}

int sw_smc_read(const char *key, double *value) {
    if (g_smc_failed || strlen(key) != 4) return -1;
    if (!g_smc) {
        io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSMC"));
        if (!service || IOServiceOpen(service, mach_task_self(), 0, &g_smc) != kIOReturnSuccess) {
            g_smc_failed = 1;
            if (service) IOObjectRelease(service);
            return -1;
        }
        IOObjectRelease(service);
    }
    sw_smc_param_t in, out;
    memset(&in, 0, sizeof(in));
    in.key = ((UInt32)key[0] << 24) | ((UInt32)key[1] << 16) | ((UInt32)key[2] << 8) | (UInt32)key[3];
    in.data8 = 9; // read key info
    if (sw_smc_call(&in, &out) != 0) return -1;
    UInt32 type = out.keyInfo.dataType, size = out.keyInfo.dataSize;
    if (size == 0 || size > 32) return -1;
    in.keyInfo.dataSize = size;
    in.data8 = 5; // read bytes
    if (sw_smc_call(&in, &out) != 0) return -1;

    char t[5] = { (char)(type >> 24), (char)(type >> 16), (char)(type >> 8), (char)type, 0 };
    if (!strcmp(t, "flt ") && size == 4) {
        float f; memcpy(&f, out.bytes, 4); *value = f;
    } else if ((t[0] == 's' || t[0] == 'f') && t[1] == 'p' && size == 2) {
        int frac = t[3] >= 'a' ? t[3] - 'a' + 10 : t[3] - '0';
        int raw = (out.bytes[0] << 8) | out.bytes[1];
        if (t[0] == 's') raw = (short)raw;
        *value = raw / (double)(1 << frac);
    } else if (t[0] == 'u' && t[1] == 'i' && size <= 4) {
        unsigned v = 0;
        for (UInt32 i = 0; i < size; i++) v = (v << 8) | out.bytes[i];
        *value = v;
    } else {
        return -1;
    }
    return 0;
}
