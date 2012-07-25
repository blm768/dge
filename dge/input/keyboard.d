/++
Keyboard input
+/
module dge.input.keyboard;

import std.string;

import derelict.sdl2.sdl;

/++
Maps key names to SDL key codes

Examples:
assert(key!"up" == SDL_SCANCODE_UP);
+/
template key(string k) {
	mixin("enum SDL_Scancode key = SDL_SCANCODE_" ~ toUpper(k) ~ ";");
}

package bool[SDL_NUM_SCANCODES] keys;
