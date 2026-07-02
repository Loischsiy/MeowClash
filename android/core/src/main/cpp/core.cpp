#ifdef LIBCLASH
#include <jni.h>
#include <cstring>
#include "jni_helper.h"
#include "libclash.h"

extern "C"
JNIEXPORT void JNICALL
Java_com_meowclash_app_core_Core_startTun(JNIEnv *env, jobject, const jint fd, jobject cb) {
    const auto interface = new_global(cb);
    startTUN(fd, interface);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_meowclash_app_core_Core_stopTun(JNIEnv *) {
    stopTun();
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_meowclash_app_core_Core_zapret2Apply(
        JNIEnv *env,
        jobject,
        jstring strategy,
        jstring args_json,
        jstring hosts_json) {
    char *strategy_c = jni_get_string(env, strategy);
    char *args_c = jni_get_string(env, args_json);
    char *hosts_c = jni_get_string(env, hosts_json);
    if (strategy_c == nullptr || args_c == nullptr || hosts_c == nullptr) {
        release_string(&strategy_c);
        release_string(&args_c);
        release_string(&hosts_c);
        return JNI_FALSE;
    }
    const bool ok = zapret2ApplyNative(strategy_c, args_c, hosts_c);
    release_string(&strategy_c);
    release_string(&args_c);
    release_string(&hosts_c);
    return ok ? JNI_TRUE : JNI_FALSE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_meowclash_app_core_Core_zapret2Clear(JNIEnv *) {
    zapret2ClearNative();
}


static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;


static void release_jni_object_impl(void *obj) {
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
}

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    if (tun_interface == nullptr) {
        return;
    }
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(tun_interface),
                        m_tun_interface_protect,
                        fd);
}

static const char *
call_tun_interface_resolve_process_impl(void *tun_interface, int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    ATTACH_JNI();
    const auto j_source = new_string(source);
    const auto j_target = new_string(target);
    const auto packageName = reinterpret_cast<jstring>(env->CallObjectMethod(static_cast<jobject>(tun_interface),
                                                                       m_tun_interface_resolve_process,
                                                                       protocol,
                                                                       j_source,
                                                                       j_target,
                                                                       uid));
    const char* res = get_string(packageName);
    if (res == nullptr) {
        return strdup("");
    }
    return res;
}

extern "C"
JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    initialize_jni(vm, env);

    const auto c_tun_interface = find_class("com/meowclash/app/core/TunInterface");

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)V");
    m_tun_interface_resolve_process = find_method(c_tun_interface, "resolverProcess",
                                                  "(ILjava/lang/String;Ljava/lang/String;I)Ljava/lang/String;");

    registerCallbacks(&call_tun_interface_protect_impl,
                      &call_tun_interface_resolve_process_impl,
                      &release_jni_object_impl);
    return JNI_VERSION_1_6;
}
#endif
