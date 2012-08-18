/++
Materials, textures, and fragment shaders
+/
module dge.graphics.material;

import std.file;
import std.stdio;
import std.string;

import derelict.opengl3.gl3;
import derelict.sdl2.image;
import derelict.sdl2.sdl;


import dge.config;
public import dge.graphics.shader;

struct TexCoord2 {
	this(GLfloat x, GLfloat y) {
		this.x = x;
		this.y = y;
	}

	GLfloat[2] values;
	@property GLfloat* ptr() {return values.ptr;}

	@property GLfloat x() {
		return values[0];
	}

	@property void x(GLfloat x) {
		values[0] = x;
	}

	@property GLfloat y() {
		return values[1];
	}

	@property void y(GLfloat y) {
		values[1] = y;
	}
}

/++
Represents an OpenGL color

If it is not initialized, it will be fully transparent black.
+/
struct Color {
	GLfloat[4] values = [0f, 0f, 0f, 1f];
	@property GLfloat* ptr() {return values.ptr;}

	this(float r, float g, float b, float a = 1.0) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	@property GLfloat r() pure const {
		return values[0];
	}

	@property void r(GLfloat r) {
		values[0] = r;
	}

	@property GLfloat g() pure const {
		return values[1];
	}

	@property void g(GLfloat g) {
		values[1] = g;
	}

	@property GLfloat b() pure const {
		return values[2];
	}

	@property void b(GLfloat b) {
		values[2] = b;
	}

	@property GLfloat a() pure const {
		return values[3];
	}

	@property void a(GLfloat a) {
		values[3] = a;
	}

	alias a alpha;
}

/++
Standard, color-based material
+/
class Material {
	public:
	this() {
		_vertShader = defaultVertexShader;
		_fragShader = materialFragmentShader;
		setProgram();
	}

	this(Color diffuse, Color specular, Color emission = Color(), GLfloat shininess = 0.0, Color ambient = diffuse) {
		this.diffuse = diffuse;
		this.ambient = ambient;
		this.specular = specular;
		this.emission = emission;
		this.shininess = shininess;
		this();
	}

	Color diffuse;
	Color ambient;
	Color specular;
	Color emission;
	GLfloat shininess = 0.0;
	bool usesLighting = true;

	///Sets both diffuse and ambient at once.
	void setBaseColor(Color c) {
		diffuse = ambient = c;
	}

	/++
	Prepare to draw using this material

	The caller must bind the shader and its values.

	To do: make use() handle some shader stuff?
	+/
	void use(DGEShaderProgram program) {
		if(transparent) {
			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		}
		program.setUniform(program.matUniforms.diffuse, diffuse);
		if(texture) {
			texture.bind(0);
			program.setUniform(program.matUniforms.surface, 0);
		}
	}

	/++
	Finish drawing using this material
	+/
	void finish() {
		glDisable(GL_BLEND);
		if(texture) {
			texture.unbind(0);
		}
	}

	@property FragmentShader fragShader() {
		return _fragShader;
	}

	@property VertexShader vertShader() {
		return _vertShader;
	}

	@property DGEShaderProgram program() {
		return _program;
	}

	@property Texture texture() {
		return _texture;
	}

	@property void texture(Texture tex) {
		_texture = tex;
		//To do: optimize for case when program doesn't change?
		if(tex) {
			_fragShader = textureFragmentShader;
			writeln("Texture set");
		} else {
			_fragShader = materialFragmentShader;
		}
		setProgram();
	}

	//To do: figure out how this will work w/ shaders.
	bool transparent;

	private:
	void setProgram() {
		_program = ShaderProgram.getProgram!DGEShaderProgram(ShaderGroup(vertShader, fragShader));
	}

	Texture _texture;

	VertexShader _vertShader;
	FragmentShader _fragShader;
	DGEShaderProgram _program;
}

/++
A standard texture

Currently, only PNG files are supported.
+/
class Texture {
	public:

	class TextureLoadError: Error {this(const(char)[] msg) {super(msg.idup);}}

	this(const(char)[] filename, const(char[])[] path = [getcwd()]) {
		SDL_Surface* surface = null;
		char[] mName = filename.dup ~ '\0';
		if((surface = IMG_Load(mName.ptr)) != null) {
			glGenTextures(1, &_id);
			glBindTexture(GL_TEXTURE_2D, _id);
			GLint mode = GL_RGB;
			if(surface.format.BytesPerPixel == 4) {
				mode = GL_RGBA;
				transparent = true;
			}
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexImage2D(GL_TEXTURE_2D, 0, mode, surface.w, surface.h, 0, mode, GL_UNSIGNED_BYTE, surface.pixels);
			SDL_FreeSurface(surface);
		} else {
			throw new TextureLoadError("Unable to open file \"" ~ filename ~ "\".");
		}
	}

	//To do: check GL_MAX_COMBINED_TEXTURE_UNITS.
	void bind(uint unit) {
		glActiveTexture(GL_TEXTURE0 + unit);
		glBindTexture(GL_TEXTURE_2D, _id);
	}

	void unbind(uint unit) {
		glActiveTexture(GL_TEXTURE0 + unit);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	@property int id() pure const {
		return _id;
	}

	~this() {
		glDeleteTextures(1, &_id);
	}

	bool transparent;

	private:
	GLuint _id;

}
