#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#include "sokol_entry.h"

@interface SokolApp : NSApplication
@end
@interface SokolAppDelegate<NSApplicationDelegate> : NSObject
@end
@interface SokolWindowDelegate<NSWindowDelegate> : NSObject
@end
@interface SokolViewDelegate<MTKViewDelegate> : NSObject
@end
@interface SokolMTKView : MTKView
@end


float _sg_restore_rect_x;
float _sg_restore_rect_y;
int _sg_restore_rect_width;
int _sg_restore_rect_height;
static bool _sg_window_minimized;
static bool _sg_window_maximized;
static bool _sg_is_window_fullscreen;
static int _sg_width;
static int _sg_height;
static int _sg_sample_count;
static const char* _sg_window_title;
static sg_init_func _sg_init_func;
static sg_frame_func _sg_frame_func;
static sg_shutdown_func _sg_shutdown_func;
/* window event callback */
static sg_window_minimize_func _sg_on_window_minimize;
static sg_window_maximize_func _sg_on_window_maximize;
static sg_window_move_func _sg_on_window_move;
static sg_window_resize_func _sg_on_window_resize;
static sg_window_active_func _sg_on_window_active;
/* input event callbacks */
static sg_key_func _sg_key_down_func;
static sg_key_func _sg_key_up_func;
static sg_char_func _sg_char_func;
static sg_mouse_btn_func _sg_mouse_btn_down_func;
static sg_mouse_btn_func _sg_mouse_btn_up_func;
static sg_mouse_pos_func _sg_mouse_pos_func;
static sg_mouse_wheel_func _sg_mouse_wheel_func;
static bool _sg_mouse_locked;

static id _sg_window_delegate;
static id _sg_window;
static id<MTLDevice> _sg_mtl_device;
static id _sg_mtk_view_delegate;
static MTKView* _sg_mtk_view;

//------------------------------------------------------------------------------
@implementation SokolApp

int main(int argc, char * argv[]) {
    //_sg_is_window_fullscreen = false;
    sg_main();
}


// From http://cocoadev.com/index.pl?GameKeyboardHandlingAlmost
// This works around an AppKit bug, where key up events while holding
// down the command key don't get sent to the key window.
- (void)sendEvent:(NSEvent*) event {
    if ([event type] == NSEventTypeKeyUp && ([event modifierFlags] & NSEventModifierFlagCommand)) {
        [[self keyWindow] sendEvent:event];
    }
    else {
        [super sendEvent:event];
    }
}
@end


/* get an MTLRenderPassDescriptor from the MTKView */
const void* sg_mtk_get_render_pass_descriptor() {
    return CFBridgingRetain([_sg_mtk_view currentRenderPassDescriptor]);
}

/* get the current CAMetalDrawable from MTKView */
const void* sg_mtk_get_drawable() {
    return CFBridgingRetain([_sg_mtk_view currentDrawable]);
}

//------------------------------------------------------------------------------
@implementation SokolAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    // window delegate
    _sg_window_delegate = [[SokolWindowDelegate alloc] init];

    // window
    const NSUInteger style =
        NSWindowStyleMaskTitled |
        NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable |
        NSWindowStyleMaskResizable;
    _sg_window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, _sg_width, _sg_height)
        styleMask:style
        backing:NSBackingStoreBuffered
        defer:NO];
    
    [_sg_window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [_sg_window setTitle:[NSString stringWithUTF8String:_sg_window_title]];
    [_sg_window setAcceptsMouseMovedEvents:YES];
    [_sg_window center];
    [_sg_window setRestorable:YES];
    [_sg_window setDelegate:_sg_window_delegate];

    // view delegate, MTKView and Metal device
    _sg_mtk_view_delegate = [[SokolViewDelegate alloc] init];
    _sg_mtl_device = MTLCreateSystemDefaultDevice();
    _sg_mtk_view = [[SokolMTKView alloc] init];
    [_sg_window setContentView:_sg_mtk_view];
    [_sg_mtk_view setPreferredFramesPerSecond:60];
    [_sg_mtk_view setDelegate:_sg_mtk_view_delegate];
    [_sg_mtk_view setDevice: _sg_mtl_device];
    [[_sg_mtk_view layer] setMagnificationFilter:kCAFilterNearest];
    [_sg_mtk_view setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [_sg_mtk_view setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
    CGSize drawable_size = { (CGFloat) _sg_width, (CGFloat) _sg_height };
    [_sg_mtk_view setDrawableSize:drawable_size];
    [_sg_mtk_view setSampleCount:_sg_sample_count];
    [_sg_window makeKeyAndOrderFront:nil];

    // call the init function
    const sg_gfx_init_data ctx = {
        .mtl_device = CFBridgingRetain(_sg_mtl_device),
        .mtl_renderpass_descriptor_cb = sg_mtk_get_render_pass_descriptor,
        .mtl_drawable_cb = sg_mtk_get_drawable,
    };
    
    _sg_init_func(&ctx);
    [_sg_window toggleFullScreen:nil];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    return YES;
}
@end

//------------------------------------------------------------------------------
@implementation SokolWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
    if (_sg_shutdown_func) {
        _sg_shutdown_func();
    }
    return YES;
}
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
	_sg_is_window_fullscreen = true;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
	_sg_is_window_fullscreen = false;
}
#endif // MAC_OS_X_VERSION_MAX_ALLOWED

- (void)windowDidResize:(NSNotification*)notification {
    if (_sg_on_window_resize) {
        _sg_on_window_resize(
            sg_get_window_width(),
            sg_get_window_height()
        );
    }
}

- (void)windowDidMove:(NSNotification*)notification {
    if (_sg_on_window_move) {
        _sg_on_window_move(
            sg_get_window_x(),
            sg_get_window_y()
        );
    }
}

- (void)windowDidMiniaturize:(NSNotification*)notification {
    if (_sg_on_window_minimize) {
        _sg_on_window_minimize(true);
    }
}

- (void)windowDidDeminiaturize:(NSNotification*)notification {
    if (_sg_on_window_minimize) {
        _sg_on_window_minimize(false);
    }
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    if (_sg_on_window_active) {
        _sg_on_window_active(true);
    }
}

- (void)windowDidResignKey:(NSNotification*)notification {
    if (_sg_on_window_active) {
        _sg_on_window_active(false);
    }
}

@end

//------------------------------------------------------------------------------
@implementation SokolViewDelegate

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size {
    // FIXME
}

- (void)drawInMTKView:(nonnull MTKView*)view {
    @autoreleasepool {
        _sg_frame_func();
    }
}
@end

//------------------------------------------------------------------------------
@implementation SokolMTKView

- (BOOL) isOpaque {
    return YES;
}

- (BOOL)canBecomeKey {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)mouseDown:(NSEvent*)event {
    if (_sg_mouse_btn_down_func) {
        _sg_mouse_btn_down_func(0);
    }
}

- (void)mouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)mouseUp:(NSEvent*)event {
    if (_sg_mouse_btn_up_func) {
        _sg_mouse_btn_up_func(0);
    }
}

- (void)mouseMoved:(NSEvent*)event {
    if (_sg_mouse_pos_func) {
        const NSRect content_rect = [_sg_mtk_view frame];
        const NSPoint pos = [event locationInWindow];
        _sg_mouse_pos_func(pos.x, content_rect.size.height - pos.y);
    }
}

- (void)rightMouseDown:(NSEvent*)event {
    if (_sg_mouse_btn_down_func) {
        _sg_mouse_btn_down_func(1);
    }
}

- (void)rightMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)rightMouseUp:(NSEvent*)event {
    if (_sg_mouse_btn_up_func) {
        _sg_mouse_btn_up_func(1);
    }
}

- (void)keyDown:(NSEvent*)event {
    if (_sg_key_down_func) {
        _sg_key_down_func([event keyCode]);
    }
    if (_sg_char_func) {
        const NSString* characters = [event characters];
        const NSUInteger length = [characters length];
        for (NSUInteger i = 0; i < length; i++) {
            const unichar codepoint = [characters characterAtIndex:i];
            if ((codepoint & 0xFF00) == 0xF700) {
                continue;
            }
            _sg_char_func(codepoint);
        }
    }
}

- (void)flagsChanged:(NSEvent*)event {
    if (_sg_key_up_func) {
        _sg_key_up_func([event keyCode]);
    }
}

- (void)keyUp:(NSEvent*)event {
    if (_sg_key_up_func) {
        _sg_key_up_func([event keyCode]);
    }
}

- (void)scrollWheel:(NSEvent*)event {
    if (_sg_mouse_wheel_func) {
        double dy = [event scrollingDeltaY];
        if ([event hasPreciseScrollingDeltas]) {
            dy *= 0.1;
        }
        else {
            dy = [event deltaY];
        }
        _sg_mouse_wheel_func(dy);
    }
}
@end

//------------------------------------------------------------------------------
void sg_start(int w, int h, int smp_count, const char* title, sg_init_func ifun, sg_frame_func ffun, sg_shutdown_func sfun) {
    _sg_width = w;
    _sg_height = h;
    _sg_sample_count = smp_count;
    _sg_window_title = title;
    _sg_init_func = ifun;
    _sg_frame_func = ffun;
    _sg_shutdown_func = sfun;
    _sg_key_down_func = 0;
    _sg_key_up_func = 0;
    _sg_char_func = 0;
    _sg_mouse_btn_down_func = 0;
    _sg_mouse_btn_up_func = 0;
    _sg_mouse_pos_func = 0;
    _sg_mouse_wheel_func = 0;
    [SokolApp sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id delg = [[SokolAppDelegate alloc] init];
    [NSApp setDelegate:delg];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
}
void sg_quite() {
    exit(0);
}

extern void sg_on_window_minimize(sg_window_minimize_func fn) {
    _sg_on_window_minimize = fn;
}
extern void sg_on_window_maximize(sg_window_minimize_func fn) {
    _sg_on_window_maximize = fn;
}
extern void sg_on_window_move(sg_window_move_func fn) {
    _sg_on_window_move = fn;
}
extern void sg_on_window_resize(sg_window_resize_func fn) {
    _sg_on_window_resize = fn;
}
extern void sg_on_window_active(sg_window_active_func fn) {
    _sg_on_window_active = fn;
}


void _sg_update_window() {
	bool borderless_full = false;

	if (sg_is_window_borderless()) {
		NSRect frameRect = [_sg_window frame];
		NSRect screenRect = [[_sg_window screen] frame];

		// Check if our window covers up the screen
		if (frameRect.origin.x <= screenRect.origin.x && frameRect.origin.y <= frameRect.origin.y &&
				frameRect.size.width >= screenRect.size.width && frameRect.size.height >= screenRect.size.height) {
			borderless_full = true;
		}
	}

	if (borderless_full) {
		// If the window covers up the screen set the level to above the main menu and hide on deactivate
		[_sg_window setLevel:NSMainMenuWindowLevel + 1];
		[_sg_window setHidesOnDeactivate:YES];
	} else {
		// Reset these when our window is not a borderless window that covers up the screen
		[_sg_window setLevel:NSNormalWindowLevel];
		[_sg_window setHidesOnDeactivate:NO];
	}
}

/* screen */
int _sg_is_hidpi_allowed() {
    return true;
}

float _sg_display_scale(id screen) {
	if (_sg_is_hidpi_allowed()) {
		if ([screen respondsToSelector:@selector(backingScaleFactor)]) {
			return fmax(1.0, [screen backingScaleFactor]);
		}
	}
	return 1.0f;
}
float _sg_default_display_scale() {
    if (_sg_window) {
        return _sg_display_scale([_sg_window screen]);
    } else {
        return _sg_display_scale([NSScreen mainScreen]);
    }
}
void sg_set_window_position(float x, float y) {
    float width, height;
	sg_get_screen_size(0, &width, &height);
	NSPoint pos;
	float displayScale = _sg_default_display_scale();

	pos.x = x / displayScale;
	// For OS X the y starts at the bottom
	pos.y = (height - y) / displayScale;

	[_sg_window setFrameTopLeftPoint:pos];

	_sg_update_window();
}
void sg_set_window_size(float width, float height) {

	if (sg_is_window_borderless() == false) {
		// NSRect used by setFrame includes the title bar, so add it to our size.y
		CGFloat menuBarHeight = [[[NSApplication sharedApplication] mainMenu] menuBarHeight];
		if (menuBarHeight != 0.f) {
			height += menuBarHeight;
#if MAC_OS_X_VERSION_MAX_ALLOWED <= 101104
		} else {
			height += [[NSStatusBar systemStatusBar] thickness];
#endif
		}
	}

	NSRect frame = [_sg_window frame];
	[_sg_window setFrame:NSMakeRect(frame.origin.x, frame.origin.y, width, height) display:YES];

	_sg_update_window();
};

int _sg_get_screen_index(NSScreen *screen) {
    const NSUInteger index = [[NSScreen screens] indexOfObject:screen];
    return index == NSNotFound ? 0 : index;
}
int sg_get_screen_count() {
	NSArray *screenArray = [NSScreen screens];
	return [screenArray count];
}
int sg_get_current_screen() {
	if (_sg_window) {
		return _sg_get_screen_index([_sg_window screen]);
	} else {
		return _sg_get_screen_index([NSScreen mainScreen]);
	}
}
bool sg_get_screen_position(int screenId, float *x, float *y) {
	if (screenId < 0) {
		screenId = sg_get_current_screen();
	}

	NSArray *screenArray = [NSScreen screens];
    NSUInteger _screenId = (NSUInteger) screenId;
	if (_screenId < [screenArray count]) {
		float displayScale = _sg_display_scale([screenArray objectAtIndex:_screenId]);
		NSRect nsrect = [[screenArray objectAtIndex:screenId] frame];
        *x = (float) nsrect.origin.x * displayScale;
        *y = (float) nsrect.origin.y * displayScale;
		return true;
	}
    return false;
}
float sg_get_screen_x(int screenId) {
    float x, y;
    sg_get_screen_position(screenId, &x, &y);
    return x;
}
float sg_get_screen_y(int screenId) {
    float x, y;
    sg_get_screen_position(screenId, &x, &y);
    return y;
}
bool sg_get_screen_size(int screenId, float *width, float *height) {
	if (screenId < 0) {
		screenId = sg_get_current_screen();
	}

	NSArray *screenArray = [NSScreen screens];
    NSUInteger _screenId = (NSUInteger) screenId;
	if (_screenId < [screenArray count]) {
		float displayScale = _sg_display_scale([screenArray objectAtIndex:_screenId]);
		// Note: Use frame to get the whole screen size
		NSRect nsrect = [[screenArray objectAtIndex:screenId] frame];
        *width = nsrect.origin.x * displayScale;
        *height = nsrect.origin.y * displayScale;
		return true;
	}
	return false;
}
float sg_get_screen_width(int screenId) {
    float width, height;
    sg_get_screen_size(screenId, &width, &height);
    return width;
}
float sg_get_screen_height(int screenId) {
    float width, height;
    sg_get_screen_size(screenId, &width, &height);
    return height;
}
float sg_get_screen_dpi(int screenId) {
	if (screenId < 0) {
		screenId = sg_get_current_screen();
	}
    NSUInteger _screenId = (NSUInteger) screenId;

	NSArray *screenArray = [NSScreen screens];
	if (_screenId < [screenArray count]) {
		float displayScale = _sg_display_scale([screenArray objectAtIndex:_screenId]);
		NSDictionary *description = [[screenArray objectAtIndex:_screenId] deviceDescription];
		NSSize displayPixelSize = [[description objectForKey:NSDeviceSize] sizeValue];
        CGSize displayPhysicalSize = CGDisplayScreenSize([[description objectForKey:@"NSScreenNumber"] unsignedIntValue]);

		return (displayPixelSize.width * 25.4f / displayPhysicalSize.width) * displayScale;
	}

	return 72.0f;
}

bool sg_can_control_window() {
    return true;
}
bool sg_can_go_fullscreen() {
    return true;
}

void sg_set_window_fullscreen(bool enable) {
	if (_sg_is_window_fullscreen != enable) {
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
		[_sg_window toggleFullScreen:nil];
#else
		[_sg_window performZoom:nil];
#endif /*MAC_OS_X_VERSION_MAX_ALLOWED*/
	}
	_sg_is_window_fullscreen = enable;
}
bool sg_is_window_fullscreen() {
    return [_sg_window isZoomed];
}
void sg_set_window_borderless(bool borderless) {

	// OrderOut prevents a lose focus bug with the window
	[_sg_window orderOut:nil];

	if (borderless) {
		[_sg_window setStyleMask:NSWindowStyleMaskBorderless];
	} else {
		[_sg_window setStyleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask];

		// Force update of the window styles
		NSRect frameRect = [_sg_window frame];
		[_sg_window setFrame:NSMakeRect(frameRect.origin.x, frameRect.origin.y, frameRect.size.width + 1, frameRect.size.height) display:NO];
		[_sg_window setFrame:frameRect display:NO];

		// Restore the window title
        [_sg_window setTitle:[NSString stringWithUTF8String:_sg_window_title]];
	}

	_sg_update_window();

	[_sg_window makeKeyAndOrderFront:nil];
}

bool sg_is_window_borderless() {
    return [_sg_window styleMask] == NSWindowStyleMaskBorderless;
}
void sg_set_window_minimized(bool enabled) {
	if (enabled) {
		[_sg_window performMiniaturize:nil];
    } else {
		[_sg_window deminiaturize:nil];
    }
}

bool sg_is_window_minimized() {
	if ([_sg_window respondsToSelector:@selector(isMiniaturized)]) {
        return [_sg_window isMiniaturized];
    }

	return _sg_window_minimized;
}

void sg_set_window_maximized(bool enabled) {
	if (enabled) {
        _sg_restore_rect_x = sg_get_window_x();
        _sg_restore_rect_y = sg_get_window_x();
        _sg_restore_rect_width = sg_get_window_width();
        _sg_restore_rect_height = sg_get_window_height();
		[_sg_window setFrame:[[[NSScreen screens] objectAtIndex:sg_get_current_screen()] visibleFrame] display:YES];
	} else {
		sg_set_window_size(_sg_restore_rect_x, _sg_restore_rect_y);
		sg_set_window_position(_sg_restore_rect_width, _sg_restore_rect_height);
	};
	_sg_window_maximized = enabled;
}

bool sg_is_window_maximized() {
	// don't know
	return _sg_window_maximized;
}
void sg_set_window_resizable(bool enabled) {
	if (enabled) {
		[_sg_window setStyleMask:[_sg_window styleMask] | NSResizableWindowMask];
    } else {
		[_sg_window setStyleMask:[_sg_window styleMask] & ~NSResizableWindowMask];
    }
}
bool sg_is_window_resizable() {
	return [_sg_window styleMask] & NSResizableWindowMask;
}
void move_window_to_foreground() {
    [_sg_window orderFrontRegardless];
}
bool sg_get_window_position(float *x, float *y) {
	*x = [_sg_window frame].origin.x * _sg_default_display_scale();
    *y = [_sg_window frame].origin.y * _sg_default_display_scale();
    return true;
};
float sg_get_window_x() {
	return [_sg_window frame].origin.x * _sg_default_display_scale();
};
float sg_get_window_y() {
	return [_sg_window frame].origin.y * _sg_default_display_scale();
};

/* return current MTKView drawable width */
bool sg_get_window_size(int *width, int *height) {
    *width = (int) [_sg_mtk_view drawableSize].width;
    *height = (int) [_sg_mtk_view drawableSize].height;
    return true;
}

void sg_request_attention() {
    [NSApp requestUserAttention:NSCriticalRequest];
}

/* return current MTKView drawable width */
int sg_get_window_width() {
    return (int) [_sg_mtk_view drawableSize].width;
}

/* return current MTKView drawable height */
int sg_get_window_height() {
    return (int) [_sg_mtk_view drawableSize].height;
}

/* register input callbacks */
void sg_on_key_down(sg_key_func fn) {
    _sg_key_down_func = fn;
}
void sg_on_key_up(sg_key_func fn) {
    _sg_key_up_func = fn;
}
void sg_on_char(sg_char_func fn) {
    _sg_char_func = fn;
}
void sg_on_mouse_btn_down(sg_mouse_btn_func fn) {
    _sg_mouse_btn_down_func = fn;
}
void sg_on_mouse_btn_up(sg_mouse_btn_func fn) {
    _sg_mouse_btn_up_func = fn;
}
void sg_on_mouse_pos(sg_mouse_pos_func fn) {
    _sg_mouse_pos_func = fn;
}
void sg_on_mouse_wheel(sg_mouse_wheel_func fn) {
    _sg_mouse_wheel_func = fn;
}

void sg_set_mouse_locked(bool locked) {
    // Apple Docs state that the display parameter is not used.
    // "This parameter is not used. By default, you may pass kCGDirectMainDisplay."
    // https://developer.apple.com/library/mac/documentation/graphicsimaging/reference/Quartz_Services_Ref/Reference/reference.html
    if (locked) {
        CGDisplayHideCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(false);
    } else {
        CGDisplayShowCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(true);
    }
    _sg_mouse_locked = locked;
}
bool sg_is_mouse_locked() {
    return _sg_mouse_locked;
}
void sg_set_mouse_hidden(bool hidden) {
    if (hidden) {
        CGDisplayHideCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(true);
    } else {
        CGDisplayShowCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(true);
    }
}
