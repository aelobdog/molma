#version 330

in vec3 Normal;
in vec3 FragPos;

uniform vec4 colDiffuse;

out vec4 finalColor;

const vec3 light_position = vec3(0.0, 0.0, 1000.0);
const vec3 light_color = vec3(1.0, 1.0, 1.0);
const float ambient_strength = 0.3;

void main() {
    vec4 ambient_light = vec4(ambient_strength * light_color, 1.0);

    vec3 Normal = normalize(Normal);
    vec3 light_direction = normalize(light_position - FragPos);
    float diff = max(dot(Normal, light_direction), 0.0);
    vec4 diffused_light = vec4(diff * light_color, 1.0);

    finalColor = (ambient_light + diffused_light) * colDiffuse;
}
