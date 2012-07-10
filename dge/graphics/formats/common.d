/++
Common tools for all format loaders
+/
module dge.graphics.formats.common;

import std.array;
import std.conv;
import std.stdio;

//To do: remove this when DMD bug fixed
import std.c.stdlib;

import derelict.opengl3.gl3;

public import dge.graphics.mesh;

//To do: reduce number of memory allocations.
Mesh sourceMeshToMesh(SourceMesh src, Material[string] materials) {
	Mesh m;
	Vertex[] vertices;
	Normal[] normals;
	TexCoord2[] texCoords;
	VertexAction[] srcVertexActions, vertexActions;
	uint[string] vertexActionLookup;
	uint[SourceVertex] usedSets;

	//Set up actions.
	//We'll convert the associative array to a linear one so we don't have to always use AA lookups.
	vertexActions.length = srcVertexActions.length = src.vertexActions.length;
	size_t vertexActionIndex = 0;
	foreach(string name, VertexAction srcAct; src.vertexActions) {
		srcVertexActions[vertexActionIndex] = srcAct;
		VertexAction act;
		act.frames.length = srcAct.frames.length;
		vertexActions[vertexActionIndex] = act;
		vertexActionLookup[name] = cast(uint)vertexActionIndex;
		++vertexActionIndex;
	}

	if(vertexActions.length > 0) {
		m = new AnimatedMesh;
	} else {
		m = new Mesh;
	}

	//To do: use uninitializedArray.
	m.faceGroups.length = src.faceGroups.length;
	size_t faceGroupIndex = 0;
	foreach(string matName, SourceFaceGroup srcFg; src.faceGroups) {
		Material mat = materials.get(matName, null);
		assert(mat, `Unable to locate material "` ~ matName ~ `"`);

		Mesh.FaceGroup fg = m.new Mesh.FaceGroup(mat);

		Face[] faces;
		faces.length = srcFg.faces.length;
		//loop over the source faces
		foreach(size_t faceIndex, SourceFace face; srcFg.faces) {
			Face nextFace;
			//Loop over the vertices.
			for(uint i = 0; i < 3; ++i) {
				uint v = face.vertices[i];
				uint n = face.normals[i];
				uint t = 0;
				//If texCoords are included in the data, get the index; otherwise, use zero as a dummy value.
				if(face.texCoords.length > 0) {
					t = face.texCoords[i];
				}

				auto vertex = SourceVertex(v, n, t);

				//Has this vertex/normal/texCoord set been used before?
				if((vertex in usedSets) == null) {
					//Nope.
					//Copy the source vertex to the new vertex array:
					vertices ~= src.vertices[v];
					normals ~= src.normals[n];

					//If we have tex coordinates, copy them.
					if(face.texCoords.length > 0) {
						texCoords ~= src.texCoords[t];
					}

					//If there are actions, handle them.
					if(src.vertexActions.length > 0) {
						foreach(size_t actIndex, VertexAction srcAct; srcVertexActions) {
							foreach(size_t frameIndex, VertexAnimationFrame srcFrame; srcAct.frames) {
								vertexActions[actIndex].frames[frameIndex].vertices ~= srcFrame.vertices[v];
								vertexActions[actIndex].frames[frameIndex].normals ~= srcFrame.normals[n];
							}
						}
					}

					//Add an entry to UsedSets:
					usedSets[vertex] = cast(uint)vertices.length - 1;
				}
				nextFace.vertices[i] = usedSets[vertex];
			}
			faces[faceIndex] = nextFace;
		}
		fg.faces = faces;
		m.faceGroups[faceGroupIndex] = fg;
		++faceGroupIndex;
	}

	m.vertices = vertices;
	m.normals = normals;
	m.texCoords = texCoords;

	if(vertexActions.length > 0) {
		auto am = cast(AnimatedMesh)m;
		am.vertexActions = vertexActions;
		am.vertexActionLookup = vertexActionLookup;
	}

	return m;
}

/++
A face with an arbitry number of vertices; vertices, normals, and texture coordinates are specified per face.
To do: switch to a triangle system? Unify arrays into SourceVertex[]?
+/
struct SourceFace {
	GLuint[] vertices;
	GLuint[] normals;
	GLuint[] texCoords;
}

///Represents a vertex of a polygon
struct SourceVertex {
	GLuint vertex, normal, texCoord;
}

class SourceMesh {
	/++
	Face groups by material
	+/
	SourceFaceGroup[string] faceGroups;
	Vector3[] vertices;
	Vector3[] normals;
	TexCoord2[] texCoords;
	VertexAction[string] vertexActions;
}

class SourceFaceGroup {
	SourceFace[] faces;
}

/++
Parses n floats
+/
float[n] parseFloats(size_t n)(ref const(char)[] line) {
	float[n] floats;
	//Using C functions until DMD Bugzilla 2962 is fixed:
	const(char)[] cLine = line ~ "\0";
	char* pos = null;
	for(size_t i = 0; i < n; ++i) {
		floats[i] = strtof(cLine.ptr, &pos);
		cLine = cLine[pos - cLine.ptr .. $];
	}
	line = cLine[0 .. $ - 1];
	/+for(size_t i = 0; i < n; ++i) {
		floats[i] = parse!float(line);
	}+/
	return floats;
}
