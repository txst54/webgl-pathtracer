//begin_macro{RIS_UTIL}
float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

// Balance heuristic for MIS weights
float balanceHeuristic(float pI, float pJ, float M_I, float M_J) {
    return (pI * M_I) / (M_I * pI + M_J * pJ + 1e-6);
}

// Sample point on sphere
vec3 sampleSphere(vec3 center, float radius, vec2 u) {
    float z = 1.0 - 2.0 * u.x;
    float phi = 2.0 * pi * u.y;
    float r = sqrt(1.0 - z * z);
    return center + radius * vec3(r * cos(phi), r * sin(phi), z);
}

// Improved shadow ray test
bool isVisible(vec3 from, vec3 to) {
    vec3 dir = normalize(to - from);
    float dist = length(to - from);

    // Offset the ray origin slightly to avoid self-intersection
    Isect shadowIsect = intersect(dir, from + dir * 0.001);

    // No intersection or intersection beyond target point
    return shadowIsect.t < 0.0 || shadowIsect.t > dist - 0.001;
}

float compute_p(vec3 a, vec3 b) {
    vec3 vec_a_to_b = b - a;
    float distSq = dot(vec_a_to_b, vec_a_to_b);
    if (distSq == 0.0) return 0.0;
    float dist = sqrt(distSq);
    vec3 dir_a_to_b = vec_a_to_b / dist; // Normalized direction from a to b

    vec3 lightNormal = -normalize(b - light); // Normal at point b on the sphere
    float cosBeta = max(0.0, dot(lightNormal, dir_a_to_b)); // Cosine between light normal and direction from a to b
    if (cosBeta == 0.0) return 0.0; // Point on light is not visible or facing away from a

    float area = 4.0 * pi * lightSize * lightSize; // Area of the sphere

    // PDF in area measure
    float pArea = 1.0 / area;

    // Conversion factor dA / dOmega = ||b-a||^2 / |(b-a) . n_b|
    // (b-a) . n_b = vec_a_to_b . lightNormal = dist * dir_a_to_b . lightNormal = dist * cosBeta
    // Conversion factor is distSq / (dist * cosBeta) = dist / cosBeta
    float conversionFactor = dist / max(cosBeta, epsilon);

    return pArea * conversionFactor;
}

float compute_p_hat(vec3 a, vec3 b, vec3 normal, vec3 albedo) {
    // computes the light contribution p_hat of a ray from the light position 'b' to the object pos 'a'
    vec3 lightDir = normalize(b - a);
    float dist2 = dot(b - a, b - a);

    float cosTheta = max(dot(normal, lightDir), 0.0);
    vec3 f_r = albedo / pi;

    vec3 contrib = f_r * ReSTIR_lightEmission * cosTheta / dist2;
    return length(contrib);
}

vec3 shade_reservoir(ReSTIR_Reservoir r, Isect isect) {
    vec3 lightDir = normalize(r.Y - isect.position);
    float cosTheta = max(dot(isect.normal, lightDir), 0.0);
    vec3 brdf = isect.albedo / pi;
    return (brdf * ReSTIR_lightEmission * cosTheta) * r.W_Y;
}

void random_samples(out vec3[M] samples, out int count, Isect isect, vec2 randUV) {
    count = 0;
    for (int i = 0; i < M; i++) {
        float seed1 = float(i) * 0.1 + uTime * 0.5;
        float seed2 = float(i) * 0.2 + uTime * 0.7;
        vec2 u = vec2(rand(randUV, seed1), rand(randUV, seed2));

        vec3 lightPos = sampleSphere(light, lightSize, u);
        vec3 lightDir = normalize(lightPos - isect.position);

        if (dot(isect.normal, lightDir) <= 0.0 || !isVisible(isect.position, lightPos)) continue;

        if (count < M) {
            samples[count] = lightPos;
            count++;
        }
    }
}


ReSTIR_Reservoir resample(vec3[M] samples, int count, Isect isect, vec2 randUV) {
    ReSTIR_Reservoir r = initializeReservoir();
    if (isect.isLight) {
        r.Y = ReSTIR_lightEmission; // Increased light emission value
        r.W_Y = 0.0;
        return r;
    }

    // No valid samples found
    if (count == 0) {
        r.Y = vec3(0.0);
        return r;
    }

    float p_hatx[M];
    float p_x[M];
    float weights[M];

    for (int i = 0; i < M; i++) {
        if (i >= count) {
            break;
        }
        float p_light = compute_p(isect.position, samples[i]);
        float p_hat = compute_p_hat(isect.position, samples[i], isect.normal, isect.albedo);
        weights[i] = p_hat / p_light / float(count);
        p_hatx[i] = p_hat;
        p_x[i] = p_light;
        r.w_sum += weights[i];
    }

    float randint = rand(randUV, uTime + 123.456);
    int selectedIdx = 0;

    for (int i = 0; i < M; i++) {
        if (i >= count) {
            break;
        }
        randint = randint - weights[i]/r.w_sum;
        if (randint <= 0.0) {
            selectedIdx = i;
            break;
        }
    }
    r.Y = samples[selectedIdx];
    r.W_Y = r.w_sum / p_hatx[selectedIdx];
    return r;
}
//end_macro