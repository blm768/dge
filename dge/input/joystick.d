/++
Joystick support
+/
module dge.input.joystick;

import std.conv;

import derelict.sdl2.sdl;

/++
A joystick

This should not generally be used by client code; the
mapping interface is more flexible. However, 
+/
class Joystick {
	/++
	Creates a Joystick using attached joystick #num
	+/
	this(uint num) {
		if(num >= count) {
			throw new Error("Joystick #" ~ to!string(num) ~ " not found.");
		}
		this.num = num;
		name = to!string(SDL_JoystickName(num));
		js = SDL_JoystickOpen(num);
		//To do: get uninitialized array or init each element to 0.0
		axes.length = SDL_JoystickNumAxes(js);
		//Clear the array to 0.0 so the default NaN doesn't cause problems.
		for(uint i = 0; i < axes.length; ++i) {
			axes[i] = 0.0;
		}
		buttons.length = SDL_JoystickNumButtons(js);
		openedJoysticks[num] = this;
	}
	
	~this() {
		SDL_JoystickClose(js);
	}
	
	SDL_Joystick* js;
	string name;
	uint num;
	float[] axes;
	bool[] buttons;
	
	///The number of attached joysticks
	static @property uint count() {
		return SDL_NumJoysticks();
	}
	
	///All opened joysticks by number
	static Joystick[uint] openedJoysticks;
}