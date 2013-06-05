/+-----------/
/-Mesh tools-/
/-----------+/

//TODO: allow transparency in colors, not just textures.
module dge.graphics.mesh;

import std.stdio;
import std.conv;
import std.math;
import std.string;

import derelict.opengl3.gl3;

import dge.config;
public import dge.graphics.material;
import dge.graphics.scene;
import dge.graphics.vao;
public import dge.math;
import dge.resource;
import dge.util.array;

/++
A typical mesh
+/
class Mesh {
	this() {
		vao = new VAO;
		vao.bind();
		posVbo = AttributeArray(3, GL_FLOAT, Vector3.sizeof);
		normalVbo = AttributeArray(3, GL_FLOAT, Vector3.sizeof);
		texCoordVbo = AttributeArray(2, GL_FLOAT, TexCoord2.sizeof);
	}

	public:
	void draw(Scene scene, TransformMatrix transform, bool useTransparency = true) {
		foreach(FaceGroup fg; faceGroups) {
			fg.draw(scene, transform);
		}
	}

    @property const(Vertex)[] vertices() const {
        return _vertices;
    }

    @property void vertices(Vertex[] verts) {
        _vertices = verts;
        posVbo.setData(vertices);
    }

    @property const(Normal)[] normals() const {
    	return _normals;
    }

    @property void normals(Normal[] norm) {
    	_normals = norm;
    	normalVbo.setData(norm);
    }

     @property const(TexCoord2)[] texCoords() const {
    	return _texCoords;
    }

    @property void texCoords(TexCoord2[] tc) {
    	_texCoords = tc;
    	texCoordVbo.setData(tc);
    }

	FaceGroup[] faceGroups;

	class FaceGroup {
		this(Material mat = new Material) {
			this.material = mat;
			elementArray = ElementArray(GL_UNSIGNED_INT);
		}

		this(Face[] faces, Material mat = new Material) {
			this.faces = faces;
			this(mat);
		}

		void draw(Scene scene, TransformMatrix model, bool useTransparency = false) {
			auto program = material.program;
			program.use();
			program.setUniform(program.vUniforms.model, model);
			program.setUniform(program.vUniforms.view, scene.activeCamera.view);
			program.setUniform(program.vUniforms.projection, scene.activeCamera.projection);

			material.use(program);
			LightNode.setProgramLights(program, scene);

			vao.bind();
			//To do: avoid repeating each frame?
			posVbo.bindToAttribute(program.vAttributes.position);
			posVbo.enable();
			normalVbo.bindToAttribute(program.vAttributes.normal);
			normalVbo.enable();
			if(texCoords.length > 0) {
				texCoordVbo.bindToAttribute(program.vAttributes.texCoord);
				texCoordVbo.enable();
			}
			elementArray.bind();

			glDrawElements(GL_TRIANGLES, cast(int)faces.length * 3, GL_UNSIGNED_INT, null);

			material.finish();

			posVbo.disable();
			normalVbo.disable();
			texCoordVbo.disable();
		}

		@property const(Face)[] faces() const {
			return _faces;
		}

		@property void faces(Face[] faces) {
			_faces = faces;
			elementArray.setData(_faces);
		}

		//To do: encapsulate?
		Material material;

		private:
		Face[] _faces;
		ElementArray elementArray;
	}

	private:
    Vertex[] _vertices;
	Normal[] _normals;
	TexCoord2[] _texCoords;
	AttributeArray posVbo, normalVbo, texCoordVbo;
	VAO vao;
}

class AnimatedMesh: Mesh {
	void draw(Scene scene, TransformMatrix viewTransform, size_t action, size_t frame, bool useTransparency = false) {

	}
	VertexAction[] vertexActions;
	uint[string] vertexActionLookup;
}

struct VertexAnimationFrame {
	Vector3[] vertices;
	Vector3[] normals;
}

struct VertexAction {
	VertexAnimationFrame[] frames;
}

struct Face {
	//To do: change index type?
	GLuint[3] vertices;
}

/+-------------------------------/
/--Functions to generate meshes--/
/-------------------------------+/

Mesh rectangle(GLfloat w, GLfloat h, Material mat = null) {
	if(mat is null) {
		mat = new Material;
		mat.diffuse = Color(1, 1, 1, 1);
	}
	Normal[] normals;

	Mesh m = new Mesh;
	m.faceGroups ~= m.new Mesh.FaceGroup(mat);
	Mesh.FaceGroup* fg = &m.faceGroups[0];
	m.vertices = [Vertex(w / 2.0, h / 2.0, 0), Vertex(w / 2.0, -h / 2.0, 0), Vertex(-w / 2.0, -h / 2.0, 0), Vertex(-w / 2.0, h / 2.0, 0)];
	for(uint i = 0; i < 4; ++i) {
		normals ~= Normal(0, 0, 1);
	}
	m.normals = normals;
	fg.faces = [Face([2, 1, 0]), Face([0, 3, 2])];

	m.texCoords = [TexCoord2(1, 0), TexCoord2(1, 1), TexCoord2(0, 1), TexCoord2(0, 0)];

	return m;
}
