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
	void setUniform(int uniform, Vector3 vec) {
		if(uniform > -1) {
			//glProgramUniform3fv(programId, uniform, 1, &vec);
			use();
			glUniform3fv(uniform, 1, vec.ptr);
		}
	}

	void setUniform(int uniform, Vector3[] vec) {
		if(uniform > -1) {
			//glProgramUniform3fv(programId, uniform, vec.length, vec.ptr);
			use();
			glUniform3fv(uniform, cast(int)vec.length, cast(float*)vec.ptr);
		}
	}

	void setUniform(int uniform, Color c) {
		if(uniform > -1) {
			//glProgramUniform4fv(programId, uniform, 1, &c);
			use();
			glUniform4fv(uniform, 1, c.ptr);
		}
	}

	void setUniform(int uniform, Color[] c) {
		if(uniform > -1) {
			//glProgramUniform4fv(programId, uniform, c.length, c.ptr);
			use();
			glUniform4fv(uniform, cast(int)c.length, cast(float*)c.ptr);
		}
	}

	void setUniform(int uniform, TransformMatrix mat) {
		if(uniform > -1) {
			use();
			glUniformMatrix4fv(uniform, 1, cast(ubyte)false, mat.ptr);
		}
	}

	void setUniform(int uniform, int value) {
		if(uniform > -1) {
			use();
			glUniform1i(uniform, value);
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
		const(char)*[1] shaderStrings = [shader.ptr];
		const(int)[1] shaderLengths = [cast(int)shader.length];
		glShaderSource(shaderId, 1, shaderStrings.ptr, shaderLengths.ptr);
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

in vec3 position;
in vec3 normal;
in vec2 texCoord;

out vec3 fragNormal;
out vec2 fragTexCoord;

void main() {
	gl_Position = projection * modelview * vec4(position, 1.0);
	fragNormal = normal;
	fragTexCoord = texCoord;
}
`;

@property VertexShader defaultVertexShader() {
	static VertexShader shader;
	if(!shader) {
		shader = new VertexShader(defaultVertexShaderText);
	}
	return shader;
}

private string materialFragmentShaderText = `
#version 330

uniform vec4 diffuse;

in vec3 fragNormal;
in vec2 fragTexCoord;

out vec4 fragColor;

void main() {
	fragColor = diffuse * vec4(fragNormal, 1.0);
}
`;

@property FragmentShader materialFragmentShader() {
	static FragmentShader shader;
	if(!shader) {
		shader = new FragmentShader(materialFragmentShaderText);
	}
	return shader;
}

private string textureFragmentShaderText = `
#version 330

uniform sampler2D surface;

in vec3 fragNormal;
in vec2 fragTexCoord;

out vec4 fragColor;

void main() {
	fragColor = vec4(fragNormal, 1.0);
}
`;

@property FragmentShader textureFragmentShader() {
	static FragmentShader shader;
	if(!shader) {
		shader = new FragmentShader(textureFragmentShaderText);
	}
	return shader;
}

struct MaterialUniformLocations {
	this(ShaderProgram program) {
		diffuse = program.getUniformLocation("diffuse");
		ambient = program.getUniformLocation("ambient");
		specular = program.getUniformLocation("specular");
		emission =  program.getUniformLocation("emission");
		shininess = program.getUniformLocation("shininess");

		surface = program.getUniformLocation("surface");
	}

	int diffuse, ambient, specular, emission, shininess, surface;
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
