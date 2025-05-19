#version 300 es
precision highp float;

uniform vec3 uEye;
uniform float uTime;
in vec3 initialRay;

uniform sampler2D uTexture;
uniform float uTextureWeight;
uniform vec2 uRes;

#define NB_BSDF 5
#define NB_LIGHT 5

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}

out vec4 fragColor;

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    vec3 directLight = vec3(0.0);

    float timeEntropy = hashValue(uTime);
    float rouletteSeed = hashCoords(gl_FragCoord.xy + timeEntropy * vec2(1.0, -1.0));
    float roulette = random(vec3(1.0), rouletteSeed);
    int num_iters = int(ceil(log(1.0 - roulette) / log(0.9)));
    float total_dist = 0.0;

    for (int bounce = 0; bounce < 10; bounce++) {
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }

        ReSTIR_Reservoir r = initializeReservoir();
        int M = NB_BSDF + NB_LIGHT;
        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        float baseSeed = hashValue(float(bounce) * 51.19 * float(M) * 23.0 + 79.0) + rouletteSeed;

        for (int candidate = 0; candidate < M; candidate++) {
            vec3 next_ray = ray;
            float cBaseSeed = baseSeed * 17.51 + hashValue(float(candidate)) * 119.73;

            float reservoirWeight = 0.0;
            bool usedCosine = candidate < NB_BSDF;
            if (usedCosine) {
                next_ray = cosineWeightedDirection(cBaseSeed + 11.37, isect.normal);
                // is bsdf so need to check if ray ends at light
                Isect next_isect = intersect(next_ray, nextOrigin);
                if (!next_isect.isLight) {
                    continue;
                }
            } else {
                next_ray = uniformSphereDirection(isect.position, cBaseSeed + 23.57, light, lightSize);
            }

            float pdfCosine = pdfCosineWeighted(next_ray, isect.normal);
            float pdfLight = pdfUniformSphere(next_ray, isect.position);

            float pdfA = usedCosine? pdfCosine : pdfLight;
            float pdfB = usedCosine? pdfLight : pdfCosine;
            float nbPdfA = float(usedCosine ? NB_BSDF : NB_LIGHT);
            float nbPdfB = float(usedCosine ? NB_LIGHT : NB_BSDF);
            float misWeight = balanceHeuristic(pdfA, nbPdfA, pdfB, nbPdfB);

            float pdfX = max(epsilon, usedCosine ? pdfCosine : pdfLight);

            vec3 brdf = isect.albedo / pi;
            float ndotr = dot(isect.normal, next_ray);
            vec3 contribution = brdf * abs(ndotr);
            float pHat = dot(contribution, vec3(0.3086, 0.6094, 0.0820));

            if (ndotr <= epsilon || pHat <= epsilon || pdfX <= epsilon) {
                continue;
            }

            reservoirWeight = misWeight * pHat / pdfX;
            r.w_sum += reservoirWeight;
            float reservoirStrategy = random(vec3(1.0), cBaseSeed + 7.23);
            if (reservoirStrategy < reservoirWeight / r.w_sum) {
                r.p_hat = pHat;
                r.Y = next_ray;
            }
        }

        if (isect.isLight && bounce == 0) {
            accumulatedColor += lightIntensity;
        }

        if (r.w_sum > 0.0) {
            vec3 brdf = isect.albedo / pi;
            float ndotr = dot(isect.normal, r.Y);
            r.W_Y = r.w_sum / max(r.p_hat, epsilon);
            directLight = lightIntensity * brdf * abs(ndotr) * r.W_Y;
            accumulatedColor += colorMask * directLight;
        }

//        if (bounce >= num_iters) {
//            break;
//        }

        vec3 nextRay = cosineWeightedDirection(baseSeed, isect.normal);
        float pdfCosine = pdfCosineWeighted(nextRay, isect.normal);
        float ndotr = dot(isect.normal, nextRay);
        if (ndotr <= 0.0 || pdfCosine <= epsilon) break;
        vec3 brdf = isect.albedo / pi;
        colorMask *= brdf * ndotr / pdfCosine;

        origin = nextOrigin;
        ray = nextRay;
    }

    return accumulatedColor;
}

void main() {

    // Avoid using 'texture' as a variable name
    vec3 texColor = texture(uTexture, gl_FragCoord.xy / uRes).rgb;

    vec3 color = calculateColor(uEye, initialRay, light);
    // vec3 color = mix(calculateColor(uEye, initialRay, light), texColor, uTextureWeight);
    fragColor = vec4(color, 1.0);
}