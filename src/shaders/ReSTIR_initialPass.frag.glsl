#version 300 es
precision highp float;
precision highp usampler2D;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;

// use_macro{SCENE_HEADERS}

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;

#define NB_BSDF 1
#define NB_LIGHT 1

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{TRIMESH_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{DIRECT_LIGHT_RIS}

ReSTIR_Reservoir resampleInitialRay(vec3 origin, vec3 ray, vec3 light) {

    float timeEntropy = hashValue(uTime);
    float seed = hashValue(hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0)));
    float total_dist = 0.0;
    Isect isect = intersect(ray, origin);
    ReSTIR_Reservoir r = initializeReservoir();
    return sample_lights_ris(r, isect, ray, NB_BSDF, NB_LIGHT, seed);
}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;
    ReSTIR_Reservoir r = resampleInitialRay(origin, ray, light);
    out_ReservoirData1 = packReservoir1(r);
    out_ReservoirData2 = packReservoir2(r);
}