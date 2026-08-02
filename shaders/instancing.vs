// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;

in mat4 instanceTransform;

uniform mat4 mvp;

out vec2 fragTexCoord;

void main()
{
    fragTexCoord = vertexTexCoord;
    gl_Position = mvp * instanceTransform * vec4(vertexPosition, 1.0);
}
