module dge.sound;

import std.conv;
import std.string;

version(none) {
import derelict.sdl2.sdl;

import dge.resource;

enum int loopForever = -1;
enum int firstFreeChannel = -1;

class Music {
	this(const char [] filename, const char[][] path = [getcwd()]) {
		music = Mix_LoadMUS(toStringz(filename));
		if(!music){
			throw new Error(`Unable to load file "` ~ filename.idup);
		}
		Mix_HookMusicFinished(&onMusicFinished);
	}
	
	void play(int loops = loopForever) {
		playing = this;
		Mix_PlayMusic(music, loops);
	}
	
	void stop() {
		Mix_HaltMusic();
		playing = null;
	}
	
	@property void volume(int volume) {
		Mix_VolumeMusic(volume);
	}
	
	@property int volume() {
		return Mix_VolumeMusic(-1);
	}
	
	~this() {
		Mix_FreeMusic(music);
	}
	
	static Music playing;
	
	static extern(C) void onMusicFinished() {
		playing = null;
	}
	
	private:
	Mix_Music* music;
}

class Sound {
	this(const char[] filename, const char[][] path = [getcwd()]) {
		chunk = Mix_LoadWAV(filename.idup);
		if(!chunk) {
			throw new Error(`Unable to load file "` ~ filename.idup);
		}
	}
	
	void play(int loops = 0) {
		channel = Mix_PlayChannel(firstFreeChannel, chunk, loops);
		if(channel == -1) {
			throw new Error("Unable to play sound: " ~ to!string(Mix_GetError()));
		}
	}
	
	void pause() {
		Mix_Pause(channel);
	}
	
	void resume() {
		Mix_Resume(channel);
	}
	
	void stop() {
		Mix_HaltChannel(channel);
	}
	
	@property bool playing() {
		return Mix_Playing(channel) != 0;
	}
	
	~this() {
		Mix_FreeChunk(chunk);
	}
	
	private:
	Mix_Chunk* chunk;
	int channel;
}
}