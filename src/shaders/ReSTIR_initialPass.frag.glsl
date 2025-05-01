#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;

#define NUM_CANDIDATES 8
#define M1 4 // num of bsdf sampled candidates
#define M2 4 // num of light candidates
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
    return (M_I * pI) / (M_I * pI + M_J * pJ + 1e-6);
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
    float selectedPdf = 0.0;
    float selectedMisWeight = 0.0;
    bool sampleFound = false;

    // ------------------------
    // Generate and evaluate all candidates
    // ------------------------

    for (int i = 0; i < M1+M2; i++) {
        float seed = float(i) + uTime;
        vec2 randUV = gl_FragCoord.xy / uRes;

        // Determine sampling technique (BSDF or light)
        bool fromLight = bool(i < M2);

        vec3 lightDir;
        float p_light, p_bsdf;
        float misWeight;
        float targetPDF;

        if (fromLight) {
            // --- Sample from light source ---
            vec2 u = vec2(rand(randUV, seed), rand(randUV, seed + 1.0));
            vec3 lightPos = sampleSphere(light, lightSize, u);
            lightDir = normalize(lightPos - hitPoint);

            // Skip if behind surface
            if (dot(isect.normal, lightDir) <= 0.0) continue;

            // Check visibility
            float lightDist = length(lightPos - hitPoint);
            Isect shadowIsect = intersect(lightDir, hitPoint + isect.normal * 0.001);
            if (shadowIsect.t > 0.0 && shadowIsect.t < lightDist - 0.01) continue;

            // Compute PDFs for both techniques
            float cosLight = max(dot(-lightDir, normalize(lightPos - light)), 0.0);
            float area = 4.0 * PI * lightSize * lightSize;
            p_light = (lightDist * lightDist) / (area * cosLight + 1e-6);
            p_bsdf = pdfCosineWeighted(lightDir, isect.normal);

            // Target function f = cos(theta) (assuming unit radiance)
            targetPDF = max(dot(isect.normal, lightDir), 0.0);

            // MIS weight using balance heuristic
            misWeight = balanceHeuristic(p_light, p_bsdf, float(M2), float(M1));
        }
        else {
            // --- Sample from BSDF ---
            lightDir = cosineWeightedDirection(seed, isect.normal);

            // Trace ray and check if it hits a light
            Isect lightIsect = intersect(lightDir, hitPoint + isect.normal * 0.001);
            if (lightIsect.t < 0.0 || !lightIsect.isLight) continue;

            // Compute light intersection details
            float lightDist = lightIsect.t;
            vec3 lightPos = hitPoint + lightDir * lightDist;

            // Compute PDFs for both techniques
            float cosLight = max(dot(-lightDir, normalize(lightPos - light)), 0.0);
            float area = 4.0 * PI * lightSize * lightSize;
            p_light = (lightDist * lightDist) / (area * cosLight + 1e-6);
            p_bsdf = pdfCosineWeighted(lightDir, isect.normal);

            // Target function f = cos(theta) (assuming unit radiance)
            targetPDF = max(dot(isect.normal, lightDir), 0.0);

            // MIS weight using balance heuristic
            misWeight = balanceHeuristic(p_bsdf, p_light, float(M1), float(M2));
        }

        // Skip invalid samples
        if (p_light <= 0.0 || p_bsdf <= 0.0 || targetPDF <= 0.0) continue;

        // Compute RIS weight - according to the paper:
        // w_i = m_i(X_i) * p̂(X_i) / p(X_i)
        float samplePdf = fromLight ? p_light : p_bsdf;
        float risWeight = misWeight * targetPDF / samplePdf;

        // Add to sum of weights for normalization
        sumWeights += risWeight;

        // Reservoir sampling
        if (!sampleFound || rand(randUV, seed + 2.0) * sumWeights < risWeight) {
            selectedDirection = lightDir;
            selectedPdf = samplePdf;
            selectedMisWeight = misWeight;
            sampleFound = true;
        }
    }

    // No valid samples found
    if (!sampleFound || sumWeights <= 0.0) {
        fragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    // ------------------------
    // Final estimation
    // ------------------------

    // According to the paper: W_X = (1/p̂(X)) * (sum of all weights)
    // This is our unbiased contribution weight
    float M_total = float(M1 + M2);
    float finalWeight = sumWeights / (M_total * selectedPdf);

    // Compute lighting with the selected sample
    vec3 finalLighting = isect.albedo * max(dot(isect.normal, selectedDirection), 0.0);

    // Final color
    fragColor = vec4(finalLighting * finalWeight, 1.0);
}