//begin_macro{RESTIRGI_SPATIAL_RESAMPLING_LIB}

ReSTIRGI_Reservoir sampleLightsReSTIRGISpatial(vec3 ray, float seed, Isect isectCenter, sampler2D reservoirData1, sampler2D reservoirData2) {
    vec2 uv = gl_FragCoord.xy / uRes;
    ReSTIRGI_Reservoir rCenter = unpackReservoirGI(texture(reservoirData1, uv), texture(reservoirData2, uv));
    ReSTIRGI_Reservoir r = initializeReservoirGI();
    int MAX_NEIGHBORS = 16;
    ReSTIRGI_Reservoir candidates[17];
    candidates[0] = rCenter;
    int count = 1;
    float sum_p_hat = luminance(rCenter.L);
    vec3 centerBrdf = isectCenter.albedo / PI;
    for (int candidateIndex = 0; candidateIndex < MAX_NEIGHBORS; candidateIndex++) {
        vec2 dxy = uniformlyRandomDisk(hashValue(seed + float(candidateIndex)), 8);
        vec2 neighbor = gl_FragCoord.xy + vec2(int(dxy.x), int(dxy.y));
        if (neighbor.x < 0.0 || neighbor.y < 0.0 ||
        neighbor.x >= uRes.x || neighbor.y >= uRes.y) continue;

        vec2 uv = (neighbor) / uRes;

        vec4 uCandidate1 = texture(reservoirData1, uv);
        vec4 uCandidate2 = texture(reservoirData2, uv);

        candidates[count] = unpackReservoirGI(uCandidate1, uCandidate2);
        vec3 candidateRay = normalize(candidates[count].Y - isectCenter.position);
        Isect candidateIsect = intersect(candidateRay, isectCenter.position);
        if (abs(distance(candidateIsect.position, candidates[count].Y)) > epsilon) continue;
        vec2 percent = (neighbor / uRes);
        candidateRay = normalize(mix(mix(uRay00, uRay01, percent.y), mix(uRay10, uRay11, percent.y), percent.x));
        candidateIsect = intersect(candidateRay, uEye);

        float dist = length(candidateIsect.position - isectCenter.position);
        if (
        dot(candidateIsect.normal, isectCenter.normal) < 0.95 ||
        abs(candidateIsect.t - isectCenter.t) / isectCenter.t > 0.3 ||
        abs(candidateIsect.t - isectCenter.t) / isectCenter.t < 0.1 || dist > 1.0)
        continue;

        // generate X_i
        sum_p_hat += luminance(candidates[count].L);
        r.c += candidates[count].c;
        count++;
    }
    if (sum_p_hat <= epsilon) return r;
    float w_sum = 0.0;
    for (int i = 0; i < MAX_NEIGHBORS + 1; i++) {
        if (i >= count) break;
        ReSTIRGI_Reservoir r_i = candidates[i];
        float m_i = luminance(r_i.L)/sum_p_hat;
        float p_hat_at_center = evaluateTargetFunctionAtCenterGI(r_i, isectCenter, centerBrdf);
        float w_i = m_i * p_hat_at_center * r_i.W_Y;
        float randint = random(vec3(71.31, 67.73, 91.83), hashValue(seed + float(i)));
        w_sum += w_i;
        if (randint < w_i / w_sum) {
            r.Y = r_i.Y;
            r.L = r_i.L;
        }
    }
    if (w_sum == 0.0 || luminance(r.L) <= epsilon) {
        return r;
    }
    r.W_Y = w_sum / luminance(r.L);
    return r;
}
//end_macro