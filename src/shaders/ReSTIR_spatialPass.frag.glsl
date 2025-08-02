#version 300 es
precision highp float;
precision highp usampler2D;

uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;

// use_macro{SCENE_HEADERS}

out vec4 fragColor;
uniform sampler2D uReservoirData1;
uniform sampler2D uReservoirData2;

#define NB_BSDF 1
#define NB_LIGHT 1

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{TRIMESH_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RESTIRGI_RESERVOIR_LIB}
// use_macro{RESTIRDI_SPATIAL_RESAMPLING_LIB}
// use_macro{DIRECT_LIGHT_RIS}

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    vec3 directLight = vec3(0.0);

    float timeEntropy = hashValue(uTime);
    float seed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));
    vec2 uv = gl_FragCoord.xy / uRes;
    ReSTIR_Reservoir r = initializeReservoir();
    float russian_roulette_prob = 1.0;
    for (int bounce = 0; bounce < 1; bounce++) {
        float roulette = random(vec3(hashValue(36.7539*float(bounce)), hashValue(50.3658*float(bounce)), hashValue(306.2759*float(bounce))), dot(gl_FragCoord.xy, vec2(12.9898, 78.233)) + uTime * 17.13 + float(bounce) * 91.71);
        if (roulette >= russian_roulette_prob) {
            break;
        }
        colorMask /= russian_roulette_prob;

        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }

        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        float baseSeed = hashValue(float(bounce) * 51.19 + 79.0) + seed;

        if(bounce == 0) {
            r = sample_lights_restir_spatial(ray, baseSeed, isect, uReservoirData1, uReservoirData2);
            // return vec4(vec3(r.c), 1.0);
            r.c = min(512.0, r.c);
        } else {
            r = initializeReservoir();
            r = sample_lights_ris(r, isect, ray, NB_BSDF, NB_LIGHT, baseSeed);
        }

        if (isect.isLight && bounce == 0) {
            accumulatedColor += LIGHTCOLOR;
        }

        if (r.w_sum > 0.0) {
            vec3 brdf = isect.albedo / PI;
            vec3 sample_direction = normalize(r.Y - isect.position);
            float ndotr = dot(isect.normal, sample_direction);
            directLight = LIGHTCOLOR * brdf * abs(ndotr) * r.W_Y;
            accumulatedColor += colorMask * directLight;
        }

        vec3 nextRay = cosineWeightedDirection(baseSeed, isect.normal);
        float pdfCosine = pdfCosineWeighted(nextRay, isect.normal);
        float ndotr = dot(isect.normal, nextRay);
        if (ndotr <= 0.0 || pdfCosine <= epsilon) break;
        vec3 brdf = isect.albedo / PI;
        colorMask *= brdf * ndotr / pdfCosine;

        // Russian Roulette Termination
        float throughput_max_element = max(max(colorMask.x, colorMask.y), colorMask.z);
        russian_roulette_prob = min(throughput_max_element, 1.0);
        origin = nextOrigin;
        ray = nextRay;
    }

    return accumulatedColor;
}

void main() {
    vec3 color = calculateColor(uEye, initialRay, light);
    color = pow( clamp(color,0.0,1.0), vec3(0.45) );
    fragColor = vec4(color, 1.0);
}