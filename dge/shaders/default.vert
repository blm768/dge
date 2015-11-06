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

