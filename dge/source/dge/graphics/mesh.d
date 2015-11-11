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
		vao = VAO.create();
		vao.bind();
		posVbo = AttributeArray(3, GL_FLOAT, Vector3.sizeof);
		normalVbo = AttributeArray(3, GL_FLOAT, Vector3.sizeof);
		texCoordVbo = AttributeArray(2, GL_FLOAT, TexCoord2.sizeof);
	}

	public:
	void draw(Scene scene, TransformMatrix transform, Material mat = null) {
		foreach(FaceGroup fg; faceGroups) {
			fg.draw(scene, transform);
		}
	}

    @property const(Vertex)[] vertices() const {
        return _vertices;
    }

    @property void vertices(const(Vertex)[] verts) {
        _vertices = verts;
        posVbo.setData(verts);
    }

    @property const(Normal)[] normals() const {
    	return _normals;
    }

    @property void normals(const(Normal)[] norm) {
    	_normals = norm;
    	normalVbo.setData(norm);
    }

     @property const(TexCoord2)[] texCoords() const {
    	return _texCoords;
    }

    @property void texCoords(const(TexCoord2)[] tc) {
    	_texCoords = tc;
    	texCoordVbo.setData(tc);
    }

	FaceGroup[] faceGroups;

	class FaceGroup {
		this(Material mat = null) {
			if(mat is null) {
				mat = new Material;
			}
			this.material = mat;
			elementArray = ElementArray(GL_UNSIGNED_INT);
		}

		this(Face[] faces, Material mat = null) {
			this.faces = faces;
			this(mat);
		}

		void prepDraw(Scene scene, TransformMatrix model, Material mat) {
			auto program = mat.program;
			program.use();
			program.setUniform(program.vUniforms.model, model);
			program.setUniform(program.vUniforms.view, scene.activeCamera.view);
			program.setUniform(program.vUniforms.projection, scene.activeCamera.projection);

			mat.use();
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
		}

		void finishDraw(Material mat) {
			mat.finish();

			posVbo.disable();
			normalVbo.disable();
			texCoordVbo.disable();
		}

		/++
		Draws the FaceGroup
		+/
		void draw(Scene scene, TransformMatrix model, Material mat = null) {
			if(!mat) {
				mat = material;
			}
			prepDraw(scene, model, mat);

			glDrawElements(GL_TRIANGLES, cast(int)faces.length * 3, GL_UNSIGNED_INT, null);

			finishDraw(mat);
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

    const(Vertex)[] _vertices;
	const(Normal)[] _normals;
	const(TexCoord2)[] _texCoords;
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
