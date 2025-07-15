// begin_macro{DIRECT_LIGHT_RIS}
ReSTIR_Reservoir sample_lights_ris(ReSTIR_Reservoir r_in, Isect isect, vec3 ray, int nb_bsdf, int nb_light, float seed) {
    ReSTIR_Reservoir r = r_in;
    int M = nb_bsdf + nb_light;
    vec3 nextOrigin = isect.position + isect.normal * epsilon;
    float baseSeed = hashValue(float(M) * 23.0 + 79.0) + seed;

    for (int candidate = 0; candidate < M; candidate++) {
        vec3 next_ray = ray;
        vec3 light_sample;
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
            light_sample = next_isect.position;
        } else {
            light_sample = uniformSpherePos(isect.position, cBaseSeed + 23.57, light, lightSize);
            next_ray = normalize(light_sample - isect.position);
        }

        float pdfCosine = pdfCosineWeighted(next_ray, isect.normal);
        float pdfLight = pdfUniformSphere(next_ray, isect.position);

        float pdfA = usedCosine? pdfCosine : pdfLight;
        float pdfB = usedCosine? pdfLight : pdfCosine;
        float nbPdfA = float(usedCosine ? NB_BSDF : NB_LIGHT);
        float nbPdfB = float(usedCosine ? NB_LIGHT : NB_BSDF);
        float misWeight = balanceHeuristic(pdfA, nbPdfA, pdfB, nbPdfB);

        float pdfX = max(epsilon, usedCosine ? pdfCosine : pdfLight);

        vec3 brdf = isect.albedo / PI;
        float ndotr = dot(isect.normal, next_ray);
        float pHat = evaluate_target_function_at_center(light_sample, isect, brdf);

        if (ndotr <= epsilon || pHat <= epsilon || pdfX <= epsilon) {
            continue;
        }

        reservoirWeight = misWeight * pHat / pdfX;
        r.w_sum += reservoirWeight;
        float reservoirStrategy = random(vec3(1.0), cBaseSeed + 7.23);
        if (reservoirStrategy < reservoirWeight / r.w_sum) {
            r.p_hat = pHat;
            r.Y = light_sample;
            r.t = isect.t;
        }
    }

    if (r.w_sum > 0.0) {
        r.W_Y = r.w_sum / max(r.p_hat, epsilon);
    }
    r.c = 1.0;
    return r;
}
//end_macro