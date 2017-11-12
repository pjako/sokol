#pragma once
#include "sokol_entry.h"
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#ifndef SOKOL_CANVAS_ELEMENT
#define SOKOL_CANVAS_ELEMENT "#canvas"
#endif

static se_key_func _se_on_key_down;
void _se_on_key_down_internal_cb(se_key_func, onst EmscriptenKeyboardEvent* e, void*) {
    if (e->keyCode < 512) {
        _se_on_key_down(e->keyCode);
    }
    return e->keyCode < 32;

}
void se_on_key_down(se_key_func fn) {
    if (!_se_on_key_down) {
        _se_on_key_down = fn;
        emscripten_set_keydown_callback(0, nullptr, true, _se_on_key_down_internal_cb);
    }
}
static se_key_func _se_on_key_up;
void _se_on_key_up_internal_cb(se_key_func, onst EmscriptenKeyboardEvent* e, void*) {
    if (e->keyCode < 512) {
        _se_on_key_up(e->keyCode);
    }
    return e->keyCode < 32;
}
void se_on_key_up(se_key_func fn) {
    if (!_se_on_key_down) {
        _se_on_key_down = fn;
        emscripten_set_keyup_callback(0, nullptr, true, _se_on_key_down_internal_cb);
    }
}

static se_mouse_btn_func _se_on_mouse_btn_down;
void se_on_mouse_btn_down(se_mouse_btn_func) {

}

static se_mouse_btn_func _se_on_mouse_btn_up;
void se_on_mouse_btn_up(se_mouse_btn_func) {

}

static se_mouse_btn_func _se_on_mouse_pos;
void se_on_mouse_pos(se_mouse_pos_func) {

}
static se_mouse_wheel_func _se_on_mouse_wheel;
void se_on_mouse_wheel(se_mouse_wheel_func) {

}

/*// emscripten to ImGui input forwarding
    emscripten_set_keydown_callback(0, nullptr, true, 
        [](int, const EmscriptenKeyboardEvent* e, void*)->EMSCRIPTEN_RESULT {
            if (e->keyCode < 512) {
                ImGui::GetIO().KeysDown[e->keyCode] = true;
            }
            // only forward alpha-numeric keys to browser
            return e->keyCode < 32;
        });
    emscripten_set_keyup_callback(0, nullptr, true, 
        [](int, const EmscriptenKeyboardEvent* e, void*)->EMSCRIPTEN_RESULT {
            if (e->keyCode < 512) {
                ImGui::GetIO().KeysDown[e->keyCode] = false;
            }
            // only forward alpha-numeric keys to browser
            return e->keyCode < 32;
        });
    emscripten_set_keypress_callback(0, nullptr, true,
        [](int, const EmscriptenKeyboardEvent* e, void*)->EMSCRIPTEN_RESULT {
            ImGui::GetIO().AddInputCharacter((ImWchar)e->charCode);
            return true;
        });
    emscripten_set_mousedown_callback("#canvas", nullptr, true, 
        [](int, const EmscriptenMouseEvent* e, void*)->EMSCRIPTEN_RESULT {
            if ((e->button >= 0) && (e->button < 3)) {
                ImGui::GetIO().MouseDown[e->button] = true;
            }
            return true;
        });
    emscripten_set_mouseup_callback("#canvas", nullptr, true, 
        [](int, const EmscriptenMouseEvent* e, void*)->EMSCRIPTEN_RESULT {
            if ((e->button >= 0) && (e->button < 3)) {
                ImGui::GetIO().MouseDown[e->button] = false;
            }
            return true;
        });
    emscripten_set_mousemove_callback("#canvas", nullptr, true, 
        [](int, const EmscriptenMouseEvent* e, void*)->EMSCRIPTEN_RESULT {
            ImGui::GetIO().MousePos.x = (float) e->canvasX;
            ImGui::GetIO().MousePos.y = (float) e->canvasY;
            return true;
        });
    emscripten_set_wheel_callback("#canvas", nullptr, true, 
        [](int, const EmscriptenWheelEvent* e, void*)->EMSCRIPTEN_RESULT {
            ImGui::GetIO().MouseWheel = (float) -0.25f * e->deltaY;
            return true;
        });*/