// begin_macro{RAND_LIB}
float random(vec3 scale, float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
}

float hashCoords(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hashValue(float p) {
    return fract(sin(p * 43758.5453) * 43758.5453);
}

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 uniformlyRandomDirection(float seed) {
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    float z = 1.0 - 2.0 * u;
    float r = sqrt(1.0 - z * z);
    float angle = 6.283185307179586 * v;
    return vec3(r * cos(angle), r * sin(angle), z);
}

vec3 uniformlyRandomVector(float seed) {
    return uniformlyRandomDirection(seed) * sqrt(random(vec3(36.7539, 50.3658, 306.2759), seed));
}

// https://rh8liuqy.github.io/Uniform_Disk.html
vec2 uniformlyRandomDisk(float seed, int radius) {
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed + 1.0);
    float x = float(radius) * sqrt(u) * cos(2.0 * PI * u);
    float y = float(radius) * sqrt(v) * sin(2.0 * PI * v);
    return vec2(x, y);
}
// end_macro

// begin_macro{CONSTANTS}
vec3 roomCubeMin = vec3(-3.0, -3.0, -3.0);
vec3 roomCubeMax = vec3(3.0, 3.0, 3.0);
vec3 wallCubeMax = vec3(10.0, 5.0, 1.0);
vec3 wallCubeMin = vec3(0.0, -10.0, -1.0);
vec3 sphereCenter = vec3(-3.0, -7.0, -3.0);
float sphereRadius = 3.0;
vec3 light = vec3(0.0, 2.0, 0.0);
float lightIntensity = 1.0;
float infinity = 10000.0;
float epsilon = 0.00001;
float lightSize = 0.5;
float maxBounces = 100.0;
vec3 ReSTIR_lightEmission = vec3(0.5); // Light intensity/color
#define PI 3.14159265359
#define LIGHTCOLOR vec3(16.86, 10.76, 8.2)*0.15
#define WHITECOLOR vec3(.7295, .7355, .729)*0.7
#define GREENCOLOR vec3(.117, .5125, .115)*0.7
#define REDCOLOR vec3(.711, .0555, .062)*0.7
#define INFINITY 10000.0;
// end_macro