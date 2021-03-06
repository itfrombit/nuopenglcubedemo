;; @file nuopenglcube.nu
;; @discussion A simple OpenGL example in Nu.
;;
;; Adapted from Apple's Cocoa OpenGL demo.
;; http://developer.apple.com/samplecode/CocoaGL/index.html
;;
;; @copyright Copyright (c) 2008 Jeff Buck

(import Cocoa)
(import OpenGL)
(import NSOpenGL)
(import NSOpenGLView)

(set kTol 0.001)
(set kRad2Deg (/ 180.0 3.1415927))
(set kDeg2Rad (/ 3.1415927 180.0))


;; Cube data
(set cubeNumVertices 8)

(set cubeVertices '(
                    (1.0 1.0 1.0)
                    (1.0 -1.0 1.0)
                    (-1.0 -1.0 1.0)
                    (-1.0 1.0 1.0)
                    (1.0 1.0 -1.0)
                    (1.0 -1.0 -1.0)
                    (-1.0 -1.0 -1.0)
                    (-1.0 1.0 -1.0)))

(set cubeVertexColors '(
                        (1.0 1.0 1.0)
                        (1.0 1.0 0.0)
                        (0.0 1.0 0.0)
                        (0.0 1.0 1.0)
                        (1.0 0.0 1.0)
                        (1.0 0.0 0.0)
                        (0.0 0.0 0.0)
                        (0.0 0.0 1.0)))

(set cubeNumFaces 6)

(set cubeFaces '(
                 (3 2 1 0)
                 (2 3 7 6)
                 (0 1 5 4)
                 (3 0 4 7)
                 (1 2 6 5)
                 (4 5 6 7)))



;; Bridged math functions.  Some of these are in NuMath, but some are missing...
(set cos (NuBridgedFunction functionWithName:"cos" signature:"dd"))
(set sin (NuBridgedFunction functionWithName:"sin" signature:"dd"))
(set tan (NuBridgedFunction functionWithName:"tan" signature:"dd"))

(set acos (NuBridgedFunction functionWithName:"acos" signature:"dd"))
(set asin (NuBridgedFunction functionWithName:"asin" signature:"dd"))
(set atan (NuBridgedFunction functionWithName:"atan" signature:"dd"))
(set atan2 (NuBridgedFunction functionWithName:"atan2" signature:"ddd"))

(set fabs (NuBridgedFunction functionWithName:"fabs" signature:"dd"))
(set sqrt (NuBridgedFunction functionWithName:"sqrt" signature:"dd"))


;; One function that needed to be written in objective-c
;; It passes an array of enumerated values into NSOpenGLPixelFormat's initializer
(set defaultPixelFormat (NuBridgedFunction functionWithName:"defaultPixelFormat" signature:"@"))


;; A few simple helper classes

;; Utility class for storing rotation matrices, quaternions,
;; and 3D coordinates
(class SpaceVector is NSObject
     (ivars)
     (ivar-accessors)
     
     (- (void) zero is
        (@data removeAllObjects)
        (@data << 0.0)
        (@data << 0.0)
        (@data << 0.0)
        (@data << 0.0))
     
     (- (id) init is
        (super init)
        (set @data ((NSMutableArray alloc) init))
        (self zero)
        self)
     
     (- (double) valueAtIndex:(int) i is
        (@data objectAtIndex:i))
     
     (- (void) setValue:(double) value atIndex:(int) i is
        (@data replaceObjectAtIndex:i withObject:value))
     
     (- (void) setDelta:(double) delta atIndex:(int) i is
        (self setValue:(+ (self valueAtIndex:i) delta) atIndex:i))
     
     ;; Make aliases for 3d coordinate usage
     (- (double) x is
        (self valueAtIndex:0))
     
     (- (double) y is
        (self valueAtIndex:1))
     
     (- (double) z is
        (self valueAtIndex:2))
     
     (- (void) setX:(double)value is
        (self setValue:value atIndex:0))
     
     (- (void) setY:(double)value is
        (self setValue:value atIndex:1))
     
     (- (void) setZ:(double)value is
        (self setValue:value atIndex:2)))


;; For keeping track of our camera
(class Camera is NSObject
     (ivars)
     (ivar-accessors)
     
     (- (id) init is
        (super init)
        (puts "Camera:init #{self}")
        
        (set @aperture 0.0)
        
        (set @viewWidth 0)
        (set @viewHeight 0)
        
        (set @viewPos  ((SpaceVector alloc) init))
        (set @viewDir  ((SpaceVector alloc) init))
        (set @viewUp   ((SpaceVector alloc) init))
        (set @rotPoint ((SpaceVector alloc) init))
        self))


;; The main view
(class NuOpenGLView is NSOpenGLView
     (ivars)
     (ivar-accessors)
     
     (- (void) initializeAnimationParameters is
        (set @rRot   ((SpaceVector alloc) init))
        (set @rVel 	 ((SpaceVector alloc) init))
        (set @rAccel ((SpaceVector alloc) init))
        
        (set @camera ((Camera alloc) init))
        
        (set @worldRotation ((SpaceVector alloc) init))
        (set @objectRotation ((SpaceVector alloc) init))
        
        (set @theOrigin ((SpaceVector alloc) init))
        (set @trackballRotation ((SpaceVector alloc) init))
        
        (set @shapeSize 7.0)
        
        ;; set start values...
        (@rVel setValue:0.3 atIndex:0)
        (@rVel setValue:0.1 atIndex:1)
        (@rVel setValue:0.2 atIndex:2)
        (set $rVel @rVel)
        
        (@rAccel setValue:0.003 atIndex:0)
        (@rAccel setValue:-0.005 atIndex:1)
        (@rAccel setValue:0.004 atIndex:2)
        (set $rAccel @rAccel)
        
        (set @timer nil)
        (set @isAnimate 0)
        (set @lastTime (CFAbsoluteTimeGetCurrent))
        
        (set @dollyPanStartPoint ((SpaceVector alloc) init))
        
        (set @isDolly NO)
        (set @isPan NO)
        (set @isTrackball NO)
        
        (set @gRadiusTrackball 0.0)
        (set @gXCenterTrackball 0)
        (set @gYCenterTrackball 0)
        
        (set @gStartPtTrackball ((SpaceVector alloc) init))
        (set @gEndPtTrackball ((SpaceVector alloc) init))

		;; Temporary working variables for trackball functions
		;; to avoid local alloc-init each frame
		(set @rotation ((SpaceVector alloc) init))
		(set @q0 ((SpaceVector alloc) init))
		(set @q1 ((SpaceVector alloc) init))
		(set @q2 ((SpaceVector alloc) init)))
     
     
     (- (id) initWithFrame: (NSRect) frameRect is
        (set pf (defaultPixelFormat))
        (super initWithFrame:frameRect pixelFormat:pf)
        
        (self initializeAnimationParameters)
        
        (set $view self)
        self)
     
     
     (- (void) resetCamera is
        
        (@camera setAperture:40.0)
        
        ((@camera rotPoint) setX:(@theOrigin x))
        ((@camera rotPoint) setY:(@theOrigin y))
        ((@camera rotPoint) setZ:(@theOrigin z))
        
        ((@camera viewPos) setX:0.0)
        ((@camera viewPos) setY:0.0)
        ((@camera viewPos) setZ:-10.0)
        
        ((@camera viewDir) setX:(- 0.0 ((@camera viewPos) x)))
        ((@camera viewDir) setY:(- 0.0 ((@camera viewPos) y)))
        ((@camera viewDir) setZ:(- 0.0 ((@camera viewPos) z)))
        
        ((@camera viewUp) setX:0)
        ((@camera viewUp) setY:1)
        ((@camera viewUp) setZ:0))
     
     
     ;; Called by the framework to set up drawing context
     (- (void) prepareOpenGL is
        (set swapInterval (list 1))
        ((self openGLContext) setValues:swapInterval forParameter:NSOpenGLCPSwapInterval)
        
        (glEnable GL_DEPTH_TEST)
        (glShadeModel GL_SMOOTH)
        (glEnable GL_CULL_FACE)
        (glFrontFace GL_CCW)
        (glPolygonOffset 1.0 1.0)
        
        (glClearColor 0.0 0.0 0.0 0.0)
        
        (self resetCamera)
        
        ;; max radius of of objects
        (set @setShapeSize 7.0))
     
     
     (- (void) drawCube: (float) fSize is
        ;; Draw the faces
        (glColor3f 1.0 0.5 0.0)
        (glBegin GL_QUADS)
        
        (for ((set f 0) (< f cubeNumFaces) (set f (+ f 1)))
             (for ((set i 0) (< i 4) (set i (+ i 1)))
                  (glColor3f
                            ((cubeVertexColors ((cubeFaces f) i)) 0)
                            ((cubeVertexColors ((cubeFaces f) i)) 1)
                            ((cubeVertexColors ((cubeFaces f) i)) 2))
                  
                  (glVertex3f
                             (* ((cubeVertices ((cubeFaces f) i)) 0) fSize)
                             (* ((cubeVertices ((cubeFaces f) i)) 1) fSize)
                             (* ((cubeVertices ((cubeFaces f) i)) 2) fSize))))
        (glEnd)
        
        ;; Draw the edges
        (glColor3f 0.0 0.0 0.0)
        
        (for ((set f 0) (< f cubeNumFaces) (set f (+ f 1)))
             (glBegin GL_LINE_LOOP)
             
             (for ((set i 0) (< i 4) (set i (+ i 1)))
                  (glVertex3f
                             (* ((cubeVertices ((cubeFaces f) i)) 0) fSize)
                             (* ((cubeVertices ((cubeFaces f) i)) 1) fSize)
                             (* ((cubeVertices ((cubeFaces f) i)) 2) fSize)))
             (glEnd)))
     
     
     ;; Draw a simple cube
     (- (void) drawRect: (NSRect) rect is
        (self resizeGL)
        (self updateModelView)
        
        (glClear (| GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))
        (self drawCube:1.5)
        
        ((self openGLContext) flushBuffer))
     
     
     ;; Update the Projection Frustum
     (- (void) updateProjection is
        ((self openGLContext) makeCurrentContext)
        
        (glMatrixMode GL_PROJECTION)
        (glLoadIdentity)
        
        (set near (- (* -1.0 ((@camera viewPos) z)) (* @shapeSize 0.5)))
        (if (< near 0.00001)
            (then (set near 0.00001)))
        
        (set far (+ (* -1.0 ((@camera viewPos) z)) (* @shapeSize 0.5)))
        (if (< far 1.0)
            (then (set far 1.0)))
        
        ;; Use half aperture degrees in radians
        (set radians (/ (* 0.0174532925 (@camera aperture)) 2))
        (set wd2 (* near (tan radians)))
        (set ratio (/ (@camera viewWidth) (* 1.0 (@camera viewHeight))))
        
        (if (>= ratio 1.0)
            (then
                 (set left  (* -1.0 ratio wd2))
                 (set right (* ratio  wd2))
                 (set top wd2)
                 (set bottom (* -1.0 wd2)))
            (else
                 (set left (* -1.0 wd2))
                 (set right wd2)
                 (set top (/ wd2 ratio))
                 (set bottom (/ (* -1.0 wd2) ratio))))
        
        ;(puts "glFrustum: #{left} #{right} #{bottom} #{top} #{near} #{far}")
        (glFrustum left right bottom top near far))
     
     
     ;; Update rotation based on velocity and acceleration
     (- (void) updateObjectRotationForTimeDelta: (double) deltaTime is

        (set vMax 2.0)
        
        ;; Do velocities
        (for ((set i 0) (< i 3) (set i (+ i 1)))
             (@rVel setDelta:(* (@rAccel valueAtIndex:i) deltaTime 30.0) atIndex:i)
             
             (if (> (@rVel valueAtIndex:i) vMax)
                 (then
                      (@rAccel setValue:(* -1.0 (@rAccel valueAtIndex:i)) atIndex:i)
                      (@rVel setValue:vMax atIndex:i))
                 (else
                      (if (< (@rVel valueAtIndex:i) (- 0.0 vMax))
                          (then
                               (@rAccel setValue:(* -1.0 (@rAccel valueAtIndex:i)) atIndex:i)
                               (@rVel setValue:(- 0.0 vMax) atIndex:i)))))
             
             (@rRot setDelta:(* (@rVel valueAtIndex:i) deltaTime 30.0) atIndex:i)
             
             ;; Get our values in the normal range
             (while (> (@rRot valueAtIndex:i) 360.0)
                    (@rRot setDelta:-360.0 atIndex:i))
             
             (while (< (@rRot valueAtIndex:i) -360.0)
                    (@rRot setDelta:360.0 atIndex:i)))
        
        (@rotation setValue:(@rRot valueAtIndex:0) atIndex:0)
        (@rotation setValue:1.0 atIndex:1)
        (self addToRotationTrackball:@rotation a:@objectRotation)
        
        (@rotation setValue:(@rRot valueAtIndex:1) atIndex:0)
        (@rotation setValue:0.0 atIndex:1)
        (@rotation setValue:1.0 atIndex:2)
        (self addToRotationTrackball:@rotation a:@objectRotation)
        
        (@rotation setValue:(@rRot valueAtIndex:2) atIndex:0)
        (@rotation setValue:0.0 atIndex:2)
        (@rotation setValue:1.0 atIndex:3)
        (self addToRotationTrackball:@rotation a:@objectRotation))
     
     
     ;; Move the objects and apply panning and rotations
     (- (void) updateModelView is
        ((self openGLContext) makeCurrentContext)
        
        (glMatrixMode GL_MODELVIEW)
        (glLoadIdentity);
        (gluLookAt 	((@camera viewPos) x)
             ((@camera viewPos) y)
             ((@camera viewPos) z)
             (+ ((@camera viewPos) x) ((@camera viewDir) x))
             (+ ((@camera viewPos) y) ((@camera viewDir) y))
             (+ ((@camera viewPos) z) ((@camera viewDir) z))
             ((@camera viewUp) x)
             ((@camera viewUp) y)
             ((@camera viewUp) z))
        
        ;; Do we have trackball rotation to map?
        (if (!= (@trackballRotation valueAtIndex:0) 0.0)
            (then
                 (glRotatef (@trackballRotation valueAtIndex:0)
                      (@trackballRotation valueAtIndex:1)
                      (@trackballRotation valueAtIndex:2)
                      (@trackballRotation valueAtIndex:3))))
        
        ;; Set accumulated world rotation via trackball
        (glRotatef 	(@worldRotation valueAtIndex:0)
             (@worldRotation valueAtIndex:1)
             (@worldRotation valueAtIndex:2)
             (@worldRotation valueAtIndex:3))
        
        ;; Rotate the cube itself after camera rotation
        (glRotatef 	(@objectRotation valueAtIndex:0)
             (@objectRotation valueAtIndex:1)
             (@objectRotation valueAtIndex:2)
             (@objectRotation valueAtIndex:3))
        
        ;; reset animation rotations
        ;; (do in all cases to prevent rotating while moving with trackball)
        (@rRot setValue:0.0 atIndex:0)
        (@rRot setValue:0.0 atIndex:1)
        (@rRot setValue:0.0 atIndex:2))
     
     
     ;; Rescale the viewport
     (- (void) resizeGL is
        (set rectView (self bounds))
        
        (if (or (!= (@camera viewHeight) (fourth rectView))
                (!= (@camera viewWidth) (third rectView)))
            (then
                 (@camera setViewHeight:(fourth rectView))
                 (@camera setViewWidth:(third rectView))
                 
                 (glViewport 0 0 (@camera viewWidth) (@camera viewHeight))
                 (self updateProjection))))
     
     ;; ---------------------------------------------------------------
     ;; Mouse events
     
     ;; Changes zoom factor on the z axis
     (- (void) scrollWheel: (id) event is
        (set wheelDelta (+ (event deltaX) (event deltaY) (event deltaZ)))
        
        (if (!= wheelDelta 0.0)
            (then
                 (set deltaAperture (/ (* wheelDelta (* -1.0 (@camera aperture))) 200.0))
                 (@camera setAperture:(+ (@camera aperture) deltaAperture))
                 
                 ;; Do not let aperture <= 0.1 or >= 180.0
                 (if (< (@camera aperture) 0.1)
                     (then (@camera setAperture:0.1)))
                 
                 (if (> (@camera aperture) 179.9)
                     (then (@camera setAperture:179.9)))
                 
                 (self updateProjection)
                 (self setNeedsDisplay:YES))))
     
     
     ;; Move the camera
     (- (void) mouseDolly: (NSPoint) location is
        (set dolly (* (- (@dollyPanStartPoint y) (second location)) (/ ((@camera viewPos) z) -300.0)))
        
        ((@camera viewPos) setZ:(+ ((@camera viewPos) z) dolly))
        
        ;; Prevent z from reaching 0.0
        (if (eq ((@camera viewPos) z) 0.0)
            (then ((@camera viewPos) setZ:0.0001)))
        
        (@dollyPanStartPoint setX:(first location))
        (@dollyPanStartPoint setY:(second location)))
     
     
     ;; Move camera in x/y plane
     (- (void) mousePan: (NSPoint) location is
        (set panX (/ (- (@dollyPanStartPoint x) (first location)) (/ -900.0  ((@camera viewPos) z))))
        (set panY (/ (- (@dollyPanStartPoint y) (second location)) (/ -900.0  ((@camera viewPos) z))))
        
        ((@camera viewPos) setX:(- ((@camera viewPos) x) panX))
        ((@camera viewPos) setY:(- ((@camera viewPos) y) panY))
        
        (@dollyPanStartPoint setX:(first location))
        (@dollyPanStartPoint setY:(second location)))
     
     
     ;; Handle primary mouse button
     ;; Also look for modifiers and route to their handlers
     ;;   Plain Mousedown: Rotate model
     ;;   Ctrl-Mousedown:  Pan camera
     ;;   Opt-Mousedown:   Move dolly
     (- (void) mouseDown:(id)event is
        (if (& (event modifierFlags) NSControlKeyMask)
            (then (self rightMouseDown:event))
            (else (if (& (event modifierFlags) NSAlternateKeyMask)
                      (then (self otherMouseDown:event))
                      (else
                           (set location (self convertPoint:(event locationInWindow) fromView:nil))
                           (set flipy (- (@camera viewHeight) (second location)))
                           (set @isDolly NO)
                           (set @isPan NO)
                           (set @isTrackball YES)
                           (self startTrackball:(first location) y:flipy originX:0 originY:0 width:(@camera viewWidth) height:(@camera viewHeight)))))))
     
     ;; Ctrl-Mouse/Right-Mouse is pan
     (- (void) rightMouseDown:(id)event is
        (set location (self convertPoint:(event locationInWindow) fromView:nil))
        (set flipy (- (@camera viewHeight) (second location)))
        
        (if (eq @isTrackball YES)
            (then
                 (if (!= (@trackballRotation valueAtIndex:0) 0.0)
                     (then
                          (self addToRotationTrackball:@trackballRotation a:@worldRotation)))
                 
                 (@trackballRotation zero)))
        
        (set @isDolly NO)
        (set @isPan YES)
        (set @isTrackball NO)
        
        ((@dollyPanStartPoint) setX:(first location))
        ((@dollyPanStartPoint) setY:flipy))
     
     
     ;; Opt-Mouse/Middle mouse is dolly move
     (- (void) otherMouseDown:(id)event is
        (set location (self convertPoint:(event locationInWindow) fromView:nil))
        (set flipy (- (@camera viewHeight) (second location)))
        
        (if (eq @isTrackball YES)
            (then
                 (if (!= (@trackballRotation valueAtIndex:0) 0.0)
                     (then
                          (self addToRotationTrackball:@trackballRotation a:@worldRotation)))
                 
                 (@trackballRotation zero)))
        
        (set @isDolly YES)
        (set @isPan NO)
        (set @isTrackball NO)
        
        ((@dollyPanStartPoint) setX:(first location))
        ((@dollyPanStartPoint) setY:flipy))
     
     
     ;; Handles all cases when mouse is dragged.
     ;; See what mode we're in (rotate/pan/dolly)
     (- (void) mouseDragged:(id)event is
        (set location (self convertPoint:(event locationInWindow) fromView:nil))
        (set flipy (- (@camera viewHeight) (second location)))
        
        (if (@isTrackball)
            (then
                 (self rollToTrackball:(first location) y:flipy rot:@trackballRotation)
                 (self setNeedsDisplay: YES))
            (else (if (@isDolly)
                      (then
                           (self mouseDolly: (list (first location) flipy))
                           (self updateProjection)
                           (self setNeedsDisplay: YES))
                      (else (if (@isPan)
                                (then
                                     (self mousePan: (list (first location) flipy))
                                     (self setNeedsDisplay: YES))))))))
     
     
     (- (void) rightMouseDragged: (id)event is
        (self mouseDragged: event))
     
     (- (void) otherMouseDragged: (id)event is
        (self mouseDragged: event))
     
     
     ;; Reset our drag modes and do final rotation
     (- (void) mouseUp: (id) event is
        (if (eq @isDolly YES)
            (then (set @isDolly NO))
            (else (if (eq @isPan YES)
                      (then (set @isPan NO))
                      (else (if (eq @isTrackball YES)
                                (then
                                     (set @isTrackball NO)
                                     (if (!= (@trackballRotation valueAtIndex:0) 0.0)
                                         (then
                                              (self addToRotationTrackball:@trackballRotation a:@worldRotation)))
                                     (@trackballRotation zero))))))))
     
     
     (- (void) rightMouseUp: (id) event is
        (self mouseUp:event))
     
     (- (void) otherMouseUp:(id)event is
        (self mouseUp:event))
     
     
     ;; View overrides
     (- (BOOL) acceptsFirstResponder is
        YES)
     
     (- (BOOL) becomeFirstResponder is
        YES)
     
     (- (BOOL) resignFirstResponder is
        YES)
     
     
     ;; Animation timer event
     ;; Figure out how long it was from our last rotation and
     ;; apply appropriate rotation amount
     (- (void)animationTimer: (id)timer is
        (set shouldDraw NO)
        
        (if (eq @isAnimate YES)
            (then
                 (set deltaTime (- (CFAbsoluteTimeGetCurrent) @lastTime))
                 
                 (if (<= deltaTime 10.0)
                     (then
                          (if (!= @isTrackball YES)
                              (then
                                   (self updateObjectRotationForTimeDelta: deltaTime)))
                          (set shouldDraw YES)))))
        
        (set @lastTime (CFAbsoluteTimeGetCurrent))
        
        (if (eq shouldDraw YES)
            (then
                 (self drawRect:(self bounds)))))
     
     
     (- (void) startAnimation is
        (if (eq @isAnimate NO)
            (then
                 ;; Reset timer so we start animation from current model position
                 ;; Otherwise we "jump" from some keyframe point in the past
                 (set @lastTime (CFAbsoluteTimeGetCurrent))
                 
                 (set @isAnimate YES)
                 (set @timer (NSTimer timerWithTimeInterval:(/ 1.0 60.0) target:self selector:"animationTimer:" userInfo:nil repeats:YES))
                 ((NSRunLoop currentRunLoop) addTimer:@timer forMode:NSDefaultRunLoopMode)
                 
                 ;; Put timer in EventTracking loop so we get animation even when resizing the window
                 ((NSRunLoop currentRunLoop) addTimer:@timer forMode:NSEventTrackingRunLoopMode))))
     
     
     (- (void) stopAnimation is
        (if (eq @isAnimate YES)
            (then
                 (set @isAnimate NO)
                 (@timer invalidate))))
     
     ;; From the Apple example code:
     ;; 	This can be a troublesome call to do anything heavyweight,
     ;; 	as it is called on window moves, resizes, and display config changes.
     ;; 	So be careful of doing too much here.
     (- (void) update is
        ;; How about doing a big pile of nothing.
        ;; Is that lightweight enough?
        (super update))
     
     (- (void) resetCameraAndUpdateProjection is
        (self resetCamera)
        (self updateProjection)
        (self setNeedsDisplay:YES))
     
     ;; Process keyboard shortcuts
     (- (void)keyDown: (id)event is
        (set key ((event characters) characterAtIndex:0))
        ;(puts "keyDown: #{key}")
        (case key
              ;; spacebar: toggle animation
              (32
                 (if (eq @isAnimate NO)
                     (then
                          (self startAnimation))
                     (else
                          (self stopAnimation))))
              
              ;; r: reset camera
              (114
                  (self resetCameraAndUpdateProjection))))
     
     
     ;; ----------------------------------------------------------
     ;; Trackball functions...
     ;; This sort of thing is probably best done in C/Objective-C
     ;; for two reasons:
     ;;   1. Readability: I think the heavy math equations are easier to read in infix.
     ;;                   That's just my opinion though.
     ;;   2. Speed: CPU load is much lower as C code
     ;;
     ;; However, that's not the point here.  Given the heavy amount of
     ;; calculation that's being done here, I think Nu holds it's own.
     
     ;; Start the trackball.
     (- (void) startTrackball:(int) x y:(int) y originX:(int) originX originY:(int) originY width:(int) width height:(int) height is
        
        ;; The following helpful comments are from the Apple example at
        ;; http://developer.apple.com/samplecode/CocoaGL/index.html
        ;; This code was ported over from the trackball.c file in that example.
        ;;
        ;; The trackball works by pretending that a ball
        ;; encloses the 3D view.  You roll this pretend ball with the mouse.  For
        ;; example, if you click on the center of the ball and move the mouse straight
        ;; to the right, you roll the ball around its Y-axis.  This produces a Y-axis
        ;; rotation.  You can click on the "edge" of the ball and roll it around
        ;; in a circle to get a Z-axis rotation.
        ;;
        ;; The math behind the trackball is simple: start with a vector from the first
        ;; mouse-click on the ball to the center of the 3D view.  At the same time, set the radius
        ;; of the ball to be the smaller dimension of the 3D view.  As you drag the mouse
        ;; around in the 3D view, a second vector is computed from the surface of the ball
        ;; to the center.  The axis of rotation is the cross product of these two vectors,
        ;; and the angle of rotation is the angle between the two vectors.
        (set nx width)
        (set ny height)
        
        (if (> nx ny)
            (then (set @gRadiusTrackball (* ny 0.5)))
            (else (set @gRadiusTrackball (* nx 0.5))))
        
        ;; Figure out the center of the view.
        (set @gXCenterTrackball (+ originX (* width 0.5)))
        (set @gYCenterTrackball (+ originY (* height 0.5)))
        
        ;; Compute the starting vector from the surface of the ball to its center.
        (@gStartPtTrackball setValue:(- x @gXCenterTrackball) atIndex:0)
        (@gStartPtTrackball setValue:(- y @gYCenterTrackball) atIndex:1)
        
        (set xxyy (+ (* (@gStartPtTrackball valueAtIndex:0) (@gStartPtTrackball valueAtIndex:0))
                     (* (@gStartPtTrackball valueAtIndex:1) (@gStartPtTrackball valueAtIndex:1))))
        
        (if (> xxyy (* @gRadiusTrackball @gRadiusTrackball))
            (then
                 ;; Outside the sphere
                 (@gStartPtTrackball setValue:0.0 atIndex:2))
            (else
                 (@gStartPtTrackball setValue:(sqrt (- (* @gRadiusTrackball @gRadiusTrackball) xxyy)) atIndex:2))))
     
     
     ;; update to new mouse position, output rotation angle
     (- (void) rollToTrackball:(int) x y:(int) y rot:(id) rot is
        (@gEndPtTrackball setValue:(- x @gXCenterTrackball) atIndex:0)
        (@gEndPtTrackball setValue:(- y @gYCenterTrackball) atIndex:1)
        
        (if (and (< (fabs (- (@gEndPtTrackball valueAtIndex:0) (@gStartPtTrackball valueAtIndex:0))) kTol)
                 (< (fabs (- (@gEndPtTrackball valueAtIndex:1) (@gStartPtTrackball valueAtIndex:1))) kTol))
            (then
                 ;; Not enough change to bother with...do nothing...
                 (puts "...Doing nothing...yawn"))
            (else
                 ;; Compute the ending vector from the surface of the ball to its center.
                 (set xxyy (+ (* (@gEndPtTrackball valueAtIndex:0) (@gEndPtTrackball valueAtIndex:0))
                              (* (@gEndPtTrackball valueAtIndex:1) (@gEndPtTrackball valueAtIndex:1))))
                 
                 (if (> xxyy (* @gRadiusTrackball @gRadiusTrackball))
                     (then
                          ;; Outside the sphere.
                          (@gEndPtTrackball setValue:0.0 atIndex:2))
                     (else
                          (@gEndPtTrackball setValue:(sqrt (- (* @gRadiusTrackball @gRadiusTrackball) xxyy)) atIndex:2)))
                 
                 ;; Take the cross product of the two vectors. r = s X e
                 (rot setValue:(- (* (@gStartPtTrackball valueAtIndex:1) (@gEndPtTrackball valueAtIndex:2))
                                  (* (@gStartPtTrackball valueAtIndex:2) (@gEndPtTrackball valueAtIndex:1)))
                      atIndex:1)
                 
                 (rot setValue:(+ (* (- 0.0 (@gStartPtTrackball valueAtIndex:0)) (@gEndPtTrackball valueAtIndex:2))
                                  (* (@gStartPtTrackball valueAtIndex:2) (@gEndPtTrackball valueAtIndex:0)))
                      atIndex:2)
                 
                 (rot setValue:(- (* (@gStartPtTrackball valueAtIndex:0) (@gEndPtTrackball valueAtIndex:1))
                                  (* (@gStartPtTrackball valueAtIndex:1) (@gEndPtTrackball valueAtIndex:0)))
                      atIndex:3)
                 
                 ;; Use atan for a better angle.  If you use only cos or sin, you only get
                 ;; half the possible angles, and you can end up with rotations that flip around near
                 ;; the poles.
                 
                 ;; cos(a) = (s . e) / (||s|| ||e||)
                 
                 ;; (s . e)
                 (set cosAng (+ (* (@gStartPtTrackball valueAtIndex:0) (@gEndPtTrackball valueAtIndex:0))
                                (* (@gStartPtTrackball valueAtIndex:1) (@gEndPtTrackball valueAtIndex:1))
                                (* (@gStartPtTrackball valueAtIndex:2) (@gEndPtTrackball valueAtIndex:2))))
                 
                 (set ls (sqrt (+ (* (@gStartPtTrackball valueAtIndex:0) (@gStartPtTrackball valueAtIndex:0))
                                  (* (@gStartPtTrackball valueAtIndex:1) (@gStartPtTrackball valueAtIndex:1))
                                  (* (@gStartPtTrackball valueAtIndex:2) (@gStartPtTrackball valueAtIndex:2)))))
                 
                 (set ls (/ 1.0 ls))
                 
                 (set le (sqrt (+ (* (@gEndPtTrackball valueAtIndex:0) (@gEndPtTrackball valueAtIndex:0))
                                  (* (@gEndPtTrackball valueAtIndex:1) (@gEndPtTrackball valueAtIndex:1))
                                  (* (@gEndPtTrackball valueAtIndex:2) (@gEndPtTrackball valueAtIndex:2)))))
                 
                 (set le (/ 1.0 le))
                 
                 (set cosAng (* cosAng ls le))
                 
                 ;; sin(a) = ||(s X e)|| / (||s|| ||e||)
                 
                 ;; ||(s X e)||
                 (set sinAng (sqrt (+ (* (rot valueAtIndex:1) (rot valueAtIndex:1))
                                      (* (rot valueAtIndex:2) (rot valueAtIndex:2))
                                      (* (rot valueAtIndex:3) (rot valueAtIndex:3)))))
                 
                 (set lr sinAng)
                 (set sinAng (* sinAng ls le))
                 
                 ;; GL rotations are in degrees.
                 (rot setValue:(* (atan2 sinAng cosAng) kRad2Deg) atIndex:0)
                 
                 ;; Normalize the rotation axis.
                 (set lr (/ 1.0 lr))
                 
                 (rot setValue:(* (rot valueAtIndex:1) lr) atIndex:1)
                 (rot setValue:(* (rot valueAtIndex:2) lr) atIndex:2)
                 (rot setValue:(* (rot valueAtIndex:3) lr) atIndex:3))))
     
     
     
     (- (void) rotation2Quat:(id)A q:(id)q is
        ;; Convert a GL-style rotation to a quaternion.
        ;; The GL rotation looks like this:
        ;;	 {angle, x, y, z}
        ;; The corresponding quaternion looks like this:
        ;;   {{v}, cos(angle/2)}, where {v} is {x, y, z} / sin(angle/2).
        
        ;; Convert from degrees ot radians, get the half-angle.
        (set ang2 (* (A valueAtIndex:0) kDeg2Rad 0.5))
        (set sinAng2 (sin ang2))
        
        (q setValue:(* (A valueAtIndex:1) sinAng2) atIndex:0)
        (q setValue:(* (A valueAtIndex:2) sinAng2) atIndex:1)
        (q setValue:(* (A valueAtIndex:3) sinAng2) atIndex:2)
        (q setValue:(cos ang2) atIndex:3))
     
     
     (- (void) addToRotationTrackball:(id)dA a:(id)A is
        ;; Figure out A' = A . dA
        ;; In quaternions: let q0 <- A, and q1 <- dA.
        ;; Figure out q2 = q1 + q0 (note the order reversal!).
        ;; A' <- q3.
        
        (self rotation2Quat:A q:@q0)
        (self rotation2Quat:dA q:@q1)
        
        ;; q2 = q1 + q0;
        ;; Better have a 30" Cinema Display to see all of this line at once.
        (@q2 setValue:(+ (+ (- (* (@q1 valueAtIndex:1) (@q0 valueAtIndex:2)) (* (@q1 valueAtIndex:2) (@q0 valueAtIndex:1))) (* (@q1 valueAtIndex:3) (@q0 valueAtIndex:0))) (* (@q1 valueAtIndex:0) (@q0 valueAtIndex:3))) atIndex:0)
        (@q2 setValue:(+ (+ (- (* (@q1 valueAtIndex:2) (@q0 valueAtIndex:0)) (* (@q1 valueAtIndex:0) (@q0 valueAtIndex:2))) (* (@q1 valueAtIndex:3) (@q0 valueAtIndex:1))) (* (@q1 valueAtIndex:1) (@q0 valueAtIndex:3))) atIndex:1)
        (@q2 setValue:(+ (+ (- (* (@q1 valueAtIndex:0) (@q0 valueAtIndex:1)) (* (@q1 valueAtIndex:1) (@q0 valueAtIndex:0))) (* (@q1 valueAtIndex:3) (@q0 valueAtIndex:2))) (* (@q1 valueAtIndex:2) (@q0 valueAtIndex:3))) atIndex:2)
        (@q2 setValue:(- (- (- (* (@q1 valueAtIndex:3) (@q0 valueAtIndex:3)) (* (@q1 valueAtIndex:0) (@q0 valueAtIndex:0))) (* (@q1 valueAtIndex:1) (@q0 valueAtIndex:1))) (* (@q1 valueAtIndex:2) (@q0 valueAtIndex:2))) atIndex:3)
        
        ;; An identity rotation is expressed as rotation by 0 about any axis.
        ;; The "angle" term in a quaternion is really the cosine of the half-angle.
        ;; So, if the cosine of the half-angle is one (or, 1.0 within our tolerance),
        ;; then you have an identity rotation.
        (if (< (fabs (fabs (- (@q2 valueAtIndex:3) 1.0))) 1.0e-7)
            (then
                 ;; Identity rotation.
                 (A setValue:0.0 atIndex:0)
                 (A setValue:1.0 atIndex:1)
                 (A setValue:0.0 atIndex:2)
                 (A setValue:0.0 atIndex:3))
            (else
                 ;; If you get here, then you have a non-identity rotation.
                 ;; In non-identity rotations, the cosine of the half-angle is non-0,
                 ;; which means the sine of the angle is also non-0.
                 ;; So we can safely divide by sin(theta2).
                 
                 ;; Turn the quaternion back into an {angle, {axis}} rotation.
                 (set theta2 (acos (@q2 valueAtIndex:3)))
                 (set sinTheta2 (/ 1.0 (sin theta2)))
                 (A setValue:(* theta2 2.0 kRad2Deg) atIndex:0)
                 (A setValue:(* (@q2 valueAtIndex:0) sinTheta2) atIndex:1)
                 (A setValue:(* (@q2 valueAtIndex:1) sinTheta2) atIndex:2)
                 (A setValue:(* (@q2 valueAtIndex:2) sinTheta2) atIndex:3)))))


;; @class NuOpenGLWindowController
;; @discussion The Window Controller for the Nu OpenGL Cube Demo application.
;;
;; Mostly lifted from Tim Burks' Benwanu example.

(class NuOpenGLWindowController is NSWindowController
     (ivars)
     (ivar-accessors)
     
     (imethod (id) init is
          (set mainFrame (list 0 0 800 600))
          (set styleMask (+ NSTitledWindowMask
                            NSClosableWindowMask
                            NSMiniaturizableWindowMask
                            NSResizableWindowMask))

          (self initWithWindow:((NSWindow alloc)
                                initWithContentRect:mainFrame
                                styleMask:styleMask
                                backing:NSBackingStoreBuffered
                                defer:NO))
          
          (let (w (self window))
               (w center)
               (w set: (title:"Nu OpenGL Cube Demo"
                        delegate:self
                        opaque:NO
                        hidesOnDeactivate:NO
                        frameOrigin: (NSValue valueWithPoint: '(100 200))
                        minSize:     (NSValue valueWithSize:  '(600 400))
                        contentView: ((NSView alloc) initWithFrame:mainFrame)))

               (set @view ((NuOpenGLView alloc) initWithFrame:'(0 0 800 600)))
               ((w contentView) addSubview:@view)
               (@view setAutoresizingMask:(+ NSViewWidthSizable NSViewHeightSizable))
               
               (w makeKeyAndOrderFront:self))
          self))
