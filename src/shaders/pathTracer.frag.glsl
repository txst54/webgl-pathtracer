#version 300 es
precision highp float;
precision highp usampler2D;

uniform vec3 uEye;
uniform float uTime;

// use_macro{SCENE_HEADERS}


// uniform sampler2D uTexture;
uniform float uTextureWeight;
uniform vec2 uRes;
in vec3 initialRay;

#define EYE_PATH_LENGTH 4

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{TRIMESH_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}

out vec4 fragColor;

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);

    float russian_roulette_prob = 1.0;
    float total_dist = 0.0;
    for (int bounce = 0; bounce < EYE_PATH_LENGTH; bounce++) {
        float roulette = random(vec3(hashValue(36.7539*float(bounce)), hashValue(50.3658*float(bounce)), hashValue(306.2759*float(bounce))), dot(gl_FragCoord.xy, vec2(12.9898, 78.233)) + uTime * 17.13 + float(bounce) * 91.71);
        if (roulette >= russian_roulette_prob) {
            break;
        }
        colorMask /= russian_roulette_prob;
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }
        if (bounce == 0 && isect.isLight) {
            accumulatedColor += LIGHTCOLOR;
        } else if (isect.isLight) {
            return accumulatedColor;
        }

        vec3 directRay;
        float ndotr;
        float pdfA;
        float pdfB;
        float misWeight;
        vec3 lightRadianceMIS;
        vec3 bsdfRadianceMIS;
        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        vec3 brdf = isect.albedo / PI;

        colorMask *= isect.albedo;

        // *** MIS, METHOD 1
        // Uniform Light Sample
        directRay = uniformSphereDirection(isect.position, uTime + float(bounce) * 11.71 + ray.x + ray.y * 91.0, light, lightSize);
        pdfA = pdfUniformSphere(directRay, nextOrigin);
        pdfB = pdfCosineWeighted(directRay, isect.normal);
        if (pdfA > epsilon && pdfB > epsilon) {
            misWeight = balanceHeuristic(pdfA, 1.0, pdfB, 1.0);
            ndotr = clamp(dot(isect.normal, directRay), 0., 1.);
            lightRadianceMIS = brdf * ndotr * LIGHTCOLOR * misWeight / pdfA;
        }

        // BSDF Sample
        directRay = cosineWeightedDirection(uTime + float(bounce) * 17.23 + ray.x + ray.y * 11.0 + 11.0, isect.normal);
        pdfA = pdfCosineWeighted(directRay, isect.normal);
        pdfB = pdfUniformSphere(directRay, nextOrigin);
        if (pdfA > epsilon && pdfB > epsilon) {
            misWeight = balanceHeuristic(pdfA, 1.0, pdfB, 1.0);
            ndotr = clamp(dot(isect.normal, directRay), 0., 1.);
            bsdfRadianceMIS = brdf * ndotr * LIGHTCOLOR * misWeight / pdfA;
        }

        vec3 directLightContribution = lightRadianceMIS + bsdfRadianceMIS;
        accumulatedColor += directLightContribution * colorMask;

        // *** NO MIS, METHOD 2
        directRay = uniformSphereDirection(isect.position, uTime + float(bounce) * 11.71 + ray.x + ray.y * 91.0, light, lightSize);
        if (pdfUniformSphere(directRay, nextOrigin) > epsilon) {
            vec3 normalizedDirectRay = normalize(directRay);
            float cos_a_max = sqrt(1. - clamp(lightSize * lightSize / dot(light-isect.position, light-isect.position), 0., 1.));
            float weight = 2. * (1. - cos_a_max);

            // accumulatedColor += (colorMask * LIGHTCOLOR) * (weight * clamp(dot( normalizedDirectRay, isect.normal ), 0., 1.));
        }

        // ** Next Ray Calculation

        vec3 nextRay = cosineWeightedDirection(uTime + float(bounce) * 71.51 + ray.x + ray.y * 61.0 + 23.0, isect.normal);
        float pdfBSDF = pdfCosineWeighted(nextRay, isect.normal);

        if (pdfBSDF <= epsilon) {
            break;
        }

        ndotr = dot(isect.normal, nextRay);
        // colorMask *= brdf * abs(ndotr) / pdfBSDF;

        // Russian Roulette Termination
        float throughput_max_element = max(max(colorMask.x, colorMask.y), colorMask.z);

        russian_roulette_prob = min(throughput_max_element, 1.0);

        origin = nextOrigin;
        ray = nextRay;
    }

    return accumulatedColor;
}

void main() {

    // Avoid using 'texture' as a variable name
    // vec3 texColor = texture(uTexture, gl_FragCoord.xy / uRes).rgb;

    // vec3 color = mix(calculateColor(uEye, initialRay, light).rgb, texColor, uTextureWeight);
    vec3 color = calculateColor(uEye, initialRay, light);
    color = pow( clamp(color,0.0,1.0), vec3(0.45) );
    fragColor = vec4(color, 1.0);
}