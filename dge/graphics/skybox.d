/++Probably broken; don't use.+/
module dge.graphics.skybox;

import std.stdio;

import derelict.opengl3.gl3;

import dge.graphics.mesh;

version(none) {

Mesh skybox(Texture t) {
    Material mat = new Material;
	mat.usesLighting = false;
	mat.diffuse = Color(1.0, 1.0, 1.0, 1.0);
	mat.texture = t;

	Mesh m = new Mesh;
	m.faceGroups ~= m.new Mesh.FaceGroup(mat);
	Mesh.FaceGroup fg = m.faceGroups[0];
	//-X face
	for(uint y = 0; y <=1; ++y) {
		for(uint z = 0; z <=1; ++z) {
			m.vertices ~= Vertex(-1.0, -1.0 + (2 * y), -1.0 + (2 * z));
			m.texCoords ~= TexCoord2(1.0/3.0 - z * 1.0/3.0, .5 - y * .5);
			m.normals ~= Normal(1, 0, 0);
		}
	}
	fg.faces ~= [Face([1, 2, 3]), Face([0, 2, 1])];

	//-Z face
	for(uint x = 0; x <=1; ++x) {
		for(uint y = 0; y <=1; ++y) {
			m.vertices ~= Vertex(-1.0 + 2 * x, -1.0 + 2 * y, -1);
			m.texCoords ~= TexCoord2(x * 1.0/3.0 + 2.0/3.0, 1.0 - y * .5);
			m.normals ~= Normal(0, 0, 1);
		}
	}
	fg.faces ~= [Face([5, 6, 7]), Face([4, 6, 5])];

	//+X face
	for(uint y = 0; y <=1; ++y) {
		for(uint z = 0; z <=1; ++z) {
			m.vertices ~= Vertex(1.0, -1.0 + (2 * y), -1.0 + (2 * z));
			m.texCoords ~= TexCoord2(z * 1.0/3 + 2.0/3, .5 - y * .5);
			m.normals ~= Normal(-1, 0, 0);
		}
	}
	fg.faces ~= [Face([11, 10, 9]), Face([9, 10, 8])];

	//-Y face
	for(uint x = 0; x <=1; ++x) {
		for(uint z = 0; z <=1; ++z) {
			m.vertices ~= Vertex(-1.0 + 2 * x, -1, -1.0 + 2 * z);
			m.texCoords ~= TexCoord2(x * 1.0/3.0, z * .5 + .5);
			m.normals ~= Normal(0, 1, 0);
		}
	}
	fg.faces ~= [Face([15, 14, 13]), Face([13, 14, 12])];

	//+Y face
	for(uint x = 0; x <=1; ++x) {
		for(uint z = 0; z <=1; ++z) {
			m.vertices ~= Vertex(-1.0 + 2 * x, 1, -1.0 + 2 * z);
			m.texCoords ~= TexCoord2(x * 1.0/3 + 1.0/3.0, 1.0 - z * .5);
			m.normals ~= Normal(0, -1, 0);
		}
	}
	fg.faces ~= [Face([17, 18, 19]), Face([16, 18, 17])];

	//+Z face
	for(uint x = 0; x <=1; ++x) {
		for(uint y = 0; y <=1; ++y) {
			m.vertices ~= Vertex(-1.0 + 2 * x, -1.0 + 2 * y, 1);
			m.texCoords ~= TexCoord2(2.0/3.0 - x * 1.0/3.0, .5 - y * .5);
			m.normals ~= Normal(0, 0, -1);
		}
	}
	fg.faces ~= [Face([23, 22, 21]), Face([21, 22, 20])];

	return m;
}
}
