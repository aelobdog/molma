#version 330

in vec3 vertexPosition;
in vec3 vertexNormal;

uniform mat4 mvp;
uniform mat4 matModel;

out vec3 Normal;
out vec3 FragPos;

void main() {
    Normal = mat3(transpose(inverse(matModel))) * vertexNormal;
    FragPos = vec3(matModel * vec4(vertexPosition, 1.0));
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
