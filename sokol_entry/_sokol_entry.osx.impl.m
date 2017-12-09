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
#ifndef SOKOL_METAL_MACOS
@interface SokolGLView : NSView /*<NSTextInputClient>*/
@end
#else
@interface SokolMTKView : MTKView
@end
#endif

float _se_restore_rect_x;
float _se_restore_rect_y;
int _se_restore_rect_width;
int _se_restore_rect_height;
static float _se_desired_frame_time;
static bool _se_window_minimized;
static bool _se_window_maximized;
static bool _se_is_window_fullscreen;
static int _se_width;
static int _se_height;
static int _se_sample_count;
static const char* _se_window_title;
static se_init_func _se_init_func;
static se_frame_func _se_frame_func;
static se_shutdown_func _se_shutdown_func;
/* window event callback */
static se_window_minimize_func _se_on_window_minimize;
static se_window_maximize_func _se_on_window_maximize;
static se_window_move_func _se_on_window_move;
static se_window_resize_func _se_on_window_resize;
static se_window_active_func _se_on_window_active;
/* input event callbacks */
static se_key_func _se_key_down_func;
static se_key_func _se_key_up_func;
static se_char_func _se_char_func;
static se_mouse_btn_func _se_mouse_btn_down_func;
static se_mouse_btn_func _se_mouse_btn_up_func;
static se_mouse_pos_func _se_mouse_pos_func;
static se_mouse_wheel_func _se_mouse_wheel_func;
static bool _se_mouse_locked;

static id _se_window_delegate;
static id _se_window;
/* metal specific */
#ifndef SOKOL_METAL_MACOS
static SokolGLView* _se_gl_view;
static id _se_gl_context;
id _se_pixel_format;
#else
static id<MTLDevice> _se_mtl_device;
static id _se_mtk_view_delegate;
static MTKView* _se_mtk_view;
#endif
/* misc */
static se_file_drop_func _se_on_file_drop;

void _se_update_window();
float _se_default_display_scale();

#ifndef SOKOL_METAL_MACOS
void _se_process_events() {
    @autoreleasepool {
        while (true) {
            NSEvent *event = [NSApp
                    nextEventMatchingMask:NSAnyEventMask
                                untilDate:[NSDate distantPast]
                                   inMode:NSDefaultRunLoopMode
                                  dequeue:YES];

            if (event == nil) {
                break;
            }

            [NSApp sendEvent:event];
        }
    }
	//[autoreleasePool drain];
	//autoreleasePool = [[NSAutoreleasePool alloc] init];
}

void _se_run() {
    while(true) {
        const float startTime = _se_get_time();
        _se_process_events();
        if (_se_frame_func) {
            _se_frame_func();
        }
        const float timeLeftInFrame = _se_desired_frame_time - (_se_get_time() - startTime);
        if (timeLeftInFrame > 0.0f) {
            [NSThread sleepForTimeInterval:timeLeftInFrame];
        }
    }
}
#endif

int main(int argc, char * argv[]) {
    //_se_is_window_fullscreen = false;
    se_main();
    return 0;
}



//------------------------------------------------------------------------------
@implementation SokolApp

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

#ifdef SOKOL_METAL_MACOS
/* get an MTLRenderPassDescriptor from the MTKView */
const void* se_mtk_get_render_pass_descriptor() {
    return CFBridgingRetain([_se_mtk_view currentRenderPassDescriptor]);
}

/* get the current CAMetalDrawable from MTKView */
const void* se_mtk_get_drawable() {
    return CFBridgingRetain([_se_mtk_view currentDrawable]);
}
#endif
//------------------------------------------------------------------------------
@implementation SokolAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
    // window delegate
    _se_window_delegate = [[SokolWindowDelegate alloc] init];

    // window
    const NSUInteger style =
        NSWindowStyleMaskTitled |
        NSWindowStyleMaskClosable |
        NSWindowStyleMaskMiniaturizable |
        NSWindowStyleMaskResizable;
    _se_window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, _se_width, _se_height)
        styleMask:style
        backing:NSBackingStoreBuffered
        defer:NO];
    
    [_se_window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [_se_window setTitle:[NSString stringWithUTF8String:_se_window_title]];
    [_se_window setAcceptsMouseMovedEvents:YES];
    [_se_window center];
    [_se_window setRestorable:YES];
    [_se_window setDelegate:_se_window_delegate];

    // view delegate, MTKView and Metal device
    #ifdef SOKOL_METAL_MACOS
    _se_mtk_view_delegate = [[SokolViewDelegate alloc] init];
    _se_mtl_device = MTLCreateSystemDefaultDevice();
    _se_mtk_view = [[SokolMTKView alloc] init];
    [_se_window setContentView:_se_mtk_view];
    [_se_mtk_view setPreferredFramesPerSecond:60];
    [_se_mtk_view setDelegate:_se_mtk_view_delegate];
    [_se_mtk_view setDevice: _se_mtl_device];
    [[_se_mtk_view layer] setMagnificationFilter:kCAFilterNearest];
    [_se_mtk_view setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [_se_mtk_view setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
    CGSize drawable_size = { (CGFloat) _se_width, (CGFloat) _se_height };
    [_se_mtk_view setDrawableSize:drawable_size];
    [_se_mtk_view setSampleCount:_se_sample_count];
    // call the init function
    const se_gfx_init_data ctx = {
        .mtl_device = CFBridgingRetain(_se_mtl_device),
        .mtl_renderpass_descriptor_cb = se_mtk_get_render_pass_descriptor,
        .mtl_drawable_cb = se_mtk_get_drawable,
    };
    if (_se_init_func) {
        _se_init_func(&ctx);
    }
    [_se_window makeKeyAndOrderFront:nil];

    #else

	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6 && _se_default_display_scale() > 1.0f) {
		[_se_gl_view setWantsBestResolutionOpenGLSurface:YES];
		//if (current_videomode.resizable)
		[_se_window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
	}

// Fail if a robustness strategy was requested
    unsigned int attributeCount = 0;
	NSOpenGLPixelFormatAttribute attributes[40];
    // OS X needs non-zero color size, so set resonable values
	const int colorBits = 32;
#define ADD_ATTR(x) \
	{ attributes[attributeCount++] = x; }
#define ADD_ATTR2(x, y) \
	{                   \
		ADD_ATTR(x);    \
		ADD_ATTR(y);    \
	}
	ADD_ATTR(NSOpenGLPFADoubleBuffer);
	ADD_ATTR(NSOpenGLPFAClosestPolicy);

	//we now need OpenGL 3 or better, maybe even change this to 3_3Core ?
	ADD_ATTR2(NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core);

	ADD_ATTR2(NSOpenGLPFAColorSize, colorBits);

	ADD_ATTR2(NSOpenGLPFADepthSize, 24);

	ADD_ATTR2(NSOpenGLPFAStencilSize, 8);

	// NOTE: All NSOpenGLPixelFormats on the relevant cards support sRGB
	//       frambuffer, so there's no need (and no way) to request it

	ADD_ATTR(0);

#undef ADD_ATTR
#undef ADD_ATTR2

	_se_pixel_format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	// ERR_FAIL_COND(_se_pixel_format == nil);

	_se_gl_context = [[NSOpenGLContext alloc] initWithFormat:_se_pixel_format shareContext:nil];

	// ERR_FAIL_COND(context == nil);

	[_se_gl_context setView:_se_gl_view];

	[_se_gl_context makeCurrentContext];

	[NSApp activateIgnoringOtherApps:YES];

    _se_update_window();
    if (_se_init_func) {
        _se_init_func(&(se_gfx_init_data) {});
    }
    [_se_window makeKeyAndOrderFront:nil];
    _se_run();
    #endif
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    return YES;
}
@end

//------------------------------------------------------------------------------
@implementation SokolWindowDelegate
- (BOOL)windowShouldClose:(id)sender {
    if (_se_shutdown_func) {
        _se_shutdown_func();
    }
    return YES;
}
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
- (void)windowDidEnterFullScreen:(NSNotification *)notification {
	_se_is_window_fullscreen = true;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
	_se_is_window_fullscreen = false;
}
#endif // MAC_OS_X_VERSION_MAX_ALLOWED

- (void)windowDidResize:(NSNotification*)notification {
    if (_se_on_window_resize) {
        _se_on_window_resize(
            se_get_window_width(),
            se_get_window_height()
        );
    }
}

- (void)windowDidMove:(NSNotification*)notification {
    if (_se_on_window_move) {
        _se_on_window_move(
            se_get_window_x(),
            se_get_window_y()
        );
    }
}

- (void)windowDidMiniaturize:(NSNotification*)notification {
    if (_se_on_window_minimize) {
        _se_on_window_minimize(true);
    }
}

- (void)windowDidDeminiaturize:(NSNotification*)notification {
    if (_se_on_window_minimize) {
        _se_on_window_minimize(false);
    }
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    if (_se_on_window_active) {
        _se_on_window_active(true);
    }
}

- (void)windowDidResignKey:(NSNotification*)notification {
    if (_se_on_window_active) {
        _se_on_window_active(false);
    }
}

@end

//------------------------------------------------------------------------------
@implementation SokolViewDelegate

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size {
    // FIXME
}
#ifdef SOKOL_METAL_MACOS
- (void)drawInMTKView:(nonnull MTKView*)view {
    @autoreleasepool {
        _se_frame_func();
    }
}
#endif
@end

//------------------------------------------------------------------------------

#ifndef SOKOL_METAL_MACOS
@implementation SokolGLView
#else
@implementation SokolMTKView
#endif

- (BOOL) isOpaque {
    return YES;
}

- (BOOL)canBecomeKey {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (id)init {
    self = [super init];
    //trackingArea = nil;
    //imeMode = false;
    [self updateTrackingAreas];
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    //&&markedText = [[NSMutableAttributedString alloc] init];
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    if (_se_on_file_drop) {
        NSPasteboard *pboard = [sender draggingPasteboard];
        NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
        for (unsigned long i = 0; i < filenames.count; i++) {
            NSString *ns = [filenames objectAtIndex:i];
            char *utfs = strdup([ns UTF8String]);
            NSFileWrapper *fileContents = [pboard readFileWrapper];
            NSData *data = [fileContents regularFileContents];
            NSUInteger len = [data length];
            Byte *byteData = (Byte*)malloc(len);
            memcpy(byteData, [data bytes], len);
            _se_on_file_drop(utfs, i, filenames.count);
            free(utfs);
        }
        
        //NSFileWrapper *fileContents = [pboard readFileWrapper];
        // Perform operation using the file’s contents
    }
	return NO;
}

- (void)mouseDown:(NSEvent*)event {
    if (_se_mouse_btn_down_func) {
        _se_mouse_btn_down_func(0);
    }
}

- (void)mouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)mouseUp:(NSEvent*)event {
    if (_se_mouse_btn_up_func) {
        _se_mouse_btn_up_func(0);
    }
}

- (void)mouseMoved:(NSEvent*)event {
    if (_se_mouse_pos_func) {
#ifdef SOKOL_METAL_MACOS
        const NSRect content_rect = [_se_mtk_view frame];
#else
        const NSRect content_rect = [_se_gl_view frame];
#endif
        const NSPoint pos = [event locationInWindow];
        _se_mouse_pos_func(pos.x, content_rect.size.height - pos.y);
    }
}

- (void)rightMouseDown:(NSEvent*)event {
    if (_se_mouse_btn_down_func) {
        _se_mouse_btn_down_func(1);
    }
}

- (void)rightMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)rightMouseUp:(NSEvent*)event {
    if (_se_mouse_btn_up_func) {
        _se_mouse_btn_up_func(1);
    }
}

- (void)keyDown:(NSEvent*)event {
    if (_se_key_down_func) {
        _se_key_down_func([event keyCode]);
    }
    if (_se_char_func) {
        const NSString* characters = [event characters];
        const NSUInteger length = [characters length];
        for (NSUInteger i = 0; i < length; i++) {
            const unichar codepoint = [characters characterAtIndex:i];
            if ((codepoint & 0xFF00) == 0xF700) {
                continue;
            }
            _se_char_func(codepoint);
        }
    }
}

- (void)flagsChanged:(NSEvent*)event {
    if (_se_key_up_func) {
        _se_key_up_func([event keyCode]);
    }
}

- (void)keyUp:(NSEvent*)event {
    if (_se_key_up_func) {
        _se_key_up_func([event keyCode]);
    }
}

- (void)scrollWheel:(NSEvent*)event {
    if (_se_mouse_wheel_func) {
        double dy = [event scrollingDeltaY];
        if ([event hasPreciseScrollingDeltas]) {
            dy *= 0.1;
        }
        else {
            dy = [event deltaY];
        }
        _se_mouse_wheel_func(dy);
    }
}
@end

//------------------------------------------------------------------------------
void se_start(const se_start_parameter* params) {
    _se_width = params->width > 0 ? params->width : 400;
    _se_height = params->height > 0 ? params->height : 400;
    _se_sample_count = params->samples > 0 ? params->samples : 1;
    _se_window_title = params->title != NULL ? params->title : "SE_OSX";
    _se_init_func = params->init;
    _se_frame_func = params->frame;
    _se_shutdown_func = params->exit;
    _se_desired_frame_time = params->desired_frame_rate > 0 ? params->desired_frame_rate : (1.0f / 60.0f);
    [SokolApp sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id delg = [[SokolAppDelegate alloc] init];
    [NSApp setDelegate:delg];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
}
void se_quite() {
    exit(0);
}

extern void se_on_window_minimize(se_window_minimize_func fn) {
    _se_on_window_minimize = fn;
}
extern void se_on_window_maximize(se_window_minimize_func fn) {
    _se_on_window_maximize = fn;
}
extern void se_on_window_move(se_window_move_func fn) {
    _se_on_window_move = fn;
}
extern void se_on_window_resize(se_window_resize_func fn) {
    _se_on_window_resize = fn;
}
extern void se_on_window_active(se_window_active_func fn) {
    _se_on_window_active = fn;
}


void _se_update_window() {
	bool borderless_full = false;

	if (se_is_window_borderless()) {
		NSRect frameRect = [_se_window frame];
		NSRect screenRect = [[_se_window screen] frame];

		// Check if our window covers up the screen
		if (frameRect.origin.x <= screenRect.origin.x && frameRect.origin.y <= frameRect.origin.y &&
				frameRect.size.width >= screenRect.size.width && frameRect.size.height >= screenRect.size.height) {
			borderless_full = true;
		}
	}

	if (borderless_full) {
		// If the window covers up the screen set the level to above the main menu and hide on deactivate
		[_se_window setLevel:NSMainMenuWindowLevel + 1];
		[_se_window setHidesOnDeactivate:YES];
	} else {
		// Reset these when our window is not a borderless window that covers up the screen
		[_se_window setLevel:NSNormalWindowLevel];
		[_se_window setHidesOnDeactivate:NO];
	}
}

/* screen */
int _se_is_hidpi_allowed() {
    return true;
}

float _se_display_scale(id screen) {
	if (_se_is_hidpi_allowed()) {
		if ([screen respondsToSelector:@selector(backingScaleFactor)]) {
			return fmax(1.0, [screen backingScaleFactor]);
		}
	}
	return 1.0f;
}
float _se_default_display_scale() {
    if (_se_window) {
        return _se_display_scale([_se_window screen]);
    } else {
        return _se_display_scale([NSScreen mainScreen]);
    }
}
void se_set_window_position(float x, float y) {
    float width, height;
	se_get_screen_size(0, &width, &height);
	NSPoint pos;
	float displayScale = _se_default_display_scale();

	pos.x = x / displayScale;
	// For OS X the y starts at the bottom
	pos.y = (height - y) / displayScale;

	[_se_window setFrameTopLeftPoint:pos];

	_se_update_window();
}
void se_set_window_size(float width, float height) {

	if (se_is_window_borderless() == false) {
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

	NSRect frame = [_se_window frame];
	[_se_window setFrame:NSMakeRect(frame.origin.x, frame.origin.y, width, height) display:YES];

	_se_update_window();
};

int _se_get_screen_index(NSScreen *screen) {
    const NSUInteger index = [[NSScreen screens] indexOfObject:screen];
    return index == NSNotFound ? 0 : index;
}
int se_get_screen_count() {
	NSArray *screenArray = [NSScreen screens];
	return [screenArray count];
}
int se_get_current_screen() {
	if (_se_window) {
		return _se_get_screen_index([_se_window screen]);
	} else {
		return _se_get_screen_index([NSScreen mainScreen]);
	}
}
bool se_get_screen_position(int screenId, float *x, float *y) {
	if (screenId < 0) {
		screenId = se_get_current_screen();
	}

	NSArray *screenArray = [NSScreen screens];
    NSUInteger _screenId = (NSUInteger) screenId;
	if (_screenId < [screenArray count]) {
		float displayScale = _se_display_scale([screenArray objectAtIndex:_screenId]);
		NSRect nsrect = [[screenArray objectAtIndex:screenId] frame];
        *x = (float) nsrect.origin.x * displayScale;
        *y = (float) nsrect.origin.y * displayScale;
		return true;
	}
    return false;
}
float se_get_screen_x(int screenId) {
    float x, y;
    se_get_screen_position(screenId, &x, &y);
    return x;
}
float se_get_screen_y(int screenId) {
    float x, y;
    se_get_screen_position(screenId, &x, &y);
    return y;
}
bool se_get_screen_size(int screenId, float *width, float *height) {
	if (screenId < 0) {
		screenId = se_get_current_screen();
	}

	NSArray *screenArray = [NSScreen screens];
    NSUInteger _screenId = (NSUInteger) screenId;
	if (_screenId < [screenArray count]) {
		float displayScale = _se_display_scale([screenArray objectAtIndex:_screenId]);
		// Note: Use frame to get the whole screen size
		NSRect nsrect = [[screenArray objectAtIndex:screenId] frame];
        *width = nsrect.origin.x * displayScale;
        *height = nsrect.origin.y * displayScale;
		return true;
	}
	return false;
}
float se_get_screen_width(int screenId) {
    float width, height;
    se_get_screen_size(screenId, &width, &height);
    return width;
}
float se_get_screen_height(int screenId) {
    float width, height;
    se_get_screen_size(screenId, &width, &height);
    return height;
}
float se_get_screen_dpi(int screenId) {
	if (screenId < 0) {
		screenId = se_get_current_screen();
	}
    NSUInteger _screenId = (NSUInteger) screenId;

	NSArray *screenArray = [NSScreen screens];
	if (_screenId < [screenArray count]) {
		float displayScale = _se_display_scale([screenArray objectAtIndex:_screenId]);
		NSDictionary *description = [[screenArray objectAtIndex:_screenId] deviceDescription];
		NSSize displayPixelSize = [[description objectForKey:NSDeviceSize] sizeValue];
        CGSize displayPhysicalSize = CGDisplayScreenSize([[description objectForKey:@"NSScreenNumber"] unsignedIntValue]);

		return (displayPixelSize.width * 25.4f / displayPhysicalSize.width) * displayScale;
	}

	return 72.0f;
}

bool se_can_control_window() {
    return true;
}
bool se_can_go_fullscreen() {
    return true;
}

void se_set_window_fullscreen(bool enable) {
	if (_se_is_window_fullscreen != enable) {
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
		[_se_window toggleFullScreen:nil];
#else
		[_se_window performZoom:nil];
#endif /*MAC_OS_X_VERSION_MAX_ALLOWED*/
	}
	_se_is_window_fullscreen = enable;
}
bool se_is_window_fullscreen() {
    return [_se_window isZoomed];
}
void se_set_window_borderless(bool borderless) {

	// OrderOut prevents a lose focus bug with the window
	[_se_window orderOut:nil];

	if (borderless) {
		[_se_window setStyleMask:NSWindowStyleMaskBorderless];
	} else {
		[_se_window setStyleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask];

		// Force update of the window styles
		NSRect frameRect = [_se_window frame];
		[_se_window setFrame:NSMakeRect(frameRect.origin.x, frameRect.origin.y, frameRect.size.width + 1, frameRect.size.height) display:NO];
		[_se_window setFrame:frameRect display:NO];

		// Restore the window title
        [_se_window setTitle:[NSString stringWithUTF8String:_se_window_title]];
	}

	_se_update_window();

	[_se_window makeKeyAndOrderFront:nil];
}

bool se_is_window_borderless() {
    return [_se_window styleMask] == NSWindowStyleMaskBorderless;
}
void se_set_window_minimized(bool enabled) {
	if (enabled) {
		[_se_window performMiniaturize:nil];
    } else {
		[_se_window deminiaturize:nil];
    }
}

bool se_is_window_minimized() {
	if ([_se_window respondsToSelector:@selector(isMiniaturized)]) {
        return [_se_window isMiniaturized];
    }

	return _se_window_minimized;
}

void se_set_window_maximized(bool enabled) {
	if (enabled) {
        _se_restore_rect_x = se_get_window_x();
        _se_restore_rect_y = se_get_window_x();
        _se_restore_rect_width = se_get_window_width();
        _se_restore_rect_height = se_get_window_height();
		[_se_window setFrame:[[[NSScreen screens] objectAtIndex:se_get_current_screen()] visibleFrame] display:YES];
	} else {
		se_set_window_size(_se_restore_rect_x, _se_restore_rect_y);
		se_set_window_position(_se_restore_rect_width, _se_restore_rect_height);
	};
	_se_window_maximized = enabled;
}

bool se_is_window_maximized() {
	// don't know
	return _se_window_maximized;
}
void se_set_window_resizable(bool enabled) {
	if (enabled) {
		[_se_window setStyleMask:[_se_window styleMask] | NSResizableWindowMask];
    } else {
		[_se_window setStyleMask:[_se_window styleMask] & ~NSResizableWindowMask];
    }
}
bool se_is_window_resizable() {
	return [_se_window styleMask] & NSResizableWindowMask;
}
void move_window_to_foreground() {
    [_se_window orderFrontRegardless];
}
bool se_get_window_position(float *x, float *y) {
	*x = [_se_window frame].origin.x * _se_default_display_scale();
    *y = [_se_window frame].origin.y * _se_default_display_scale();
    return true;
};
float se_get_window_x() {
	return [_se_window frame].origin.x * _se_default_display_scale();
};
float se_get_window_y() {
	return [_se_window frame].origin.y * _se_default_display_scale();
};

/* return current MTKView drawable width */
bool se_get_window_size(int *width, int *height) {
#ifdef SOKOL_METAL_MACOS
    *width = (int) [_se_mtk_view drawableSize].width;
    *height = (int) [_se_mtk_view drawableSize].height;
#else
    NSSize size = _se_gl_view.frame.size;
    *width = (int) size.width;
    *height = (int) size.height;
#endif
    return true;
}

void se_request_attention() {
    [NSApp requestUserAttention:NSCriticalRequest];
}

float _se_get_time() {
    return (float) CACurrentMediaTime();
}

/* return current MTKView drawable width */
int se_get_window_width() {
    int width, height;
    se_get_window_size(&width, &height);
    return width;
}

/* return current MTKView drawable height */
int se_get_window_height() {
    int width, height;
    se_get_window_size(&width, &height);
    return height;
}

/* misc */
void se_on_file_drop(se_file_drop_func fn) {
    _se_on_file_drop = fn;
}

/* register input callbacks */
void se_on_key_down(se_key_func fn) {
    _se_key_down_func = fn;
}
void se_on_key_up(se_key_func fn) {
    _se_key_up_func = fn;
}
void se_on_char(se_char_func fn) {
    _se_char_func = fn;
}
void se_on_mouse_btn_down(se_mouse_btn_func fn) {
    _se_mouse_btn_down_func = fn;
}
void se_on_mouse_btn_up(se_mouse_btn_func fn) {
    _se_mouse_btn_up_func = fn;
}
void se_on_mouse_pos(se_mouse_pos_func fn) {
    _se_mouse_pos_func = fn;
}
void se_on_mouse_wheel(se_mouse_wheel_func fn) {
    _se_mouse_wheel_func = fn;
}

void se_set_mouse_locked(bool locked) {
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
    _se_mouse_locked = locked;
}
bool se_is_mouse_locked() {
    return _se_mouse_locked;
}
void se_set_mouse_hidden(bool hidden) {
    if (hidden) {
        CGDisplayHideCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(true);
    } else {
        CGDisplayShowCursor(kCGDirectMainDisplay);
        CGAssociateMouseAndMouseCursorPosition(true);
    }
}

/* touch */

void se_on_touch_begin(touch_event_func fn) {
}
void se_on_touch_move(touch_event_func fn) {
}
void se_on_touch_cancel(touch_event_func fn) {
}
void se_on_touch_end(touch_event_func fn) {
}

/* open file for reading */
void* se_open_read_file(const char* path) {

}
/* open file for writing */
void* se_open_write_file(const char* path) {

}
/* write to file, return number of bytes actually written */
void* se_write_file(void* f, const void* ptr, int numBytes) {

}
/* read from file, return number of bytes actually read */
int se_read_file(void* f, void* ptr, int numBytes) {

}
/* seek from start of file */
bool se_seek_file(void* f, int offset) {

}
/* get file size */
extern int se_get_file_size(void* f) {

}
/* close file */
void se_close_file(void* f) {

}
/* get the executeable path */
void se_get_executable_dir(char* nameBuffer, int strLength) {

}


