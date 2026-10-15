#version 100
precision mediump float;

varying vec2 fragTexCoord;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Remaining frames of damage
uniform float damageFrames;
uniform float damageDuration;

void main() {
    vec4 texelColor = texture2D(texture0, fragTexCoord);
    float tint = clamp(damageFrames / damageDuration, 0.0, 1.0);
    vec3 flashColor = mix(texelColor.rgb, vec3(1.0), tint);
    gl_FragColor = vec4(flashColor, texelColor.a);
}
