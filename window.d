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
+/
class Window {
	this(uint width, uint height) {
		_width = width;
		_height = height;

		scene = new Scene;
	}

	void open() in {
		assert(!isOpen, "Window must be closed before reopening");	
	} body {
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, glMajorVersion);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, glMinorVersion);

		//Make sure we get an accelerated renderer.
		SDL_GL_SetAttribute(SDL_GL_ACCELERATED_VISUAL, 1);

        SDL_GL_SetAttribute(SDL_GL_RED_SIZE,     8);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,   8);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,    8);
		static if(useBufferAlpha) {
			SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,   8);
		}
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,   depthBufferSize);
		SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, stencilBufferSize);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

		_window = SDL_CreateWindow(null, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                            width, height, SDL_WINDOW_OPENGL);
        if(!_window) {
            throw new Error("Unable to create SDL window: " ~ to!string(SDL_GetError()));
		}

        context = SDL_GL_CreateContext(_window);
		if(!context) {
			throw new Error("Unable to create OpenGL " ~ to!string(glMajorVersion) ~
				"." ~ to!string(glMinorVersion) ~ " or higher context. Please try updating your graphics drivers.");
		}

		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClearDepth(1.0);

		glEnable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);

		onResize();
		
		_isOpen = true;
	}

	/++
	Make this window's context the current OpenGL context
	+/
	void makeCurrent() {
		SDL_GL_MakeCurrent(_window, &context);
	}

	void close() {
		if(_window) {
			SDL_DestroyWindow(_window);
		}
		_window = null;
	}

	/++
	+/
	void render() in {
		assert(_isOpen, "Window is not open");
		assert(scene, "Unable to render window with no scene");
	} body {
		scene.render();
		present();
	}

	/++
	Swaps the window's buffers
	+/
	void present() {
        SDL_GL_SwapWindow(_window);
	}

	///
	@property uint width() {
		return _width;
	}

	///
	@property uint height() {
		return _height;
	}
	
	@property bool isOpen() {
		return _isOpen;
	}

	///
	Scene scene;

	~this() {
		//To do: consider the case if SDL is quit before this destructor is called.
		close();
	}

	private:
	void onResize() {
		//To do: camera adjustment?
		//Make sure this is the right window and context.
		glViewport(0, 0, width, height);
	}

	uint _width, _height;
	bool _isOpen;
	SDL_Window* _window;
	SDL_GLContext context;
	SDL_RendererInfo info;
}

