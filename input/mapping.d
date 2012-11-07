/++
Tools for mapping input events to actions
+/
module dge.input.mapping;

import core.exception;
import std.conv;
import std.math;
import std.stdio;

public import derelict.sdl2.sdl;

public import dge.input.keyboard;
public import dge.input.joystick;

/++
Maps input events to enum values

T is the type of the enum.
+/
class Mapping(T) {
	public:
	this() {
		keys = new KeyboardMapping!(T);
		pseudoAnalogKeys = new PseudoAnalogKeyboardMapping!(T);
		jsButtons = new JoystickButtonMapping!(T);
		pseudoAnalogJSButtons = new PseudoAnalogJoystickButtonMapping!(T);
		jsAxes = new JoystickAxisMapping!(T);
	}
	
	/++
	Get the status of the given digital event
	
	If a joystick is not specified, only events bound to keys will be detected.
	+/
	DigitalStatus digitalStatus(T event, Joystick js = null) {
		KeyboardStatus k = keys.status(event);
		if(k.pressed) {
			return k;
		}
		if(js !is null) {
			JoystickButtonStatus b = jsButtons.status(js.num, event);
			if(b.pressed) {
				return b;
			}
		}
		return new DigitalStatus(false);
	}
	
	/++
	Get the status of the given analog or pseudo-analog event
	+/
	AnalogStatus analogStatus(T event, Joystick js = null) {
		if(js !is null) {
			JoystickAxisStatus a = jsAxes.status(js.num, event);
			if(!isNaN(a.value)) {
				return a;
			}
			AnalogStatus pa = pseudoAnalogJSButtons.status(js.num, event);
			if(!isNaN(pa.value)) {
				return pa;
			}
		}
		AnalogStatus k = pseudoAnalogKeys.status(event);
		if(!isNaN(k.value)) {
			return k;
		}
		return new AnalogStatus(0.0);
	}
	
	KeyboardMapping!(T) keys; ///
	PseudoAnalogKeyboardMapping!(T) pseudoAnalogKeys; ///
	JoystickButtonMapping!(T) jsButtons; ///
	PseudoAnalogJoystickButtonMapping!(T) pseudoAnalogJSButtons; ///
	JoystickAxisMapping!(T) jsAxes; ///
}

///
abstract class EventStatus {};

///
class DigitalStatus: EventStatus {
	this(bool pressed) {
		this.pressed = pressed;
	}
	
	///
	bool pressed;
}

class AnalogStatus: EventStatus {
	this(float value) {
		this.value = value;
	}
	
	float value;
}

///
class KeyboardStatus: DigitalStatus {
	this(bool pressed) {
		super(pressed);
	}
}

///
class JoystickButtonStatus: DigitalStatus {
	this(bool pressed, uint joystick) {
		super(pressed);
		this.joystick = joystick;
	}
	
	uint joystick; ///
}

///
class JoystickAxisStatus: AnalogStatus {
	this(float value, uint joystick) {
		super(value);
		this.joystick = joystick;
	}
	
	uint joystick; ///
}

///
class KeyboardMapping(T) {
	public:
	///
	KeyboardStatus status(T event) {
		SDL_Scancode* k = (event in mappings);
		if(k == null) {
			return new KeyboardStatus(false);
		} //else
		return new KeyboardStatus(keys[*k]);
	}
	
	SDL_Scancode[T] mappings; ///
}

class PseudoAnalogKeyboardMapping(T) {
	public:
	///
	AnalogStatus status(T event) {
		SDL_Scancode[2]* k = (event in mappings);
		if(k == null) {
			return new AnalogStatus(float.nan);
		} //else
		float result = 0.0;
		if(keys[(*k)[0]]) {
			result += 1.0;
		}
		if(keys[(*k)[1]]) {
			result -= 1.0;
		}
		return new AnalogStatus(result);
	}

	SDL_Scancode[2][T] mappings;
}

class JoystickButtonMapping(T) {
	public:
	
	JoystickButtonStatus status(uint jsNum, T event) {
		uint[T]* jsMappings = (jsNum in mappings);
		if(jsMappings == null) {
			return new JoystickButtonStatus(false, jsNum);
		} //else
		uint* mapping = (event in *jsMappings);
		if(mapping == null) {
			return new JoystickButtonStatus(false, jsNum);
		} //else
		try {
			return new JoystickButtonStatus(Joystick.openedJoysticks[jsNum].buttons[*mapping], jsNum);
		} catch(RangeError e) {
			throw new Error("Event code " ~ to!string(event) ~ "is mapped to an invalid joystick or button number.");
		}
	}
	
	uint[T][uint] mappings;
}

class JoystickAxisMapping(T) {
	public:
	///
	JoystickAxisStatus status(uint jsNum, T event) {
		uint[T]* jsMappings = (jsNum in mappings);
		if(jsMappings == null) {
			return new JoystickAxisStatus(float.nan, jsNum);
		} //else
		uint* mapping = (event in *jsMappings);
		if(mapping == null) {
			return new JoystickAxisStatus(float.nan, jsNum);
		} //else
		try {
			return new JoystickAxisStatus(Joystick.openedJoysticks[jsNum].axes[*mapping], jsNum);
		} catch(RangeError e) {
			throw new Error("Event code " ~ to!string(event) ~ " is mapped to an invalid joystick or axis number.");
		}
	}
	
	uint[T][uint] mappings;
}

///
class PseudoAnalogJoystickButtonMapping(T) {
	///
	JoystickAxisStatus status(uint jsNum, T event) {
		uint[2][T]* jsMappings = (jsNum in mappings);
		if(jsMappings == null) {
			return new JoystickAxisStatus(float.nan, jsNum);
		} //else
		uint[2]* mapping = (event in *jsMappings);
		if(mapping == null) {
			return new JoystickAxisStatus(float.nan, jsNum);
		} //else
		try {
			float result = 0.0;
			if(Joystick.openedJoysticks[jsNum].buttons[(*mapping)[0]]) {
				result += 1.0;
			}
			if(Joystick.openedJoysticks[jsNum].buttons[(*mapping)[1]]) {
				result -= 1.0;
			}
			return new JoystickAxisStatus(result, jsNum);
		} catch(RangeError e) {
			throw new Error("Event code " ~ to!string(event) ~ "is mapped to an invalid joystick or button number.");
		}
	}

	uint[2][T][uint] mappings;
}