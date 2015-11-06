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

uniform uint numLights;
uniform Light[maxLightsPerObject] lights;

in vec4 fragViewPosition;
in vec3 fragViewNormal;
in vec2 fragTexCoord;

//To do: remove conditionals?
vec3 lighting(const Light light, vec3 color) {
	//Is this a directional (sun) light?
	if(light.spotCutoff <= 0.0) {
		return light.diffuse.rgb * max(0.0, dot(fragViewNormal, (view * -vec4(light.direction, 0.0)).rgb ));
	}

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
	#if defined(lighting_none)
		fragColor = color;
	#else
		fragColor = vec4(0, 0, 0, color.a);
		//To do: eliminate warning?
		for(uint i = 0u; i < numLights; ++i) {
			fragColor.rgb += lighting(lights[i], color.rgb), diffuse.a;
		}
		fragColor.rgb += emission.rgb;
	#endif
}
