module dge.graphics.shader;

import derelict.opengl3.gl3;

import std.stdio;
import std.string;

import dge.config;
public import dge.graphics.material;
import dge.math;

/++
Represents a shader program

To do: error checking?
+/
class ShaderProgram {
	this(VertexShader vs, FragmentShader fs) {
		shaders.vs = vs;
		shaders.fs = fs;
		prepareProgram();
	}

	this(ShaderGroup group) {
		shaders = group;
		prepareProgram();
	}

	/++
	Bind the shader as the active shader.
	+/
	void use() {
		glUseProgram(programId);
	}

	/++
	To do:
	Use glProgramUniform() if possible.
	Remove the use() call? (could break some code and eventually won't be needed)
	+/
	void setUniform(Vector3 vec, int uniform) {
		if(uniform > -1) {
			//glProgramUniform3fv(programId, uniform, 1, &vec);
			use();
			glUniform3fv(uniform, 1, vec.ptr);
		}
	}

	void setUniform(Vector3[] vec, int uniform) {
		if(uniform > -1) {
			//glProgramUniform3fv(programId, uniform, vec.length, vec.ptr);
			use();
			glUniform3fv(uniform, cast(int)vec.length, cast(float*)vec.ptr);
		}
	}

	void setUniform(Color c, int uniform) {
		if(uniform > -1) {
			//glProgramUniform4fv(programId, uniform, 1, &c);
			use();
			glUniform3fv(uniform, 1, c.ptr);
		}
	}

	void setUniform(Color[] c, int uniform) {
		if(uniform > -1) {
			//glProgramUniform4fv(programId, uniform, c.length, c.ptr);
			use();
			glUniform3fv(uniform, cast(int)c.length, cast(float*)c.ptr);
		}
	}

	void setUniform(TransformMatrix mat, int uniform) {
		if(uniform > -1) {
			use();
			glUniformMatrix4fv(uniform, 1, cast(ubyte)false, mat.ptr);
		}
	}

	void finish() {
		glUseProgram(0);
	}

	int getUniformLocation(const(char)[] name) {
		//To do: remove?
		use();
		return glGetUniformLocation(programId, toStringz(name));
	}

	int getAttribLocation(const(char)[] name) {
		//To do: remove?
		use();
		return glGetAttribLocation(programId, toStringz(name));
	}

	~this() {
		glDetachShader(programId, shaders.vs.shaderId);
		glDetachShader(programId, shaders.fs.shaderId);
		glDeleteProgram(programId);
	}

	static ShadeType getProgram(ShadeType = DGEShaderProgram)(ShaderGroup group) {
		auto program = programs.get(group, null);
		if(!program) {
			program = new ShadeType(group);
		}
		return cast(ShadeType)program;
	}

	private:
	void prepareProgram() {
		programId = glCreateProgram();
		glAttachShader(programId, shaders.vs.shaderId);
		glAttachShader(programId, shaders.fs.shaderId);

		glLinkProgram(programId);
		int linked;
		glGetProgramiv(programId, GL_LINK_STATUS, &linked);
		if(!linked) {
			char[] msg;
			int len;
			glGetProgramiv(programId, GL_INFO_LOG_LENGTH, &len);
			msg.length = cast(size_t)len;
			glGetProgramInfoLog(programId, len, &len, msg.ptr);
			throw new Error("Unable to link shader program: " ~ msg.idup);
		}

		programs[shaders] = this;
	}

	static ShaderProgram[ShaderGroup] programs;

	ShaderGroup shaders;
	uint programId;

	static AssociativeArray!(ShaderGroup, ShaderProgram) hack;
}

/++
A shader program that includes DGE information
+/
class DGEShaderProgram: ShaderProgram {
	this(VertexShader vs, FragmentShader fs) {
		super(vs, fs);
		calculateData();
	}

	this(ShaderGroup group) {
		super(group);
		calculateData();
	}

	@property MaterialUniformLocations matUniforms() {
		return _matUniforms;
	}

	@property VertexUniformLocations vUniforms() {
		return _vUniforms;
	}

	@property VertexAttributeLocations vAttributes() {
		return _vAttributes;
	}

	private:
	void calculateData() {
		_matUniforms = MaterialUniformLocations(this);
		_vUniforms = VertexUniformLocations(this);
		_vAttributes = VertexAttributeLocations(this);
	}

	MaterialUniformLocations _matUniforms;
	VertexUniformLocations _vUniforms;
	VertexAttributeLocations _vAttributes;
}

struct ShaderGroup {
	VertexShader vs;
	FragmentShader fs;
}

class Shader {
	this(const(char)[] shader, GLenum type) {
		shaderId = glCreateShader(type);
		glShaderSource(shaderId, 1, [shader.ptr].ptr, [cast(int)shader.length].ptr);
		glCompileShader(shaderId);
		int compiled;
		glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compiled);
		if(!compiled) {
			//The shader didn't compile.
			char[] msg;
			int len;
			glGetShaderiv(shaderId, GL_INFO_LOG_LENGTH, &len);
			msg.length = cast(size_t)len;
			glGetShaderInfoLog(shaderId, len, &len, msg.ptr);
			throw new Error("Unable to compile shader: " ~ msg.idup);
		}
	}

	~this() {
		glDeleteShader(shaderId);
	}

	private:
	uint shaderId;
}

/++
A vertex shader
+/
class VertexShader: Shader {
	this(const(char)[] shader) {
		super(shader, GL_VERTEX_SHADER);
	}
}

class FragmentShader: Shader {
	this(const(char)[] shader) {
		super(shader, GL_FRAGMENT_SHADER);
	}
}

private string defaultVertexShaderText = `
#version 330

uniform mat4 modelview;
uniform mat4 projection;

in vec4 position;
in vec4 normal;
in vec4 texCoord;

void main() {
	gl_Position = projection * modelview * position;
}
`;

@property VertexShader defaultVertexShader() {
	static VertexShader shader;
	if(!shader) {
		shader = new VertexShader(defaultVertexShaderText);
	}
	return shader;
}

private string defaultFragmentShaderText = `
#version 330 compatibility

//out vec4 fragColor;

void main() {
	gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
`;

@property FragmentShader defaultFragmentShader() {
	static FragmentShader shader;
	if(!shader) {
		shader = new FragmentShader(defaultFragmentShaderText);
	}
	return shader;
}

struct MaterialUniformLocations {
	this(ShaderProgram program) {
		diffuse = program.getUniformLocation("diffuseColor");
		ambient = program.getUniformLocation("ambientColor");
		specular = program.getUniformLocation("specularColor");
		emission =  program.getUniformLocation("emissionColor");
		shininess = program.getUniformLocation("shininess");
	}

	int diffuse, ambient, specular, emission, shininess;
}

struct VertexUniformLocations {
	this(ShaderProgram program) {
		modelview = program.getUniformLocation("modelview");
		projection = program.getUniformLocation("projection");
	}

	int modelview, projection;
}

struct VertexAttributeLocations {
	this(ShaderProgram program) {
		position = program.getAttribLocation("position");
		normal = program.getAttribLocation("normal");
		texCoord = program.getAttribLocation("texCoord");
	}
	int position, normal, texCoord;
}
