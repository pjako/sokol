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
} se_platform_input_features;

typedef struct {
    bool position;
    bool resize;
    bool framerate;
} se_platform_control;

typedef struct {
    se_platform_input_features input;
    se_platform_control control;
} se_platform_features;

typedef struct {
    /* Metal-specific */
    const void* mtl_device;
    const void* (*mtl_renderpass_descriptor_cb)(void);
    const void* (*mtl_drawable_cb)(void);
    int mtl_global_uniform_buffer_size;
    int mtl_sampler_cache_size;
} se_gfx_init_data;


// lifetime functionality
extern void se_main();
extern void se_quite();
typedef void(*se_init_func)(const se_gfx_init_data*);
typedef void(*se_frame_func)();
typedef void(*se_shutdown_func)();


typedef struct {
    int width;
    int height;
    char* title;
    int samples;
    se_init_func init;
    se_frame_func frame;
    se_shutdown_func exit;
    float desired_frame_rate;
} se_start_parameter;

extern void se_start(const se_start_parameter*);

// screen
extern int se_get_screen_count();
extern int se_get_current_screen();
extern float se_get_screen_x(int screenId);
extern float se_get_screen_y(int screenId);
extern bool se_get_screen_position(int screenId, float *x, float *y);
extern float se_get_screen_width(int screenId);
extern float se_get_screen_height(int screenId);
extern bool se_get_screen_size(int screenId, float *width, float *height);
extern float se_get_screen_dpi(int screenId);


// window
typedef void(*se_window_minimize_func)(bool);
typedef void(*se_window_maximize_func)(bool);
typedef void(*se_window_move_func)(float x, float y);
typedef void(*se_window_resize_func)(float width, float height);
typedef void(*se_window_active_func)(bool);
extern void se_on_window_minimize(se_window_minimize_func);
extern void se_on_window_maximize(se_window_maximize_func);
extern void se_on_window_move(se_window_move_func);
extern void se_on_window_resize(se_window_resize_func);
extern void se_on_window_active(se_window_active_func);

extern bool se_can_control_window();
extern bool se_can_go_fullscreen();
extern void se_set_window_position(float x, float y);
extern void se_set_window_size(float width, float height);
extern bool se_get_window_position(float *x, float *y);
extern float se_get_window_x();
extern float se_get_window_y();
extern bool se_get_window_size(int *width, int *height);
extern int se_get_window_width();
extern int se_get_window_height();
extern void se_set_window_resizable(bool);
extern bool se_is_window_resizeable();
extern void se_set_window_fullscreen(bool);
extern bool se_is_window_fullscreen();
extern void se_set_window_borderless(bool);
extern bool se_is_window_borderless();
extern void se_set_window_minimized(bool);
extern bool se_is_window_minimized();
extern void se_set_window_maximized(bool);
extern bool se_is_window_maximized();
extern void se_set_window_resizable(bool);
extern void move_window_to_foreground();

// misc
extern void se_request_attention();
typedef void(*se_file_drop_func)(char *name, int index, int num_files);
extern void se_on_file_drop(se_file_drop_func);
extern float _se_get_time();


// input
typedef void(*se_key_func)(int key);
typedef void(*se_char_func)(wchar_t c);
typedef void(*se_mouse_btn_func)(int btn);
typedef void(*se_mouse_pos_func)(float x, float y);
typedef void(*se_mouse_wheel_func)(float v);

/* register key-down callback */
extern void se_on_key_down(se_key_func);
/* register key-up callback */
extern void se_on_key_up(se_key_func);
/* register character entry callback */
extern void se_on_char(se_char_func);
/* register mouse-button-down callback */
extern void se_on_mouse_btn_down(se_mouse_btn_func);
/* register mouse-button-up callback */
extern void se_on_mouse_btn_up(se_mouse_btn_func);
/* register mouse position callback */
extern void se_on_mouse_pos(se_mouse_pos_func);
/* register mouse wheel callback */
extern void se_on_mouse_wheel(se_mouse_wheel_func);

// touch
#ifndef SOKOL_MAX_TOUCHES
#define SOKOL_MAX_TOUCHES 10
#endif
typedef struct {
    int identifier;
    float x;
    float y;
    bool changed;
} se_touch;
typedef struct {
    se_touch touches[SOKOL_MAX_TOUCHES];
    int num_touches;
    int time;
} se_touch_event;
typedef void(*touch_event_func)(const se_touch_event*);
enum se_touch_event_type {
    se_touch_event_none = 0,
    se_touch_event_begin,
    se_touch_event_move,
    se_touch_event_cancel,
    se_touch_event_end,
};
extern void se_on_touch_begin(touch_event_func);
extern void se_on_touch_move(touch_event_func);
extern void se_on_touch_cancel(touch_event_func);
extern void se_on_touch_end(touch_event_func);


const char* se_get_config_path();
const char* se_get_data_path();
const char* se_get_cache_path();
const char* se_get_executeable_path();

/* open file for reading */
extern void* se_open_read_file(const char* path);
/* open file for writing */
extern void* se_open_write_file(const char* path);
/* write to file, return number of bytes actually written */
extern void* se_write_file(void* f, const void* ptr, int numBytes);
/* read from file, return number of bytes actually read */
extern int se_read_file(void* f, void* ptr, int numBytes);
/* seek from start of file */
extern bool se_seek_file(void* f, int offset);
/* get file size */
extern int se_get_file_size(void* f);
/* close file */
extern void se_close_file(void* f);
/* get the executeable path */
extern void se_get_executable_dir(char* nameBuffer, int strLength);

