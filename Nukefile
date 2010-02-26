;; Nukefile for Nu OpenGL Cube Demo

;; source files
(set @c_files     (filelist "^objc/.*.c$"))
(set @m_files     (filelist "^objc/.*.m$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))
(set @frameworks  '("Cocoa" "OpenGL" "Nu"))

;; application description
(set @application "NuOpenGLCubeDemo")
(set @application_identifier   "nu.programming.nuopenglcubedemo")

;; build configuration
(set @cc "gcc")
(set @cflags "-g -O3 -DMACOSX ")
(set @mflags "-fobjc-gc -fobjc-exceptions")

(set @ldflags
     ((list
           ((@frameworks map: (do (framework) " -framework #{framework}")) join)
           ((@libs map: (do (lib) " -l#{lib}")) join)
           ((@lib_dirs map: (do (libdir) " -L#{libdir}")) join))
      join))

(compilation-tasks)
(application-tasks)

(task "default" => "application")

