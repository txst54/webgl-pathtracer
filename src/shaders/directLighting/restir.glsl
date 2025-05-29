//begin_macro{DIRECT_LIGHT_RESTIR}

ReSTIR_Reservoir sample_lights_restir_spatial(vec3 ray, float seed, Isect isectCenter) {
    ReSTIR_Reservoir rCenter = unpackReservoir(texture(uReservoirData1, gl_FragCoord.xy), texture(uReservoirData2, gl_FragCoord.xy));
    ReSTIR_Reservoir r = initializeReservoir();
    int MAX_NEIGHBORS = 16;
    ReSTIR_Reservoir candidates[17];
    candidates[0] = rCenter;
    int count = 1;
    float sum_p_hat = rCenter.p_hat;
    vec3 centerBrdf = isectCenter.albedo / pi;
    for (int candidateIndex = 0; candidateIndex < MAX_NEIGHBORS; candidateIndex++) {
        vec2 dxy = uniformlyRandomDisk(hashValue(seed + float(candidateIndex)), 16);
        vec2 neighbor = gl_FragCoord.xy + vec2(int(dxy.x), int(dxy.y));
        if (neighbor.x < 0.0 || neighbor.y < 0.0 ||
        neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;

        vec2 uv = (neighbor) / uRes;

        vec4 uCandidate1 = texture(uReservoirData1, uv);
        vec4 uCandidate2 = texture(uReservoirData2, uv);

        candidates[count] = unpackReservoir(uCandidate1, uCandidate2);

        // geometry selection heuristic
        vec2 percent = (neighbor / uRes);
        vec3 candidateRay = normalize(mix(mix(uRay00, uRay01, percent.y), mix(uRay10, uRay11, percent.y), percent.x));
        Isect candidateIsect = intersect(candidateRay, uEye);
        if (abs(candidateIsect.t - isectCenter.t) > 0.5 * isectCenter.t ||
            dot(candidateIsect.normal, isectCenter.normal) < 0.8 ||
            candidates[count].p_hat <= epsilon) continue;

//        Isect candidateLightIsect = intersect(normalize(candidates[count].Y - isectCenter.position), isectCenter.position);
//        if (!candidateLightIsect.isLight) continue;
        // generate X_i
        sum_p_hat += candidates[count].p_hat;
        r.c += candidates[count].c;
        count++;
    }
    if (sum_p_hat <= epsilon) return r;
    for (int i = 0; i < MAX_NEIGHBORS + 1; i++) {
        if (i >= count) break;
        ReSTIR_Reservoir r_i = candidates[i];
        float m_i = r_i.p_hat/sum_p_hat;
        float p_hat_at_center = evaluate_target_function_at_center(r_i.Y, isectCenter, centerBrdf);
        float w_i = m_i * p_hat_at_center * r_i.W_Y;
        float randint = random(vec3(71.31, 67.73, 91.83), hashValue(seed + float(i)));
        r.w_sum += w_i;
        if (randint < w_i / r.w_sum) {
            r.Y = r_i.Y;
            r.p_hat = p_hat_at_center;
        }
    }
    if (r.w_sum == 0.0 || r.p_hat <= epsilon) {
        return r;
    }
    r.W_Y = r.w_sum / r.p_hat;
    return r;
}
//end_macro