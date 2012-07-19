/++
Classes, etc. to represent a game.

An instance of dge.game.Game must be created before any other DGE utilities are used.
+/
module dge.game;

import std.conv;
import std.datetime;
import std.stdio;

import derelict.opengl3.gl3;
import derelict.sdl2.image;
import derelict.sdl2.sdl;

import dge.config;
public import dge.graphics.scene;
public import dge.input.mapping;
public import dge.sound;
public import dge.window;

version(Windows) {
	static if(useDerelictLibs) {
		pragma(lib, `lib\DerelictUtil.lib`);
		pragma(lib, `lib\DerelictSDL.lib`);
		pragma(lib, `lib\DerelictSDLimage.lib`);
		pragma(lib, `lib\DerelictSDLMixer.lib`);
		pragma(lib, `lib\DerelictGL.lib`);
		pragma(lib, `lib\DerelictGLU.lib`);
	}
}

version(linux) {
	pragma(lib, "dl");
}

//To do: move this out of here.
immutable uint screenWidth = 800;
immutable uint screenHeight = 600;
immutable GLfloat aspectRatio = cast(float)screenWidth / cast(float)screenHeight;
immutable GLfloat near = 0.1;
immutable GLfloat far = 1000;
immutable GLfloat angle = PI / 4;

/++
Encapsulates rendering, event handling, etc. for the game

To do:
Profiling (% of frames that go over time, etc.)
Unit tests, etc. for all files/functions that need them
+/
class Game {
	public:
	this() {

		frameDuration = TickDuration.from!"msecs"(1000/30);

		//Load Derelict libraries
		DerelictSDL2.load();
		DerelictSDL2Image.load();
		//DerelictSDLMixer.load();
		DerelictGL3.load();

		//Set up SDL, etc:
		if(SDL_Init(SDL_INIT_EVERYTHING) != 0) {
			throw new Error("Unable to initialize SDL:" ~ to!string(SDL_GetError()));
		}

		window = new Window;

		GLVersion glVersion = DerelictGL3.reload();
		if(glVersion < glRequiredVersion) {
			throw new Error("Unable to create OpenGL " ~ to!string(glMajorVersion) ~
				"." ~ to!string(glMinorVersion) ~ " or higher context. Please try updating your graphics drivers.");
		}

		/++
		//Set up sound.
		int audioRate = 22050;
		Uint16 audioFormat = MIX_DEFAULT_FORMAT;
		int audioChannels = 2;
		int audioBuffers = 4096;

		if(Mix_OpenAudio(audioRate, audioFormat, audioChannels, audioBuffers) != 0) {
			throw new Error("Unable to initialize audio: " ~ to!string(Mix_GetError()));
		}+/

		scene = new Scene();

		//Set up input
		SDL_JoystickEventState(SDL_ENABLE);
	}

	void mainLoop() {
		running = true;
		SDL_Event evt;
		frameTimer.start();
		while(running) {
			//Handle events during idle time.
			//We need do/while so the event loop will run at least once.
			do {
				while(SDL_PollEvent(&evt)) {
					handleEvent(evt);
				}
			} while (frameTimer.peek() < frameDuration);
			frameTimer.reset();
			loop();
			render();
		}
	}

	void loop() {
		scene.update();
	}

	void render() {
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		scene.render();
		window.present();
	}

	void handleEvent(ref SDL_Event evt) {
		switch(evt.type) {
			case SDL_QUIT:
				running = false;
				break;
			case SDL_KEYDOWN:
				keys[evt.key.keysym.scancode] = true;
				break;
			case SDL_KEYUP:
				keys[evt.key.keysym.scancode] = false;
				break;
			case SDL_JOYBUTTONDOWN:
				Joystick.openedJoysticks[evt.jbutton.which].buttons[evt.jbutton.button] = true;
				break;
			case SDL_JOYBUTTONUP:
				Joystick.openedJoysticks[evt.jbutton.which].buttons[evt.jbutton.button] = false;
				break;
			case SDL_JOYAXISMOTION:
				//Is the value outside the "dead zone?"
				if(evt.jaxis.value < -3200 || evt.jaxis.value > 3200) {
					Joystick.openedJoysticks[evt.jaxis.which].axes[evt.jaxis.axis] = cast(float)evt.jaxis.value/327678.0;
				} else {
					Joystick.openedJoysticks[evt.jaxis.which].axes[evt.jaxis.axis] = 0;
				}
				break;
			default:
				break;
		}
	}

	~this() {
		SDL_Quit();
	}

	Scene scene;

	private:
	bool running;
	StopWatch frameTimer;
	TickDuration frameDuration;
	Window window;

}
