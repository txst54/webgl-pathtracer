#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;

#define M 10
#define PI 3.14159265359

// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RIS_UTIL}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;
    vec2 randUV = gl_FragCoord.xy / uRes;

    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;
    Isect isect = intersect(ray, origin);
    vec3[M] samples;
    int count;
    random_samples(samples, count, isect, randUV);
    ReSTIR_Reservoir r = resample(samples, count, isect, randUV);
    vec3 lightDir = normalize(r.Y - isect.position);
    if (isect.isLight) {
        fragColor = vec4(ReSTIR_lightEmission, 1.0);
        return;
    }

    float cosTheta = max(dot(isect.normal, lightDir), 0.0);
    vec3 brdf = isect.albedo / pi;
    // vec3 finalColor = brdf * cosTheta;
    vec3 finalColor = (brdf * ReSTIR_lightEmission * cosTheta) * r.W_Y;

    fragColor = vec4(finalColor, 1.0);
}
