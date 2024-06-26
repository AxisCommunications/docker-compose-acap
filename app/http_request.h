#pragma once
#include <fcgiapp.h>

struct app_state;

typedef void (*restart_dockerd_t)(struct app_state*);

struct restart_dockerd_context {
    restart_dockerd_t restart_dockerd;
    struct app_state* app_state;
};

// Callback function called from a thread by the FCGI server
void http_request_callback(FCGX_Request* request, void* restart_dockerd_context_void_ptr);
