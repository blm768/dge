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

	string glslVersion = "330",

	bool useBufferAlpha = false,
	size_t defaultDepthBits = 24,
	size_t defaultStencilBits = 8,

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
