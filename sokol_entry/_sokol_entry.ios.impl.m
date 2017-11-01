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

static id _sg_window;
static id _sg_app_delegate;

static sg_init_func _sg_init_func;
static sg_frame_func _sg_frame_func;
static sg_shutdown_func _sg_shutdown_func;


/* touch */
touch_event_func _sg_on_touch_begin;
touch_event_func _sg_on_touch_move;
touch_event_func _sg_on_touch_cancel;
touch_event_func _sg_on_touch_end;


#if SOKOL_METAL_IOS
/* metal specific */
static id _sg_mtk_view_delegate;
static id<MTLDevice> _sg_mtl_device;
static MTKView* _sg_mtk_view;
static id _sg_mtk_view_controller;
#else
static id _sg_eagl_context;
static id _sg_glk_view;
static id _sg_glk_view_controller;
static SokolGLKView* _sg_glk_view;
static GLKViewController* _sg_glk_view_controller;
#endif
#if SOKOL_METAL_IOS
/* get an MTLRenderPassDescriptor from the MTKView */
const void* sg_mtk_get_render_pass_descriptor() {
    return CFBridgingRetain([_sg_mtk_view currentRenderPassDescriptor]);
}

/* get the current CAMetalDrawable from MTKView */
const void* sg_mtk_get_drawable() {
    return CFBridgingRetain([_sg_mtk_view currentDrawable]);
}
#endif

@implementation SokolAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // get pointer to our app delegate
    _sg_app_delegate = [UIApplication sharedApplication].delegate;
    
    // create the app's main window
    CGRect mainScreenBounds = [[UIScreen mainScreen] bounds];
    _sg_window = [[UIWindow alloc] initWithFrame:mainScreenBounds];

    #if SOKOL_METAL_IOS
    // view delegate, MTKView and metal device
    this->mtkViewDelegate = [[oryolViewDelegate alloc] init];
    _sg_mtl_device = MTLCreateSystemDefaultDevice();
    _sg_mtk_view = [[SokolMTKView alloc] init];
    [_sg_mtk_view setPreferredFramesPerSecond:60];
    [_sg_mtk_view setDelegate:_sg_mtk_view_delegate];
    [_sg_mtk_view setDevice:this->mtlDevice];
    [_sg_mtk_view setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
    [_sg_mtk_view setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
    [_sg_mtk_view setUserInteractionEnabled:YES];
    [_sg_mtk_view setMultipleTouchEnabled:YES];
    [_sg_window addSubview:_sg_mtk_view];

    // create view controller
    _sg_mtk_view_controller = [[UIViewController<MTKViewDelegate> alloc] init];
    [_sg_mtk_view_controller setView:_sg_mtk_view];
    [_sg_window setRootViewController:_sg_mtk_view_controller];

    // call the init function
    const sg_gfx_init_data ctx = {
        .mtl_device = CFBridgingRetain(_sg_mtl_device),
        .mtl_renderpass_descriptor_cb = sg_mtk_get_render_pass_descriptor,
        .mtl_drawable_cb = sg_mtk_get_drawable,
    };
    _sg_init_func(&ctx);

    #else
    // create GL context and GLKView
    // NOTE: the drawable properties will be overridden later in iosDisplayMgr!
    #ifdef SOKOL_GLES2
    _sg_eagl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    #else
    _sg_eagl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    #endif
    _sg_glk_view = [[SokolGLKView alloc] initWithFrame:mainScreenBounds];
    _sg_glk_view.drawableColorFormat   = GLKViewDrawableColorFormatRGBA8888;
    _sg_glk_view.drawableDepthFormat   = GLKViewDrawableDepthFormat24;
    _sg_glk_view.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
    _sg_glk_view.drawableMultisample   = GLKViewDrawableMultisampleNone;
    _sg_glk_view.context = this->eaglContext;
    _sg_glk_view.delegate = this->appDelegate;
    _sg_glk_view.enableSetNeedsDisplay = NO;
    _sg_glk_view.userInteractionEnabled = YES;
    _sg_glk_view.multipleTouchEnabled = YES;
    _sg_glk_view.contentScaleFactor = 1.0f;     // FIXME: this caused different behaviour than Metal path!!!
    [_sg_window addSubview:_sg_glk_view];

    // create a GLKViewController
    _sg_glk_view_controller = [[GLKViewController alloc] init];
    _sg_glk_view_controller.view = _sg_glk_view;
    _sg_glk_view_controller.preferredFramesPerSecond = 60;
    _sg_window.rootViewController = _sg_glk_view_controller;

    // call the init function
    const sg_gfx_init_data ctx = {
        #ifdef SOKOL_GLES2
        .gl_force_gles2 = true,
        #else
        .gl_force_gles2 = false,
        #endif
    };
    _sg_init_func(&ctx);

    #endif

    // make window visible
    _sg_window.backgroundColor = [UIColor blackColor];
    [_sg_window makeKeyAndVisible];
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
    if (_sg_shutdown_func) {
        @autoreleasepool {
            _sg_shutdown_func();
        }
    }
}

#ifndef SOKOL_METAL_IOS
- (void)_sg_glk_view:(GLKView*)view drawInRect:(CGRect)rect {
    if (_sg_frame_func) {
        @autoreleasepool {
            _sg_frame_func();
        }
    }
}
#endif
@end

sg_touch_event _sg_on_touches(sg_touch_event_type type, (NSSet*) touches, NSArray *tlist) {
    sg_touch_event newEvent;
    newEvent.type = type;
    newEvent.time = _sg_get_time();
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
            .x = pos.x * _sg_mouse_scale,
            .y = pos.y * _sg_mouse_scale,
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
    if (_sg_on_touch_begin) {
        _sg_on_touch_begin(&_sg_on_touches(sg_touch_event_begin, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
    if (_sg_on_touch_move) {
        _sg_on_touch_move(&_sg_on_touches(sg_touch_event_move, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    if (_sg_on_touch_end) {
        _sg_on_touch_end(&_sg_on_touches(sg_touch_event_end, [[event allTouches] allObjects], touches));
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_sg_on_touch_cancel) {
        _sg_on_touch_cancel(&_sg_on_touches(sg_touch_event_cancel, [[event allTouches] allObjects], touches));
    }
}
@end

#if SOKOL_METAL_IOS

@implementation SokolViewDelegate
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // FIXME(?)
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (_sg_frame_func) {
        @autoreleasepool {
            _sg_frame_func();
        }
    }
}
@end
#endif

//------------------------------------------------------------------------------
void sg_start(int w, int h, int smp_count, const char* title, sg_init_func ifun, sg_frame_func ffun, sg_shutdown_func sfun) {
    _sg_sample_count = smp_count;
    _sg_window_title = title;
    _sg_init_func = ifun;
    _sg_frame_func = ffun;
    _sg_shutdown_func = sfun;
    [SokolApp sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id delg = [[SokolAppDelegate alloc] init];
    [NSApp setDelegate:delg];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];
}


/* touch */
void sg_on_touch_begin(touch_event_func fn) {
    _sg_on_touch_begin = fn;
}
void sg_on_touch_move(touch_event_func fn) {
    _sg_on_touch_move = fn;
}
void sg_on_touch_cancel(touch_event_func fn) {
    _sg_on_touch_cancel = fn;
}
void sg_on_touch_end(touch_event_func fn) {
    _sg_on_touch_end = fn;
}

/* misc */
float _sg_get_time() {
    return (float) CACurrentMediaTime();
}

int main(int argc, char * argv[]) {
    //_sg_is_window_fullscreen = false;
    sg_main();
    if ()
    return 0;
}