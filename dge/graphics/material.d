/++
Materials, textures, and fragment shaders
+/
module dge.graphics.material;

import std.file;
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
		_fragShader = defaultFragmentShader;
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
	void use() {
		if(transparent) {
			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		}
	}

	/++
	Finish drawing using this material
	+/
	void finish() {
		glDisable(GL_BLEND);
	}

	Texture texture;
	@property FragmentShader fragShader() {
		return _fragShader;
	}
	
	@property VertexShader vertShader() {
		return _vertShader;
	}
	
	@property DGEShaderProgram program() {
		return _program;
	}

	//To do: figure out how this will work w/ shaders.
	bool transparent;

	private:
	void setProgram() {
		_program = ShaderProgram.getProgram!DGEShaderProgram(ShaderGroup(vertShader, fragShader));
	}
	
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
			glGenTextures(1, &texName);
			glBindTexture(GL_TEXTURE_2D, texName);
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
	void bind() {
		glBindTexture(GL_TEXTURE_2D, texName);
	}

	void unbind() {
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	~this() {
		glDeleteTextures(1, &texName);
	}

	bool transparent;

	private:
	GLuint texName;

}
