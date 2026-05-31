// Adapted from raylib examples
// Original license: zlib/libpng
// Source: https://github.com/raysan5/raylib/blob/master/examples/shaders/resources/shaders/glsl330/lighting_instancing.vs

#version 330

// Input vertex attributes
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;

in mat4 instanceTransform;

// Input uniform values
uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;

void main()
{
    // Send vertex attributes to fragment shader
    fragPosition = vec3(instanceTransform * vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vec4(1.0);

    // Calculate the normal matrix from the current instance's transformation matrix
    // This correctly extracts the orientation and cancels out non-uniform scaling issues
    mat3 normalMatrix = transpose(inverse(mat3(instanceTransform)));
    fragNormal = normalize(normalMatrix * vertexNormal);

    // Calculate final vertex position
    gl_Position = mvp * instanceTransform * vec4(vertexPosition, 1.0);
}
