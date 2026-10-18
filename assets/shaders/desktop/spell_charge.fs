#version 330

in vec2 fragTexCoord;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float currentFrame;
uniform vec3 skillColor;

out vec4 outputColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    float tint = -cos(currentFrame * 0.05) * 0.25 + 0.25;
    vec3 auraColor = mix(texelColor.rgb, skillColor, tint);
    outputColor = vec4(auraColor, texelColor.a);
}
