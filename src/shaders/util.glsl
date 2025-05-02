// begin_macro{RAND_LIB}
float random(vec3 scale, float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
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
// end_macro

// begin_macro{CONSTANTS}
vec3 roomCubeMin = vec3(-10.0, -10.0, -10.0);
vec3 roomCubeMax = vec3(10.0, 10.0, 10.0);
vec3 sphereCenter = vec3(0.0, 0.0, 0.0);
float sphereRadius = 1.0;
vec3 light = vec3(0.0, 5.0, 0.0);
float lightIntensity = 1.0;
float infinity = 10000.0;
float epsilon = 0.0001;
float lightSize = 1.0;
float pi = 3.14159265359;
float maxBounces = 100.0;
vec3 ReSTIR_lightEmission = vec3(5.0); // Light intensity/color
// end_macro