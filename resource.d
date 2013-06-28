/++
Utilities for resource management
+/
module dge.resource;

import std.file;
public import std.path;
import std.stdio;

class ResourceError: Error {this(const char[] filename) {super((`Unable to load file "` ~ filename ~ `".`).idup);}}

static string locate(const char[] filename, const char[][] path = [getcwd()]) {
	//If this is an absolute path, don't check through the supplied search path.
	if(isAbsolute(filename)) {
		filename.idup;
	}
	
	foreach(const char[] s; path) {
		string fullName = buildNormalizedPath(s, filename);
		if(exists(fullName)) {
			return fullName;
		}
	}
	
	//If the resource wasn't located:
	throw new ResourceError(filename);
}

