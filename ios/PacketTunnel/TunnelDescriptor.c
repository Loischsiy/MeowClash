// Uses the system control socket API, not KVC on packetFlow's private socket.
// The core duplicates the returned fd. Never close the NE-owned original here.
#include "../Shared/MeowCore.h"
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <string.h>
#include <stdint.h>

struct meow_ctl_info { uint32_t ctl_id; char ctl_name[96]; };
struct meow_sockaddr_ctl {
    uint8_t sc_len; uint8_t sc_family; uint16_t ss_sysaddr;
    uint32_t sc_id; uint32_t sc_unit; uint32_t sc_reserved[5];
};
int32_t MeowFindTunnelDescriptor(void) {
    for (int fd = 0; fd < 1024; ++fd) {
        struct meow_sockaddr_ctl address = {0};
        socklen_t length = sizeof(address);
        if (getpeername(fd, (struct sockaddr *)&address, &length) != 0 ||
            address.sc_family != AF_SYSTEM) continue;
        struct meow_ctl_info info = {0};
        strcpy(info.ctl_name, "com.apple.net.utun_control");
        if (ioctl(fd, 0xc0644e03UL, &info) == 0 && address.sc_id == info.ctl_id) return fd;
    }
    return -1;
}
