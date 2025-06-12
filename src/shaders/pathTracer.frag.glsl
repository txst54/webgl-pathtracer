#version 300 es
precision highp float;

uniform vec3 uEye;
uniform float uTime;
in vec3 initialRay;

uniform sampler2D uTexture;
uniform float uTextureWeight;
uniform vec2 uRes;

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}

out vec4 fragColor;

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);

    float russian_roulette_prob = 1.0;
    float total_dist = 0.0;
    for (int bounce = 0; bounce < 50; bounce++) {
        float roulette = random(vec3(36.7539, 50.3658, 306.2759), dot(gl_FragCoord.xy, vec2(12.9898, 78.233)) + uTime * 17.13 + float(bounce) * 91.71);
        if (roulette >= russian_roulette_prob) {
            break;
        }
        colorMask /= russian_roulette_prob;
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }
        if (bounce == 0 && isect.isLight) {
            accumulatedColor += lightIntensity;
        }

        vec3 directRay;
        float ndotr;
        float pdfA;
        float pdfB;
        float misWeight;
        vec3 lightRadianceMIS;
        vec3 bsdfRadianceMIS;
        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        vec3 brdf = isect.albedo / pi;

        // Uniform Light Sample
        directRay = uniformSphereDirection(isect.position, uTime + float(bounce) * 11.71 + ray.x + ray.y * 91.0, light, lightSize);
        pdfA = pdfUniformSphere(directRay, nextOrigin);
        pdfB = pdfCosineWeighted(directRay, isect.normal);
        if (pdfA > epsilon && pdfB > epsilon) {
            misWeight = balanceHeuristic(pdfA, 1.0, pdfB, 1.0);
            ndotr = dot(isect.normal, directRay);
            lightRadianceMIS = brdf * ndotr * lightIntensity * misWeight / pdfA;
        }

        // BSDF Sample
        directRay = cosineWeightedDirection(uTime + float(bounce) * 17.23 + ray.x + ray.y * 11.0 + 11.0, isect.normal);
        pdfA = pdfCosineWeighted(directRay, isect.normal);
        pdfB = pdfUniformSphere(directRay, nextOrigin);
        if (pdfA > epsilon && pdfB > epsilon) {
            misWeight = balanceHeuristic(pdfA, 1.0, pdfB, 1.0);
            ndotr = dot(isect.normal, directRay);
            bsdfRadianceMIS = brdf * ndotr * lightIntensity * misWeight / pdfA;
        }

        vec3 directLightContribution = lightRadianceMIS + bsdfRadianceMIS;
        accumulatedColor += directLightContribution * colorMask;

        vec3 nextRay = cosineWeightedDirection(uTime + float(bounce) * 71.51 + ray.x + ray.y * 61.0 + 23.0, isect.normal);
        float pdfBSDF = pdfCosineWeighted(nextRay, isect.normal);

        if (pdfBSDF <= epsilon) {
            break;
        }

        ndotr = dot(isect.normal, nextRay);
        colorMask *= brdf * abs(ndotr) / pdfBSDF;

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
    vec3 texColor = texture(uTexture, gl_FragCoord.xy / uRes).rgb;

    vec3 color = mix(calculateColor(uEye, initialRay, light).rgb, texColor, uTextureWeight);
    // vec3 color = calculateColor(uEye, initialRay, light);
    fragColor = vec4(color, 1.0);
}