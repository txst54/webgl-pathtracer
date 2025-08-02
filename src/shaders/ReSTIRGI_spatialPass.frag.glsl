#version 300 es
precision highp float;
precision highp usampler2D;

uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;

// use_macro{SCENE_HEADERS}

out vec4 fragColor;
uniform sampler2D uDirectReservoirData1;
uniform sampler2D uDirectReservoirData2;
uniform sampler2D uIndirectReservoirData1;
uniform sampler2D uIndirectReservoirData2;
uniform sampler2D uDepthMap;

#define NB_BSDF 1
#define NB_LIGHT 1

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{TRIMESH_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RESTIRGI_RESERVOIR_LIB}
// use_macro{RIS_UTIL}
// use_macro{RESTIR_EQ_UTIL}
// use_macro{RESTIRDI_SPATIAL_RESAMPLING_LIB}
// use_macro{RESTIRGI_SPATIAL_RESAMPLING_LIB}
// use_macro{DIRECT_LIGHT_RIS}

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    vec3 directLight = vec3(0.0);

    float timeEntropy = hashValue(uTime);
    float seed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));
    vec2 uv = gl_FragCoord.xy / uRes;

    Isect isect = intersect(ray, origin); // x1
    if (isect.t == infinity) {
        return accumulatedColor;
    }
    vec3 nextOrigin = isect.position + isect.normal * epsilon;
    ReSTIR_Reservoir r = sample_lights_restir_spatial(ray, seed, isect, uDirectReservoirData1, uDirectReservoirData2);
    r.c = min(512.0, r.c);

    if (isect.isLight) {
        accumulatedColor += LIGHTCOLOR;
    }

    if (r.w_sum > 0.0) {
        vec3 brdf = isect.albedo / PI;
        vec3 sample_direction = normalize(r.Y - isect.position);
        float ndotr = dot(isect.normal, sample_direction);
        directLight = LIGHTCOLOR * brdf * abs(ndotr) * r.W_Y;
        accumulatedColor += colorMask * directLight;
    }

//    vec4 indirectReservoirData1 = texture(uIndirectReservoirData1, uv);
//    vec4 indirectReservoirData2 = texture(uIndirectReservoirData2, uv);
//    ReSTIRGI_Reservoir indirectReservoir = unpackReservoirGI(indirectReservoirData1, indirectReservoirData2);
    ReSTIRGI_Reservoir indirectReservoir = sampleLightsReSTIRGISpatial(ray, seed, isect, uIndirectReservoirData1, uIndirectReservoirData2);
    vec3 brdf = isect.albedo / PI;
    vec3 estimatedRadiance = evaluateRadianceAtCenterGI(indirectReservoir, isect, brdf);
    accumulatedColor += estimatedRadiance * indirectReservoir.W_Y;

    return accumulatedColor;
}

void main() {
    vec3 color = calculateColor(uEye, initialRay, light);
    color = pow( clamp(color,0.0,1.0), vec3(0.45) );
    fragColor = vec4(color, 1.0);
}