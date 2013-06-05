/++
Classes for resource management
+/
module dge.resource;

import std.file;
public import std.path;
import std.stdio;

class ResourceError: Error {this(const char[] filename) {super((`Unable to load file "` ~ filename ~ `".`).idup);}}

static T load(T)(const char[] filename, const char[][] path = [getcwd()]) {
	static T[string] loadedResources;
	
	T loadResource(string fullName) {
		T* prev = (fullName in loadedResources);
		if(prev == null) {
			T r = loadedResources[fullName] = new T(fullName, path);
			return r;
		} else {
			return *prev;
		}
	}
	
	//If this is an absolute path, don't check through the supplied search path.
	if(isAbsolute(filename)) {
		return loadResource(filename.idup);
	}
	
	foreach(const char[] s; path) {
		string fullName = buildNormalizedPath(s, filename);
		if(exists(fullName)) {
			return loadResource(fullName);
		}
	}
	
	//If the load failed:
	throw new ResourceError(filename);
}

