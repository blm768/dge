/++
Classes, etc. to represent a game.

An instance of dge.game.Game must be created before any other DGE utilities are used.

Examples:
---
//Load libraries such as SDL.
Game.initLibraries();
//Create the window.
auto window = new Window(800, 600);
//Open the window and create the OpenGL context.
w.open();
//Create the game object.
auto game = new Game(window);
---
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

version(linux) {
	pragma(lib, "dl");
}

/++
Encapsulates rendering, event handling, etc. for the game

To do:
$(UL $(LI Profiling (% of frames that go over time, etc.)))
+/
class Game {
	public:
	this(Window w) {
		window = w;

		frameDuration  = TickDuration.from!"msecs"(1000/30);

		//To do: move out of the constructor?
		//To do: only reload if never done before?
		GLVersion glVersion = DerelictGL3.reload();
		if(glVersion < glRequiredVersion) {
			throw new Error("Unable to create OpenGL " ~ to!string(glMajorVersion) ~
				"." ~ to!string(glMinorVersion) ~ " or higher context. Please try updating your graphics drivers.");
		}

		scene = new Scene();
	}

	/++
	Loads external libraries such as SDL
	+/
	static void initLibraries() {
		//Load Derelict libraries
		DerelictSDL2.load();
		DerelictSDL2Image.load();
	
		//Set up SDL, etc:
		if(SDL_Init(SDL_INIT_EVERYTHING) != 0) {
			throw new Error("Unable to initialize SDL:" ~ to!string(SDL_GetError()));
		}
		DerelictGL3.load();

		//Set up input
		SDL_JoystickEventState(SDL_ENABLE);
	}

	void mainLoop() {
		running = true;
		SDL_Event evt;
		frameTimer.start();
		while(running) {
			//Handle events during idle time.
			//To do: stop doing so much spinning?
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
				//To do: make dead zone configurable.
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
	Window window;
	TickDuration frameDuration;

	private:
	bool running;
	StopWatch frameTimer;
}