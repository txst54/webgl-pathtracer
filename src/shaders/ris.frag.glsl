#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;

#define NUM_CANDIDATES 4
#define PI 3.14159265359

// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

float importance(vec3 normal, vec3 lightDir) {
    return max(dot(normal, lightDir), 0.0);
}

// Sample a point uniformly on a sphere
vec3 sampleSphere(vec3 center, float radius, vec2 u) {
    float z = 1.0 - 2.0 * u.x;
    float phi = 2.0 * PI * u.y;
    float r = sqrt(1.0 - z * z);
    return center + radius * vec3(r * cos(phi), r * sin(phi), z);
}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    // Intersect with scene
    Isect isect = intersect(ray, origin);
    if (isect.t < 0.0) {
        discard;
    }

    vec3 hitPoint = origin + isect.t * ray;
    vec3 chosenLightDir = vec3(0.0);
    float wSum = 0.0;
    float weight = 0.0;


    for (int i = 0; i < NUM_CANDIDATES; ++i) {
        float seed = float(i) + uTime;
        vec2 randUV = gl_FragCoord.xy / uRes;
        vec2 u = vec2(rand(randUV, seed), rand(randUV, seed + 1.0));

        vec3 samplePos = sampleSphere(light, lightSize, u);
        vec3 lightDir = normalize(samplePos - hitPoint);
        float lightDist = length(samplePos - hitPoint);

        Isect shadowIsect = intersect(lightDir, hitPoint + isect.normal * 0.001);
        bool occluded = shadowIsect.t < lightDist - 0.01 && shadowIsect.t > 0.0;
        if (occluded) continue;

        // Geometry term
        float cosTheta = max(dot(isect.normal, lightDir), 0.0);
        float cosThetaLight = max(dot(-lightDir, normalize(samplePos - light)), 0.0);

        // PDF for uniform sphere surface sample
        float area = 4.0 * PI * lightSize * lightSize;
        float pdf = (lightDist * lightDist) / (area * cosThetaLight + 1e-4); // avoid div by zero

        float w = cosTheta / pdf;
        wSum += w;

        if (rand(randUV, seed + 2.0) < w / wSum) {
            chosenLightDir = lightDir;
            weight = w;
        }
    }

    if (wSum == 0.0) {
        fragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    vec3 finalLighting = isect.albedo * max(dot(isect.normal, chosenLightDir), 0.0);
    fragColor = vec4(finalLighting, 1.0);
}
