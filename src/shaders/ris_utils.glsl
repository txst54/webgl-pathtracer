//begin_macro{RIS_UTIL}

// Balance heuristic for MIS weights
float balanceHeuristic(float pI, float pJ, float M_I, float M_J) {
    return (pI * M_I) / (M_I * pI + M_J * pJ + 1e-6);
}

// Sample point on sphere
vec3 sampleSphere(vec3 center, float radius, vec2 u) {
    float theta = 2.0 * pi * u.x;
    float phi = acos(2.0 * u.y - 1.0);
    return center + radius * vec3(cos(theta) * sin(phi), sin(theta) * sin(phi), cos(phi));
}

bool isVisible(vec3 from, vec3 to) {
    vec3 dir = normalize(to - from);
    float dist = length(to - from);

    vec3 origin = from + dir * epsilon;
    Isect shadowIsect = intersect(dir, origin);

    return shadowIsect.isLight;
}


float compute_p(vec3 a, vec3 b) {
    vec3 fromLightDir = a - b;
    float dist2 = dot(fromLightDir, fromLightDir);
    fromLightDir = normalize(fromLightDir);
    vec3 lightNormal = normalize(b - light);
    float cosAtLight = max(0.0, dot(lightNormal, fromLightDir));
    if (cosAtLight < epsilon || dist2 < epsilon) return epsilon;
    float surfaceArea = 4.0 * pi * lightSize * lightSize;
    // Conversion factor from area to solid angle pdf is cos(theta)/dist2 and you divide by conversion factor
    float pArea = (1.0 / surfaceArea) * (dist2 / cosAtLight);
    return pArea;
}

vec3 compute_f(vec3 a, vec3 b, vec3 normal, vec3 albedo) {
    vec3 dir_a_to_b = normalize(b - a);
    vec3 light_normal = normalize(b - light);
    float cosTheta_a = max(dot(normal, dir_a_to_b), 0.0);
    float cosTheta_b = max(dot(light_normal, -dir_a_to_b), 0.0);
    float dist2 = dot(b - a, b - a);
    float geometry_term = (cosTheta_a * cosTheta_b) / dist2;
    vec3 brdf = albedo / pi;
    float visibility_term = shadow(a + normal * epsilon, dir_a_to_b, sphereCenter, sphereRadius);
    // Our target function does not include the geometry term because we're integrating
    // in solid angle. The geometry term in the target function ( / in the integrand) is only
    // for surface area direct lighting integration
    return ReSTIR_lightEmission * cosTheta_a * visibility_term;
}

float compute_p_hat(vec3 a, vec3 b, vec3 normal, vec3 albedo) {
    // computes the light contribution p_hat of a ray from the light position 'b' to the object pos 'a'
    return length(compute_f(a, b, normal, albedo));
}

vec3 shade_reservoir(ReSTIR_Reservoir r, Isect isect) {
    // return vec3(r.W_Y);
    return compute_f(isect.position, r.Y, isect.normal, isect.albedo) * r.W_Y;
}

void random_samples(out vec3[M] samples, out float[M] contrib_weights, Isect isect, vec2 randUV) {
    for (int i = 0; i < M; i++) {
        float seed1 = float(i) * 0.1 + uTime * 0.5;
        float seed2 = float(i) * 0.2 + uTime * 0.7;
        vec2 u = vec2(rand(randUV, seed1), rand(randUV, seed2));

        vec3 lightPos = sampleSphere(light, lightSize, u);

        samples[i] = lightPos;
        contrib_weights[i] = compute_p(isect.position, lightPos);
    }
}

//ReSTIR_Reservoir ris_resample(Isect isect, vec2 randUV) {
//    ReSTIR_Reservoir r = initializeReservoir();
//    for (int i = 0; i < M; i++) {
//        float light_sample_pdf = compute_p(isect.position, light);
//    }
//}

ReSTIR_Reservoir resample(vec3[M] samples, float[M] contrib_weights, int count, Isect isect, vec2 randUV, int mis_type, vec3 aux) {
    ReSTIR_Reservoir r = initializeReservoir();
    if (isect.isLight) {
        r.Y = light; // Increased light emission value
        r.W_Y = 1.0;
        return r;
    }

    float p_hatx[M];
    float weights[M];
    float p_sum = 0.0;

    for (int i = 0; i < M; i++) {
        if (i >= count) {
            break;
        }
        p_sum += contrib_weights[i]; // (1 / (1 / p(x)));
    }

    for (int i = 0; i < M; i++) {
        if (i >= count) {
            break;
        }
        float p_hat = compute_p_hat(isect.position, samples[i], isect.normal, isect.albedo);
        float p_i = contrib_weights[i];
        float temporal_weight = i == 0 ? 1.0 : aux.x;
        // float m_i = mis_type == 0 ? p_i / p_sum : mis_type == 1 ? p_hat / aux.x : temporal_weight * p_hat / aux.y;
        float m_i = 1.0 / float(count);
        float W_X_i = 1.0 / contrib_weights[i];
        weights[i] = m_i * p_hat * W_X_i;
        p_hatx[i] = p_hat;
        r.w_sum += weights[i];
    }

    float randint = rand(randUV, uTime + 123.456);
    int selectedIdx = 0;

    for (int i = 0; i < M; i++) {
        if (i >= count) {
            break;
        }
        if (weights[i] > epsilon) {
            randint = randint - (weights[i]/r.w_sum);
            if (randint <= 0.0) {
                selectedIdx = i;
                break;
            }
        }
    }
    r.Y = samples[selectedIdx];
    r.t = isect.t;
    r.p_hat = p_hatx[selectedIdx];
    if (r.w_sum < epsilon || p_hatx[selectedIdx] < epsilon) {
        r.W_Y = 0.0;
    } else {
        r.W_Y = 1.0 / p_hatx[selectedIdx] * r.w_sum;
    }
    r.c = 1.0;
    return r;
}
//end_macro