;; @file main.nu
;; @discussion Entry point for a Nu program.
;;
;; @copyright Copyright (c) 2008 Jeff Buck

;; The shell of this program was mostly lifted from 
;; Tim Burks' Benwanu example.

(load "nu")
(load "cocoa")
(load "menu")
(load "console")

(load "nuopenglcube")

(set SHOW_CONSOLE_AT_STARTUP t)


(class ApplicationDelegate is NSObject
     
     (- (void) applicationDidFinishLaunching: (id) sender is
        (build-menu nuopengl-application-menu "Nu OpenGL Cube Demo")
        (set $controllers (NSMutableArray array))
        (self newView:self)
        (set $console ((NuConsoleWindowController alloc) init))
        (if SHOW_CONSOLE_AT_STARTUP ($console toggleConsole:self)))
     
     ;; Handles the "New" menu item and the initial view creation
     (- (void) newView:(id) sender is
        ($controllers << ((NuOpenGLWindowController alloc) init)))
     
     ;; Close the application when the window is closed
     (- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (id) app is
        YES)
     
     ;; Menu handlers. Forward on to the view
     (- (void) resetCamera:(id) sender is
        ($view resetCameraAndUpdateProjection))
     
     (- (void) startAnimation:(id) sender is
        ($view startAnimation))
     
     (- (void) stopAnimation:(id) sender is
        ($view stopAnimation)))

(set nuopengl-application-menu
     '(menu "Main"
            (menu "Application"
                  ("About #{appname}" action:"orderFrontStandardAboutPanel:")
                  (separator)
                  (menu "Services")
                  (separator)
                  ("Hide #{appname}" action:"hide:" key:"h")
                  ("Hide Others" action:"hideOtherApplications:" key:"h" modifier:(+ NSAlternateKeyMask NSCommandKeyMask))
                  ("Show All" action:"unhideAllApplications:")
                  (separator)
                  ("Quit #{appname}" action:"terminate:" key:"q"))
            (menu "Control"
                  ("Reset Camera" action:"resetCamera:" target:$delegate key:"r")
                  (separator)
                  ("Start Animation" action:"startAnimation:" target:$delegate key:"s")
                  ("Stop Animation" action:"stopAnimation:" target:$delegate key:"d"))
            (menu "Window"
                  ("Minimize" action:"performMiniaturize:" key:"m")
                  (separator)
                  ("Bring All to Front" action:"arrangeInFront:"))
            (menu "Help"
                  ("#{appname} Help" action:"showHelp:" key:"?"))))


;; install the delegate and keep a reference to it since the application won't retain it.
((NSApplication sharedApplication) setDelegate:(set $delegate ((ApplicationDelegate alloc) init)))

((NSApplication sharedApplication) activateIgnoringOtherApps:YES)
(NSApplicationMain 0 nil)
