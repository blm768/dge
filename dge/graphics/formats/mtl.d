/++
Tools for loading .MTL files
+/

module dge.graphics.formats.mtl;

import std.conv;
import std.path;
import std.stdio;
import std.string;

import dge.graphics.formats.common;
import dge.graphics.mesh;
import dge.resource;


/++
Loads a .MTL file

Limitations:

Ignores the Ns attribute
+/
class MTLFile {
	public:
	this(string filename, const string[] path = [curdir]) {
		File file = File(filename);
		Material currentMaterial;
		foreach(char[] line; file.byLine()) {
			if(line.length >= 7 && line[0 .. 7] == "newmtl ") {
					currentMaterial = materials[strip(line[7 .. $]).idup] = new Material;
			} else if(currentMaterial !is null) {
				if(line.length >= 3 && line[0 .. 3] == "Ka ") {
					line = strip(line[3 .. $]);
					currentMaterial.ambient.values[0 .. 3] = parseFloats!3(line);
				} else if(line.length >= 3 && line[0 .. 3] == "Kd ") {
					line = strip(line[3 .. $]);
					currentMaterial.diffuse.values[0 .. 3] = parseFloats!3(line);
				} else if(line.length >= 3 && line[0 .. 3] == "Ks ") {
					line = strip(line[3 .. $]);
					currentMaterial.specular.values[0 .. 3] = parseFloats!3(line);
				} else if(line.length >= 7 && line[0 .. 7] == "map_Kd ") {
					currentMaterial.texture = load!Texture(strip(line[7 .. $]).idup, path);
				} else if(line.length >= 6 && line[0 .. 6] == "illum ") {
					line = strip(line[6 .. $]);
					int illum = parse!int(line);
					if(illum == 0) {
						currentMaterial.usesLighting = false;
					}
				}
			}
		}
	}
	
	Material[string] materials;
}