#version 300 es
precision highp float;

uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
layout(location = 2) out vec4 fragColor;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;

#define NB_BSDF 5
#define NB_LIGHT 5

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{DIRECT_LIGHT_RESTIR}
// use_macro{DIRECT_LIGHT_RIS}

void main() {
    vec2 coord = (gl_FragCoord.xy + 0.5) / uRes;
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    float timeEntropy = hashValue(uTime);
    float seed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));

    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    vec3 directLight = vec3(0.0);
    for (int bounce = 0; bounce < 3; bounce++) {
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }

        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        float baseSeed = hashValue(float(bounce) * 51.19 + 79.0 + seed);

        ReSTIR_Reservoir r;
        // can only do ReSTIR on initial bounce, everything else we will do via RIS
        if(bounce == 0) {
            r = sample_lights_restir_spatial(ray, baseSeed, isect);
            out_ReservoirData1 = packReservoir1(r);
            out_ReservoirData2 = packReservoir2(r);
            r.c = min(512.0, r.c);
        } else {
            r = sample_lights_ris(isect, ray, NB_BSDF, NB_LIGHT, baseSeed);
        }

        if (isect.isLight && bounce == 0) {
            accumulatedColor += lightIntensity;
        }

        if (r.w_sum > 0.0) {
            vec3 brdf = isect.albedo / pi;
            vec3 sample_direction = normalize(r.Y - isect.position);
            float ndotr = dot(isect.normal, sample_direction);
            directLight = lightIntensity * brdf * abs(ndotr) * r.W_Y;
            accumulatedColor += colorMask * directLight;
        }

        vec3 nextRay = cosineWeightedDirection(baseSeed, isect.normal);
        float pdfCosine = pdfCosineWeighted(nextRay, isect.normal);
        float ndotr = dot(isect.normal, nextRay);
        if (ndotr <= 0.0 || pdfCosine <= epsilon) break;
        vec3 brdf = isect.albedo / pi;
        colorMask *= brdf * ndotr / pdfCosine;

        origin = nextOrigin;
        ray = nextRay;
    }
    fragColor = vec4(accumulatedColor, 1.0);
}