/++
Loads .OBJ files
+/
module dge.graphics.formats.obj;

import core.exception;
import std.c.stdlib;
import std.conv;
import std.path;
import std.stdio;
import std.string;

import dge.graphics.formats.common;
import dge.graphics.formats.mtl;
import dge.graphics.mesh;
import dge.resource;

/++
Loads an OBJ file.

Current Limitations:

$(UL
	$(LI Assumes that both vertices and normals are supplied; texture coordinates still optional)
	$(LI Ignores the fourth vertex of quads))
+/

class OBJFile {

	class OBJError: Error {this(string filename, string msg) {super(`Error while loading "` ~ filename ~ `": ` ~ msg);}}

	this(const(char)[] filename, const char[][] path = [curdir]) {
		//Set the path while we open the file, then reset it.
		File file = File(filename, "r");
		//To do: shouldn't this be per object?
		Vertex[] sourceVertices;
		Normal[] sourceNormals;
		TexCoord2[] sourceTexCoords;
		SourceMesh[string] sourceObjects;
		SourceMesh currentObject;
		SourceFaceGroup currentFaceGroup;
		Material[string] materials;

		//Load all the data from the file
		foreach(char[] line; file.byLine()) {
			if(line.length > 0 && line[0] == '#') {
				//A comment; ignore it.
			} else if(line.length > 6 && line[0 .. 7] == "usemtl ") {
				//Switching materials
				string materialName = strip(line[7 .. $]).idup;
				if(materialName != "(null)") {
					//If the material has not been used, create a list of faces for it.
					if((materialName in currentObject.faceGroups) == null) {
						currentFaceGroup = currentObject.faceGroups[materialName] = new SourceFaceGroup;
					} else {
						currentFaceGroup = currentObject.faceGroups[materialName];
					}
				}
			} else if(line.length > 1 && line[0 .. 2] == "o ") {
				//A new object
				currentObject = sourceObjects[strip(line[2 .. $]).idup] = new SourceMesh;
				currentFaceGroup = null;
			} else if(line.length > 6 && line[0 .. 7] == "mtllib ") {
				MTLFile mf = load!MTLFile(strip(line[7 .. $]).idup, path);
				//Copy the file's materials into the main array.
				foreach(string s, Material m; mf.materials) {
					materials[s] = m;
				}
			} else if(currentObject !is null) {
				if(line.length > 1 && line[0 .. 2] == "v ") {
					//A vertex
					line = strip(line[2 .. $]);
					sourceVertices ~= Vertex(parseFloats!3(line));
				} else if(line.length > 2 && line[0 .. 3] == "vn ") {
					//A vertex normal
					line = strip(line[3 .. $]);
					Normal n;
					n.values = parseFloats!3(line);
					sourceNormals ~= n;
				} else if(line.length > 2 && line[0 .. 3] == "vt ") {
					//A texture coordinate
					line = strip(line[3 .. $]);
					TexCoord2 t;
					t.values = parseFloats!2(line);
					sourceTexCoords ~= t;
				} else if (line.length > 1 && line[0 .. 2] == "f ") {
					//A face
					if(currentFaceGroup is null) {
						currentObject.faceGroups[""] = currentFaceGroup = new SourceFaceGroup;
					}
					line = strip(line[2 .. $]);
					SourceFace f;
					for(size_t i = 0; i < 3; ++i) {
						f.vertices ~= parse!uint(line) - 1;
						//chomp the slash
						line = line[1 .. $];
						if(line[0] != '/') {
							//A texCoord is provided.
							f.texCoords ~= parse!uint(line) - 1;
						}
						line = line[1 .. $];
						f.normals ~= parse!uint(line) - 1;
						line = strip(line);
					}
					currentFaceGroup.faces ~= f;
				}
			}
		}

		//Build the Mesh objects
		foreach(string objectName, SourceMesh object; sourceObjects) {
			Mesh m = new Mesh();
			foreach(string materialName, SourceFaceGroup group; object.faceGroups) {
				FaceGroup fg = faceGroupFromSourceFaces(group.faces, sourceVertices, sourceNormals, sourceTexCoords);
				try {
					if(materialName != "") {
						fg.material = materials[materialName];
					}
				} catch(RangeError e) {
					throw new OBJError(filename, `Unable to find data for material "` ~ materialName ~ `".`);
				}
				m.faceGroups ~= fg;
			}
			meshes[objectName] = m;
		}
	}

	Mesh[string] meshes;
}

