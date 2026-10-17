#version 330

in vec2 fragTexCoord;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Remaining frames of damage
uniform float healFrames;
uniform float healDuration;

out vec4 outputColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    float tint = clamp(healFrames / healDuration, 0.0, 1.0);
    vec3 flashColor = mix(texelColor.rgb, vec3(0.33, 1.0, 0.33), tint);
    outputColor = vec4(flashColor, texelColor.a);
}
