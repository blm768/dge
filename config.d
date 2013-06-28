/++
Global configuration for DGE
+/
module dge.config;

import std.conv;

import derelict.opengl3.gl3;

import dge.graphics.material;

enum {
	//Determines whether to use precompiled Derelict libraries instead of recompiling each time; affects pragma(lib) directives
	//To do: remove?
	bool useDerelictLibs = false,

	uint glMajorVersion = 3,
	uint glMinorVersion = 2,

	bool useBufferAlpha = false,
	size_t depthBufferSize = 24,
	size_t stencilBufferSize = 8,

	GLuint stencilMaskAll = (1 << stencilBufferSize) - 1,
	//The value that must be in the stencil buffer for the stencil test to pass
	GLuint stencilAccept = 1,

	size_t maxLightsPerObject = 8,
	size_t maxMirrorReflections = 1,
}

/++
The default parameters for new material shaders

May be modified by the user
+/
MaterialShaderConfig defaultMaterialConfig;

template DerelictGLVersion(uint major, uint minor) {
	enum DerelictGLVersion = mixin("GLVersion.GL" ~ to!string(major) ~ to!string(minor));
}

/++
The minimum required OpenGL version that Derelict must load for the program to initialize properly

Automatically set from glMajorVersion and glMinorVersion
+/
enum GLVersion glRequiredVersion = DerelictGLVersion!(glMajorVersion, glMinorVersion);
