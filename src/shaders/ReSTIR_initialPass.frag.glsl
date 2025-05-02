#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;

#define NUM_CANDIDATES 8
#define M1 50 // num of bsdf sampled candidates
#define M2 50 // num of light candidates
#define PI 3.14159265359

// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESERVOIR_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}

float rand(vec2 co, float seed) {
    return fract(sin(dot(co.xy + seed, vec2(12.9898, 78.233))) * 43758.5453);
}

// Balance heuristic for MIS weights
float balanceHeuristic(float pI, float pJ, float M_I, float M_J) {
    return (pI) / (M_I * pI + M_J * pJ + 1e-6);
}

// Sample point on sphere
vec3 sampleSphere(vec3 center, float radius, vec2 u) {
    float z = 1.0 - 2.0 * u.x;
    float phi = 2.0 * PI * u.y;
    float r = sqrt(1.0 - z * z);
    return center + radius * vec3(r * cos(phi), r * sin(phi), z);
}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;

    Isect isect = intersect(ray, origin);
    if (isect.t < 0.0) {
        // Hit nothing, return sky/background color
        fragColor = vec4(0.2, 0.3, 0.5, 1.0);
        return;
    }

    vec3 hitPoint = origin + isect.t * ray;

    // Direct hit on light source
    if (isect.isLight) {
        fragColor = vec4(vec3(1.0), 1.0); // Simple emission
        return;
    }

    // Initialize for RIS
    vec3 selectedDirection;
    float sumWeights = 0.0;
    float sumSamplingWeights = 0.0;
    float selectedPdf = 0.0;
    float selectedMisWeight = 0.0;
    bool sampleFound = false;
    vec2 randUV = gl_FragCoord.xy / uRes;

    for (int i = 0; i < M1+M2; i++) {
        float seed = float(i) + uTime;

        // Determine sampling technique (BSDF or light)
        bool fromLight = bool(i < M2);

        float p1, p2, m1, m2;
        vec3 lightPos;
        vec3 lightDir;
        float lightDist;

        if (fromLight) {
            // --- Sample from light source ---
            vec2 u = vec2(rand(randUV, seed), rand(randUV, seed + 1.0));
            lightPos = sampleSphere(light, lightSize, u);
            lightDir = normalize(lightPos - hitPoint);

            if (dot(isect.normal, lightDir) <= 0.0) continue;

            lightDist = length(lightPos - hitPoint);
            Isect shadowIsect = intersect(lightDir, hitPoint + isect.normal * 0.001);
            if (shadowIsect.t > 0.0 && shadowIsect.t < lightDist - 0.01) continue;
        } else {
            // BSDF
            lightDir = cosineWeightedDirection(seed, isect.normal);

            Isect lightIsect = intersect(lightDir, hitPoint + isect.normal * 0.001);
            if (lightIsect.t < 0.0 || !lightIsect.isLight) continue;

            float lightDist = lightIsect.t;
        }
        float cosLight = max(dot(-lightDir, normalize(lightPos - light)), 0.0);
        float area = 4.0 * PI * lightSize * lightSize;
        float p_light = (lightDist * lightDist) / (area * cosLight + 1e-6);
        float p_bsdf = pdfCosineWeighted(lightDir, isect.normal);
        p1 = fromLight ? p_light : p_bsdf;
        p2 = fromLight ? p_bsdf : p_light;
        m1 = fromLight ? float(M2) : float(M1);
        m2 = fromLight ? float(M1) : float(M2);
        float m_i = balanceHeuristic(p1, p2, m1, m2);
        float p_hat = max(dot(isect.normal, lightDir), 0.0);

        // Skip invalid samples
        if (p_light <= 0.0 || p_bsdf <= 0.0 || p_hat <= 0.0) continue;

        // Compute RIS weight - according to the paper:
        float w_i = m_i * p_hat / p1;
        sumWeights += p_hat / p1;
        sumSamplingWeights += w_i;

        // Reservoir sampling
        if (!sampleFound || rand(randUV, seed + 2.0) * sumSamplingWeights < w_i) {
            selectedDirection = lightDir;
            selectedPdf = p_hat;
            selectedMisWeight = w_i;
            sampleFound = true;
        }
    }

    // No valid samples found
    if (!sampleFound || sumWeights <= 0.0) {
        fragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    // According to the paper: W_X = (1/p̂(X)) * (sum of all weights)
    // This is our unbiased contribution weight
    float M_total = float(M1 + M2);
    float finalWeight = sumWeights / selectedPdf;
    vec3 finalLighting = (isect.albedo / PI) * max(dot(isect.normal, selectedDirection), 0.0);

    // Final color
    fragColor = vec4(finalLighting * finalWeight, 1.0);
}