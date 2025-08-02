#version 300 es
precision highp float;
precision highp usampler2D;

uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
uniform vec2 uRes;
uniform float uTime;
uniform mat4 uViewMatPrev;
uniform mat4 uProjMatPrev;
in vec3 initialRay;

// use_macro{SCENE_HEADERS}

// previous state data
uniform sampler2D uDirectReservoirData1;
uniform sampler2D uDirectReservoirData2;
uniform sampler2D uIndirectReservoirData1;
uniform sampler2D uIndirectReservoirData2;
uniform sampler2D uDepthMap;
uniform sampler2D uNormalMap;

layout(location = 0) out vec4 out_DirectReservoirData1;
layout(location = 1) out vec4 out_DirectReservoirData2;
layout(location = 2) out vec4 out_IndirectReservoirData1;
layout(location = 3) out vec4 out_IndirectReservoirData2;
layout(location = 4) out vec4 out_DepthMap;
layout(location = 5) out vec4 out_NormalMap;

#define NB_BSDF 1
#define NB_LIGHT 1

// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{TRIMESH_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RESTIRGI_RESERVOIR_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}
// use_macro{RESTIR_EQ_UTIL}
// use_macro{RESTIR_UTIL}
// use_macro{DIRECT_LIGHT_RIS}
// use_macro{RESTIRDI_TEMPORAL_RESAMPLING_LIB}
// use_macro{RESTIRGI_TEMPORAL_RESAMPLING_LIB}

void main() {
    vec3 ray = normalize(initialRay);
    float timeEntropy = hashValue(uTime);
    float seed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));

    Isect isect = intersect(ray, uEye);
    ReSTIR_Reservoir r_direct = sampleLightsTemporalDI(ray, seed, isect,
        uDirectReservoirData1, uDirectReservoirData2, uDepthMap, uNormalMap);
    out_DirectReservoirData1 = packReservoir1(r_direct);
    out_DirectReservoirData2 = packReservoir2(r_direct);
    ReSTIRGI_Reservoir r_indirect = sampleLightsTemporalGI(ray, seed, isect,
        uIndirectReservoirData1, uIndirectReservoirData2, uDepthMap);
    out_DepthMap = vec4(isect.position, 0.0);
    out_NormalMap = vec4(isect.normal, 0.0);
    out_IndirectReservoirData1 = packReservoirGI1(r_indirect);
    out_IndirectReservoirData2 = packReservoirGI2(r_indirect);
}
