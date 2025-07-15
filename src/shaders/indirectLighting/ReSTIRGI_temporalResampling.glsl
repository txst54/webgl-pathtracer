// begin_macro{RESTIRGI_TEMPORAL_RESAMPLING_LIB}
ReSTIRGI_Reservoir getTemporalNeighborGI(Isect isectCenter,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap) {
    ReSTIRGI_Reservoir temporalNeighbor = getTemporalNeighborFromTextureGI(isectCenter, reservoirData1, reservoirData2, depthMap);
    ReSTIRGI_Reservoir defaultReservoir = initializeReservoirGI();
    if (temporalNeighbor.W_Y < epsilon) {
        return defaultReservoir;
    }
    vec3 rayDir = normalize(temporalNeighbor.Y - isectCenter.position);
    float rayDist = length(temporalNeighbor.Y - isectCenter.position);
    vec3 rayOrigin = isectCenter.position + isectCenter.normal * epsilon;
    Isect visibilityCheck = intersect(rayDir, rayOrigin);

    // if we dont hit the sample spot, there is occlusion
    if (abs(length(visibilityCheck.position - temporalNeighbor.Y) - rayDist) > 0.1 * rayDist) {
        return defaultReservoir;
    }
    return temporalNeighbor;
}

ReSTIRGI_Reservoir samplePath(vec3 ray, float seed, Isect isectCenter) {
    ReSTIRGI_Reservoir r = initializeReservoirGI();
    ReSTIRGI_Reservoir defaultReservoir = initializeReservoirGI();
    ReSTIR_Reservoir r_RIS = initializeReservoir();
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    vec3 directLight = vec3(0.0);
    vec3 origin = uEye;

    float timeEntropy = hashValue(uTime);
    vec2 uv = gl_FragCoord.xy / uRes;
    float russian_roulette_prob = 1.0;
    float pdfX = 0.0;
    for (int bounce = 0; bounce < 16; bounce++) {
        float roulette = random(vec3(hashValue(36.7539*float(bounce)), hashValue(50.3658*float(bounce)), hashValue(306.2759*float(bounce))), dot(gl_FragCoord.xy, vec2(12.9898, 78.233)) + uTime * 17.13 + float(bounce) * 91.71);
        if (roulette >= russian_roulette_prob) {
            break;
        }
        colorMask /= russian_roulette_prob;

        Isect isect;
        if (bounce == 0) isect = isectCenter;
        else isect = intersect(ray, origin);

        if (isect.t == infinity) {
            break;
        }

        if (bounce == 1) {
            r.Y = isect.position;
        }

        vec3 nextOrigin = isect.position + isect.normal * epsilon;
        float baseSeed = hashValue(float(bounce) * 51.19 + 79.0) + seed;

        if (bounce > 0) {
            // simulate direct lighting for our path (bounce > 0)
            r_RIS = initializeReservoir();
            r_RIS = sample_lights_ris(r_RIS, isect, ray, NB_BSDF, NB_LIGHT, baseSeed);

            if (r_RIS.w_sum > 0.0) {
                vec3 brdf = isect.albedo / PI;
                vec3 sample_direction = normalize(r_RIS.Y - isect.position);
                float ndotr = dot(isect.normal, sample_direction);
                directLight = LIGHTCOLOR * brdf * abs(ndotr) * r_RIS.W_Y;
                accumulatedColor += colorMask * directLight;
            }
        }
        vec3 nextRay = cosineWeightedDirection(baseSeed, isect.normal);
        float pdfCosine = pdfCosineWeighted(nextRay, isect.normal);
        if (bounce == 0) {
            pdfX = pdfCosine;
        }
        float ndotr = dot(isect.normal, nextRay);
        if (ndotr <= 0.0 || pdfCosine <= epsilon) break;
        vec3 brdf = isect.albedo / PI;
        if (bounce > 0) {
            colorMask *= brdf * ndotr / pdfCosine;
        }

        // Russian Roulette Termination
        float throughput_max_element = max(max(colorMask.x, colorMask.y), colorMask.z);

        russian_roulette_prob = min(throughput_max_element, 1.0);
        origin = nextOrigin;
        ray = nextRay;
    }
    r.L = accumulatedColor;
    if (pdfX < epsilon || dot(r.L, vec3(1.0, 1.0, 1.0)) < epsilon) {
        return defaultReservoir;
    }
    // r.t = isectCenter.t;
    r.c = 1.0;
    r.W_Y = 1.0; // w_sum = p_hat/pdfX, W_Y = w_sum / p_hat = p_hat/pdfX/p_hat = pdfX
    return r;
}

ReSTIRGI_Reservoir sampleLightsTemporalGI(vec3 ray, float seed, Isect isectCenter,
    sampler2D reservoirData1, sampler2D reservoirData2, sampler2D depthMap) {
    ReSTIRGI_Reservoir r_current = samplePath(ray, seed, isectCenter);
    ReSTIRGI_Reservoir r_prev = getTemporalNeighborGI(isectCenter, reservoirData1, reservoirData2, depthMap);

    if (r_prev.W_Y < epsilon) {
        return r_current;
    }

    ReSTIRGI_Reservoir r_out = resample_temporalGI(r_current, r_prev, isectCenter, seed);
    return r_out;
}
// end_macro