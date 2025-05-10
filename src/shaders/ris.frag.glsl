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

    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    for (int i = 0; i < 10; i++) {
        randUV += vec2(float(i) * 73.0);
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }

        if (isect.isLight) {
            fragColor = vec4(ReSTIR_lightEmission, 1.0);
            return;
        }

        vec3[M] samples;
        float[M] contrib_weights;
        random_samples(samples, contrib_weights, isect, randUV);
        ReSTIR_Reservoir r = resample(samples, contrib_weights, M, isect, randUV, 0, vec3(0.0));
        vec3 light_contribution = shade_reservoir(r, isect);
        float diffuse = max(0.0, dot(normalize(light - isect.position), isect.normal));

        colorMask *= isect.albedo;
        accumulatedColor += colorMask * light_contribution;
    }

    fragColor = vec4(accumulatedColor, 1.0);
}

void test_p() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    vec2 randUV = gl_FragCoord.xy / uRes;
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    Isect isect = intersect(ray, origin);
    vec3 lightPos = sampleSphere(light, lightSize, randUV);
    float visibility = shadow(isect.position + isect.normal * epsilon, lightPos - isect.position, sphereCenter, sphereRadius);
    fragColor = vec4(vec3(visibility * compute_p(isect.position, lightPos)), 1.0);
}

void test_sample_sphere() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    vec2 randUV = gl_FragCoord.xy / uRes;
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    Isect isect = intersect(ray, origin);
    vec3 lightPos = sampleSphere(light, lightSize, randUV);
    // should output gray
    fragColor = vec4(vec3(length(lightPos - light)/2.0), 1.0);
}