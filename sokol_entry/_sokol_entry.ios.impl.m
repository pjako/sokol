#import <UIKit/UIKit.h>
#include "sokol_entry.h"
#if SOKOL_METAL_IOS
#import <MetalKit/MetalKit.h>
#else
#import <GLKit/GLKit.h>
#endif

@interface SokolViewDelegate<MTKViewDelegate> : NSObject
@end

@interface SokolAppDelegate<NSApplicationDelegate> : NSObject
@end

// a delegate for touch events, and our own GLKView/MTKView which delegates touch events
@protocol touchDelegate
- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event;
- (void) touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event;
- (void) touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event;
- (void) touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event;
@end

#if SOKOL_METAL_IOS
@interface SokolMTKView: MTKView
#else
@interface SokolGLKView: GLKView
#endif
@property (nonatomic, retain) id<touchDelegate> touchDelegate;
- (void) setTouchDelegate:(id<touchDelegate>)dlg;
@end

static id _se_window;
static id _se_app_delegate;

static se_init_func _se_init_func;
static se_frame_func _se_frame_func;
static se_shutdown_func _se_shutdown_func;


/* touch */
touch_event_func _se_on_touch_begin;
touch_event_func _se_on_touch_move;
touch_event_func _se_on_touch_cancel;
touch_event_func _se_on_touch_end;


#if SOKOL_METAL_IOS
/* metal specific */
static id _se_mtk_view_delegate;
static id<MTLDevice> _se_mtl_device;
static MTKView* _se_mtk_view;
static id _se_mtk_view_controller;
#else
static id _se_eagl_context;
static id _se_glk_view;
static id _se_glk_view_controller;
static SokolGLKView* _se_glk_view;
static GLKViewController* _se_glk_view_controller;
#endif
#if SOKOL_METAL_IOS
/* get an MTLRenderPassDescriptor from the MTKView */
const void* se_mtk_get_render_pass_descriptor() {
    return (__bridge const void*) [_se_mtk_view currentRenderPassDescriptor];
}

/* get the current CAMetalDrawable from MTKView */
const void* se_mtk_get_drawable() {
    return (__bridge const void*) [_se_mtk_view currentDrawable];
}
#endif

@implementation SokolAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // get pointer to our app delegate
    _se_app_delegate = [UIApplication sharedApplication].delegate;
    
    // create the app's main window
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    _se_window = [[UIWindow alloc] initWithFrame:mainScreenBounds];

    #if SOKOL_METAL_IOS
    // view delegate, MTKView and metal device
    this->mtkViewDelegate = [[oryolViewDelegate alloc] init];
    _se_mtl_device = MTLCreateSystemDefaultDevice();
    _se_mtk_view = [[SokolMTKView alloc] init];
    [_se_mtk_view setPreferredFramesPerSecond:60];
    [_se_mtk_view setDelegate:_se_mtk_view_delegate];
    [_se_mtk_view setDevice:this->mtlDevice];
    [_se_mtk_view setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [_se_mtk_view setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
    [_se_mtk_view setUserInteractionEnabled:YES];
    [_se_mtk_view setMultipleTouchEnabled:YES];
    [_se_window addSubview:_se_mtk_view];

    // create view controller
    _se_mtk_view_controller = [[UIViewController<MTKViewDelegate> alloc] init];
    [_se_mtk_view_controller setView:_se_mtk_view];
    [_se_window setRootViewController:_se_mtk_view_controller];

    // call the init function
    const se_gfx_init_data ctx = {
        .mtl_device = CFBridgingRetain(_se_mtl_device),
        .mtl_renderpass_descriptor_cb = se_mtk_get_render_pass_descriptor,
        .mtl_drawable_cb = se_mtk_get_drawable,
    };
    @autoreleasepool {
        _se_init_func(&ctx);
    }

    #else
    // create GL context and GLKView
    // NOTE: the drawable properties will be overridden later in iosDisplayMgr!
    #ifdef SOKOL_GLES2
    _se_eagl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    #else
    _se_eagl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    #endif
    _se_glk_view = [[SokolGLKView alloc] initWithFrame:mainScreenBounds];
    _se_glk_view.drawableColorFormat   = GLKViewDrawableColorFormatRGBA8888;
    _se_glk_view.drawableDepthFormat   = GLKViewDrawableDepthFormat24;
    _se_glk_view.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
    _se_glk_view.drawableMultisample   = GLKViewDrawableMultisampleNone;
    _se_glk_view.context = this->eaglContext;
    _se_glk_view.delegate = this->appDelegate;
    _se_glk_view.enableSetNeedsDisplay = NO;
    _se_glk_view.userInteractionEnabled = YES;
    _se_glk_view.multipleTouchEnabled = YES;
    _se_glk_view.contentScaleFactor = 1.0f;     // FIXME: this caused different behaviour than Metal path!!!
    [_se_window addSubview:_se_glk_view];

    // create a GLKViewController
    _se_glk_view_controller = [[GLKViewController alloc] init];
    _se_glk_view_controller.view = _se_glk_view;
    _se_glk_view_controller.preferredFramesPerSecond = 60;
    _se_window.rootViewController = _se_glk_view_controller;

    // call the init function
    const se_gfx_init_data ctx = {
        #ifdef SOKOL_GLES2
        .gl_force_gles2 = true,
        #else
        .gl_force_gles2 = false,
        #endif
    };
    @autoreleasepool {
        _se_init_func(&ctx);
    }

    #endif

    // make window visible
    _se_window.backgroundColor = [UIColor blackColor];
    [_se_window makeKeyAndVisible];
}


- (void)applicationWillResignActive:(UIApplication *)application {

}

- (void)applicationDidEnterBackground:(UIApplication *)application {

}

- (void)applicationWillEnterForeground:(UIApplication *)application {

}

- (void)applicationDidBecomeActive:(UIApplication *)application {

}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (_se_shutdown_func) {
        @autoreleasepool {
            _se_shutdown_func();
        }
    }
}

#ifndef SOKOL_METAL_IOS
- (void)_se_glk_view:(GLKView*)view drawInRect:(CGRect)rect {
    if (_se_frame_func) {
        @autoreleasepool {
            _se_frame_func();
        }
    }
}
#endif
@end

se_touch_event _se_on_touches(se_touch_event_type type, (NSSet*) touches, NSArray *tlist) {
    se_touch_event newEvent;
    newEvent.type = type;
    newEvent.time = _se_get_time();
    //newEvent.time = Oryol::Clock::Now();
    NSEnumerator* enumerator = [[event allTouches] objectEnumerator];
	for (unsigned int i = 0; i < [tlist count]; i++) {
        if (i >= SOKOL_MAX_TOUCHES) {
            break;
        }
        UITouch *curTouch = [tlist objectAtIndex:i];
        CGPoint pos = [curTouch locationInView:curTouch.view];
        newEvent.points[i] = {
            .identifier = (unsigned int) curTouch,
            .x = pos.x * _se_mouse_scale,
            .y = pos.y * _se_mouse_scale,
            .changed = [touches containsObject:curTouch],
        };
    }
    newEvent.num_touches = [tlist count];
    return newEvent;
}

#if ORYOL_METAL
@implementation oryolMTKView
#else
@implementation oryolGLKView
#endif
@synthesize touchDelegate;

- (void) setTouchDelegate:(id<touchDelegate>)dlg {
    touchDelegate = dlg;
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
    if (_se_on_touch_begin) {
        _se_on_touch_begin(&_se_on_touches(se_touch_event_begin, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    if (_se_on_touch_move) {
        _se_on_touch_move(&_se_on_touches(se_touch_event_move, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    if (_se_on_touch_end) {
        _se_on_touch_end(&_se_on_touches(se_touch_event_end, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_se_on_touch_cancel) {
        _se_on_touch_cancel(&_se_on_touches(se_touch_event_cancel, [[event allTouches] allObjects], touches));
    }
}
@end

#if SOKOL_METAL_IOS

@implementation SokolViewDelegate
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // FIXME(?)
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (_se_frame_func) {
        @autoreleasepool {
            _se_frame_func();
        }
    }
}
@end
#endif

//------------------------------------------------------------------------------
void se_start(int w, int h, int smp_count, const char* title, se_init_func ifun, se_frame_func ffun, se_shutdown_func sfun) {
    _se_sample_count = smp_count;
    _se_window_title = title;
    _se_init_func = ifun;
    _se_frame_func = ffun;
    _se_shutdown_func = sfun;
    [SokolApp sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id delg = [[SokolAppDelegate alloc] init];
    [NSApp setDelegate:delg];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
}


/* touch */
void se_on_touch_begin(touch_event_func fn) {
    _se_on_touch_begin = fn;
}
void se_on_touch_move(touch_event_func fn) {
    _se_on_touch_move = fn;
}
void se_on_touch_cancel(touch_event_func fn) {
    _se_on_touch_cancel = fn;
}
void se_on_touch_end(touch_event_func fn) {
    _se_on_touch_end = fn;
}

/* misc */
float _se_get_time() {
    return (float) CACurrentMediaTime();
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        se_main();
    }
    return 0;
}