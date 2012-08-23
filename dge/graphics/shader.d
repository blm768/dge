module dge.graphics.shader;

import derelict.opengl3.gl3;

import std.conv;
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

	void setUniform(int uniform, float value) {
		if(uniform > -1) {
			use();
			glUniform1f(uniform, value);
		}
	}

	void setUniform(int uniform, int value) {
		if(uniform > -1) {
			use();
			glUniform1i(uniform, value);
		}
	}

	void setUniform(int uniform, bool value) {
		if(uniform > -1) {
			use();
			glUniform1i(uniform, cast(int)value);
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

	/++
	To do: take shaders rather than a ShaderGroup?
	+/
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

uniform mat4 model, view, projection;

in vec3 position;
in vec3 normal;
in vec2 texCoord;

out vec4 fragViewPosition;
out vec3 fragViewNormal;
out vec2 fragTexCoord;

void main() {
	fragViewPosition = view * model * vec4(position, 1.0);
	gl_Position = projection * fragViewPosition;
	fragViewNormal = vec3(view * model * vec4(normal, 0.0));
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

uniform mat4 view, projection;

uniform vec4 diffuse, specular, emission;
uniform float shininess;

uniform bool useTexture;
uniform sampler2D surface;

struct Light {
	vec3 position;
	vec4 diffuse;
	vec4 ambient;
	vec4 specular;
	vec3 direction;
	float spotCutoff;
	float quadraticAttenuation;
	float spotExponent;
};

uniform int numLights;
uniform Light[` ~ to!string(maxLightsPerObject) ~ `] lights;

in vec4 fragViewPosition;
in vec3 fragViewNormal;
in vec2 fragTexCoord;

//To do: figure out how to handle material's ambient color.
//To do: remove conditionals?
//To do:
vec3 lighting(const Light light, vec3 color) {
	//Is this a directional (sun) light?
	if(light.spotCutoff <= 0.0) {
		return light.diffuse.rgb * max(0.0, dot(fragViewNormal, (view * -vec4(light.direction, 0.0)).rgb ));
	} //else

	vec3 fragmentToLight = (view * vec4(light.position, 1.0) - fragViewPosition).xyz;
	float distSquared = dot(fragmentToLight, fragmentToLight);
	float attenuation = 1 / (light.quadraticAttenuation * distSquared);
	vec3 direction = normalize(fragmentToLight);

	//Is it a spotlight?
	if(light.spotCutoff <= 1.0) {
		//To do: cache dot product?
		float clampedCos = max(0.0, dot(-direction, (view * vec4(light.direction, 0.0)).xyz));
		if(clampedCos < light.spotCutoff) {
			attenuation = 0.0;
		} else {
			attenuation *= pow(clampedCos, light.spotExponent);
		}
	}

	vec3 lighting = light.diffuse.rgb * max(0.0, dot(fragViewNormal, direction)) * attenuation;

	//Calculate specular reflection.
	//To do: automatically cut out for objects/lights with no specular?
	vec3 specularLighting;

	//Is the light coming from the right side?
	if(dot(fragViewNormal, direction) > 0.0) {
		specularLighting = attenuation * vec3(light.specular) *
			pow(max(0.0, dot(reflect(-direction, fragViewNormal), -normalize(fragViewPosition.xyz))), shininess);
	} else {
		specularLighting = vec3(0.0, 0.0, 0.0);
	}

	return color * (lighting + light.ambient.xyz) + specular.rgb * specularLighting;
}

out vec4 fragColor;

void main() {
	vec4 color = diffuse;
	if(useTexture) {
		color *= texture(surface, fragTexCoord);
	}
	//To do: optimize conversions.
	fragColor = vec4(0, 0, 0, 1);
	for(uint i = 0; i < numLights; ++i) {
		fragColor.rgb += lighting(lights[i], color.rgb), diffuse.a;
	}
	fragColor.rgb += emission.rgb;
	fragColor.a = color.a;
}
`;

@property FragmentShader materialFragmentShader() {
	static FragmentShader shader;
	if(!shader) {
		shader = new FragmentShader(materialFragmentShaderText);
	}
	return shader;
}

struct MaterialUniformLocations {
	this(ShaderProgram program) {
		diffuse = program.getUniformLocation("diffuse");
		specular = program.getUniformLocation("specular");
		emission =  program.getUniformLocation("emission");
		shininess = program.getUniformLocation("shininess");

		numLights = program.getUniformLocation("numLights");

		foreach(size_t i, ref light; lights) {
			light = LightMemberLocations(program, "lights[" ~ to!string(i) ~ "]");
		}

		surface = program.getUniformLocation("surface");
		useTexture = program.getUniformLocation("useTexture");
	}

	int diffuse, specular, emission, shininess;
	int surface, useTexture;
	int numLights;
	LightMemberLocations[maxLightsPerObject] lights;
}

struct LightMemberLocations {
	this(ShaderProgram program, const(char)[] name) {
		position = program.getUniformLocation(name ~ ".position");
		diffuse = program.getUniformLocation(name ~ ".diffuse");
		ambient = program.getUniformLocation(name ~ ".ambient");
		specular = program.getUniformLocation(name ~ ".specular");

		direction = program.getUniformLocation(name ~ ".direction");
		spotCutoff = program.getUniformLocation(name ~ ".spotCutoff");
		quadraticAttenuation = program.getUniformLocation(name ~ ".quadraticAttenuation");
		spotExponent = program.getUniformLocation(name ~ ".spotExponent");
	}

	int position, diffuse, ambient, specular;
	int direction, spotCutoff, quadraticAttenuation, spotExponent;
}

struct VertexUniformLocations {
	this(ShaderProgram program) {
		model = program.getUniformLocation("model");
		view = program.getUniformLocation("view");
		projection = program.getUniformLocation("projection");
	}

	int model, view, projection;
}

struct VertexAttributeLocations {
	this(ShaderProgram program) {
		position = program.getAttribLocation("position");
		normal = program.getAttribLocation("normal");
		texCoord = program.getAttribLocation("texCoord");
	}
	int position, normal, texCoord;
}
