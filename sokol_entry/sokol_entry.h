#pragma once
#include <wchar.h>
#include <stdbool.h>
#include <stdio.h>


typedef struct {
    bool keyboard;
    bool touch;
    bool mouse;
    bool gamepad;
    bool gyro;
} sg_platform_input_features;

typedef struct {
    bool position;
    bool resize;
    bool framerate;
} sg_platform_control;

typedef struct {
    sg_platform_input_features input;
    sg_platform_control control;
} sg_platform_features;

typedef struct {
    /* Metal-specific */
    const void* mtl_device;
    const void* (*mtl_renderpass_descriptor_cb)(void);
    const void* (*mtl_drawable_cb)(void);
    int mtl_global_uniform_buffer_size;
    int mtl_sampler_cache_size;
} sg_gfx_init_data;

// lifetime functionality
extern void sg_main();
extern void sg_quite();
typedef void(*sg_init_func)(const sg_gfx_init_data*);
typedef void(*sg_frame_func)();
typedef void(*sg_shutdown_func)();

extern void sg_start(int width, int height, int samples, const char* title, sg_init_func, sg_frame_func, sg_shutdown_func);

// screen
extern int sg_get_screen_count();
extern int sg_get_current_screen();
extern float sg_get_screen_x(int screenId);
extern float sg_get_screen_y(int screenId);
extern bool sg_get_screen_position(int screenId, float *x, float *y);
extern float sg_get_screen_width(int screenId);
extern float sg_get_screen_height(int screenId);
extern bool sg_get_screen_size(int screenId, float *width, float *height);
extern float sg_get_screen_dpi(int screenId);


// window
typedef void(*sg_window_minimize_func)(bool);
typedef void(*sg_window_maximize_func)(bool);
typedef void(*sg_window_move_func)(float x, float y);
typedef void(*sg_window_resize_func)(float width, float height);
typedef void(*sg_window_active_func)(bool);
extern void sg_on_window_minimize(sg_window_minimize_func);
extern void sg_on_window_maximize(sg_window_maximize_func);
extern void sg_on_window_move(sg_window_move_func);
extern void sg_on_window_resize(sg_window_resize_func);
extern void sg_on_window_active(sg_window_active_func);

extern bool sg_can_control_window();
extern bool sg_can_go_fullscreen();
extern void sg_set_window_position(float x, float y);
extern void sg_set_window_size(float width, float height);
extern bool sg_get_window_position(float *x, float *y);
extern float sg_get_window_x();
extern float sg_get_window_y();
extern bool sg_get_window_size(int *width, int *height);
extern int sg_get_window_width();
extern int sg_get_window_height();
extern void sg_set_window_resizable(bool);
extern bool sg_is_window_resizeable();
extern void sg_set_window_fullscreen(bool);
extern bool sg_is_window_fullscreen();
extern void sg_set_window_borderless(bool);
extern bool sg_is_window_borderless();
extern void sg_set_window_minimized(bool);
extern bool sg_is_window_minimized();
extern void sg_set_window_maximized(bool);
extern bool sg_is_window_maximized();
extern void sg_set_window_resizable(bool);
extern void move_window_to_foreground();

// misc
extern void sg_request_attention();
typedef void(*sg_file_drop_func)(char *name, int index, int num_files);
extern void sg_on_file_drop(sg_file_drop_func);
extern float _sg_get_time();


// input
typedef void(*sg_key_func)(int key);
typedef void(*sg_char_func)(wchar_t c);
typedef void(*sg_mouse_btn_func)(int btn);
typedef void(*sg_mouse_pos_func)(float x, float y);
typedef void(*sg_mouse_wheel_func)(float v);

/* register key-down callback */
extern void sg_on_key_down(sg_key_func);
/* register key-up callback */
extern void sg_on_key_up(sg_key_func);
/* register character entry callback */
extern void sg_on_char(sg_char_func);
/* register mouse-button-down callback */
extern void sg_on_mouse_btn_down(sg_mouse_btn_func);
/* register mouse-button-up callback */
extern void sg_on_mouse_btn_up(sg_mouse_btn_func);
/* register mouse position callback */
extern void sg_on_mouse_pos(sg_mouse_pos_func);
/* register mouse wheel callback */
extern void sg_on_mouse_wheel(sg_mouse_wheel_func);

// touch
#ifndef SOKOL_MAX_TOUCHES
#define SOKOL_MAX_TOUCHES 10
#endif
typedef struct {
    int identifier;
    float x;
    float y;
    bool changed;
} sg_touch;
typedef struct {
    sg_touch touches[SOKOL_MAX_TOUCHES];
    int num_touches;
    int time;
} sg_touch_event;
typedef void(*touch_event_func)(const sg_touch_event*);
enum sg_touch_event_type {
    sg_touch_event_none = 0,
    sg_touch_event_begin,
    sg_touch_event_move,
    sg_touch_event_cancel,
    sg_touch_event_end,
};
extern void sg_on_touch_begin(touch_event_func);
extern void sg_on_touch_move(touch_event_func);
extern void sg_on_touch_cancel(touch_event_func);
extern void sg_on_touch_end(touch_event_func);




