#ifndef MeowCore_h
#define MeowCore_h
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void meowSetTunnelProcess(int extension);
char *meowInvokeAction(char *input);
char *meowDrainEvents(void);
void meowFreeCString(char *value);
char *meowStartTun(int fd);
void meowStopTun(void);
void meowSuspendCore(void);
int32_t MeowFindTunnelDescriptor(void);
#ifdef __cplusplus
}
#endif
#endif
