module dge.window;

import std.conv;
import std.stdio;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import std.string;

import dge.config;
import dge.graphics.scene;

/++
An OpenGL window

To do: remove default window size?
+/
class Window {
	this(uint width = 800, uint height = 600) {
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, glMajorVersion);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, glMinorVersion);

		//Make sure we get an accelerated renderer.
		SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);

        SDL_GL_SetAttribute(SDL_GL_RED_SIZE,     8);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,   8);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,    8);
		SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,   8);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,   depthBufferSize);
		SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, stencilBufferSize);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

		window = SDL_CreateWindow(null, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                            width, height, SDL_WINDOW_OPENGL);
        if(!window) {
            throw new Error("Unable to create SDL window: " ~ to!string(SDL_GetError()));
		}

        context = SDL_GL_CreateContext(window);
		if(!context) {
			throw new Error("Unable to create OpenGL " ~ to!string(glMajorVersion) ~
				"." ~ to!string(glMinorVersion) ~ " or higher context. Please try updating your graphics drivers.");
		}

		glClearColor(0.0, 1.0, 0.0, 1.0);
		glClearDepth(1.0);

		/+glEnable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);+/

		scene = new Scene;

		onResize();
	}

	/++
	Make this window's context the current OpenGL context
	+/
	void makeCurrent() {
		SDL_GL_MakeCurrent(window, &context);
	}

	/++
	+/
	void render() in {
		assert(scene, "Unable to render window with no scene");
	} body {
		scene.render();
		present();
	}

	/++
	Swaps the window's buffers
	+/
	void present() {
        SDL_GL_SwapWindow(window);
	}

	///
	@property uint width() {
		return _width;
	}

	///
	@property uint height() {
		return _height;
	}

	///
	Scene scene;

	private:
	void onResize() {
		//To do: camera adjustment?
		//Make sure this is the right window and context.
		glViewport(0, 0, width, height);
	}

	uint _width, _height;
	SDL_Window* window;
	SDL_GLContext context;
	SDL_RendererInfo info;
}
