/++
Materials, textures, and fragment shaders
+/
module dge.graphics.material;

import std.file;
import std.stdio;
import std.string;
import std.typecons;

import derelict.opengl3.gl3;
import derelict.sdl2.image;
import derelict.sdl2.sdl;

import dge.config;
public import dge.graphics.shader.shader;
//import dge.util.object;

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
	@property GLfloat* ptr() {return values.ptr;}

	this(float r, float g, float b, float a = 1.0) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	union {
		struct {
			float r = 0.0, g = 0.0, b = 0.0, a = 1.0;
		}
		float[4] values;
	}

	alias a alpha;
}

enum BlendType {
	none, mix, add, multiply
}

struct MaterialShaderCache {
	alias Tuple!(string, MaterialShaderConfig) ShaderId;

	FragmentShader fragShader(const(char)[] shaderText, MaterialShaderConfig config) {
		auto id = tuple(shaderText.idup, config);
		auto shader = fs.get(id, null);
		if(!shader) {
			shader = new FragmentShader(shaderText, config);
			fs[id] = shader;
		}
		return shader;
	}

	private:
	VertexShader[ShaderId] vs;
	FragmentShader[ShaderId] fs;
}

/++
Standard material
+/
class Material {
	//mixin dup;

	this() {
		_shaders.vs = defaultVertexShader;
		_shaders.fs = cache.fragShader(defaultFragmentShader, _config);
		setProgram();
	}

	this(Color diffuse, Color specular = Color(1f, 1f, 1f), GLfloat shininess = 0.0) {
		this.diffuse = diffuse;
		this.specular = specular;
		this.shininess = shininess;
		this();
	}

	Color diffuse;
	Color specular;
	Color emission;
	GLfloat shininess = 0.0;
	BlendType blendType;

	/++
	Prepare to draw using this material

	program.use() must be called first.
	+/
	final void use() {
		//To do: support other blend equations?
		//To do: check if blending is enabled?
		glBlendEquation(GL_FUNC_ADD);
		switch(blendType) {
			case BlendType.mix:
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
				break;
			case BlendType.add:
				glBlendFuncSeparate(GL_ONE, GL_ONE, GL_ONE, GL_ZERO);
				break;
			case BlendType.multiply:
				glBlendFuncSeparate(GL_DST_COLOR, GL_ZERO, GL_ONE, GL_ZERO);
				break;
			default:
				//Do nothing.
		}
		_program.setUniform(program.matUniforms.diffuse, diffuse);
		_program.setUniform(program.matUniforms.emission, emission);
		_program.setUniform(program.matUniforms.specular, specular);
		_program.setUniform(program.matUniforms.shininess, shininess);
		if(texture) {
			texture.bind(0);
			_program.setUniform(program.matUniforms.useTexture, true);
			_program.setUniform(program.matUniforms.surface, 0);
		} else {
			_program.setUniform(program.matUniforms.useTexture, false);
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
		return _shaders.fs;
	}

	@property VertexShader vertShader() {
		return _shaders.vs;
	}

	@property GeometryShader geometryShader() {
		return _shaders.gs;
	}

	@property ShaderProgram program() {
		return _program;
	}

	@property Texture2D texture() {
		return _texture;
	}

	@property void texture(Texture2D tex) {
		_texture = tex;
		//Currently unused (switching is done in shader.)
		//To do: optimize for case when program doesn't change?
		/+if(tex) {
			_fragShader = textureFragmentShader;
		} else {
			_fragShader = materialFragmentShader;
		}
		setProgram();+/
	}

	//TODO: unify with default vert shader system.
	enum defaultFragmentShader = import("material.frag");

	//To do: how to handle multiple OpenGL contexts? Move this to Window?
	static MaterialShaderCache cache;

	private:
	void setProgram() {
		_program = ShaderProgram.getProgram(_shaders);
	}

	Texture2D _texture;

	ShaderGroup _shaders;
	MaterialShaderConfig _config;
	ShaderProgram _program;
}

enum ShadeType {
	none, vertex, fragment
}

struct MaterialShaderConfig {
	alias dge.config.maxLightsPerObject maxLightsPerObject;
	ShadeType shadeType = ShadeType.vertex;
}

/+
Base class for all textures
+/
abstract class Texture {
	//To do: check GL_MAX_COMBINED_TEXTURE_UNITS.
	/+
	Binds the texture to a texture unit
	+/
	void bind(uint unit) {
		glActiveTexture(GL_TEXTURE0 + unit);
		glBindTexture(type, _id);
	}

	/+
	Unbinds the texture from a texture unit
	+/
	void unbind(uint unit) {
		glActiveTexture(GL_TEXTURE0 + unit);
		glBindTexture(type, 0);
	}
	@property int id() pure const;
	@property GLenum type();

	//To do: better encapsulation
	protected:
	GLuint _id;
}

/++
A standard 2D texture

Currently, only PNG files are officially supported.
+/
class Texture2D: Texture {
	public:
	class TextureLoadError: Error {this(const(char)[] msg) {super(msg.idup);}}

	this(const(char)[] filename, const(char[])[] path = [getcwd()]) {
		SDL_Surface* surface = null;
		if((surface = IMG_Load(filename.toStringz)) != null) {
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

	override @property int id() pure const {
		return _id;
	}

	override @property GLenum type() {
		return GL_TEXTURE_2D;
	}

	~this() {
		glDeleteTextures(1, &_id);
	}

	bool transparent;
}
