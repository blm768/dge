/++
Global configuration for DGE
+/
module dge.config;

import std.conv;

import derelict.opengl3.gl3;

enum {
	//Determines whether to use precompiled Derelict libraries instead of recompiling each time
	bool useDerelictLibs = false,

	uint glMajorVersion = 3,
	uint glMinorVersion = 2,

	bool useBufferAlpha = false,
	size_t depthBufferSize = 24,
	size_t stencilBufferSize = 8,
}

template DerelictGLVersion(uint major, uint minor) {
	enum DerelictGLVersion = mixin("GLVersion.GL" ~ to!string(major) ~ to!string(minor));
}

/++
The minimum required OpenGL version that Derelict must load for the program to initialize properly

Automatically set from glMajorVersion and glMinorVersion
+/
enum GLVersion glRequiredVersion = DerelictGLVersion!(glMajorVersion, glMinorVersion);
