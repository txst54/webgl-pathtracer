#version 300 es
in vec2 aVertPos;
uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
out vec3 initialRay;

void main() {
    vec2 percent = aVertPos.xy * 0.5 + 0.5;
    initialRay = normalize(mix(mix(uRay00, uRay01, percent.y), mix(uRay10, uRay11, percent.y), percent.x));
    gl_Position = vec4(aVertPos, 0.0, 1.0);
}