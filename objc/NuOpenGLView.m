#import <Cocoa/Cocoa.h>

NSOpenGLPixelFormat* defaultPixelFormat()
{
    NSOpenGLPixelFormatAttribute attributes [] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFADoubleBuffer,	// double buffered
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)16, // 16 bit depth buffer
        (NSOpenGLPixelFormatAttribute)0
    };

    return [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
}
