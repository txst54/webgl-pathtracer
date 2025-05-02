#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;
out vec4 fragColor;

#define M 100       // Increase total number of samples for better convergence
#define M1 5       // num of bsdf sampled candidates
#define M2 5       // num of light candidates
#define PI 3.14159265359

// Assuming the macro expansions from your original shader
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
    return (pI * M_I) / (M_I * pI + M_J * pJ + 1e-6);
}

// Sample point on sphere
vec3 sampleSphere(vec3 center, float radius, vec2 u) {
    float z = 1.0 - 2.0 * u.x;
    float phi = 2.0 * PI * u.y;
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

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;
    vec2 randUV = gl_FragCoord.xy / uRes;

    // Add time-based jitter for temporal anti-aliasing
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    Isect isect = intersect(ray, origin);
    if (isect.t < 0.0) {
        // Hit nothing, return sky/background color
        fragColor = vec4(0.2, 0.3, 0.5, 1.0);
        return;
    }

    vec3 hitPoint = origin + isect.t * ray;

    // Direct hit on light source
    if (isect.isLight) {
        fragColor = vec4(vec3(5.0), 1.0); // Increased light emission value
        return;
    }

    // Light properties
    vec3 lightEmission = vec3(5.0); // Light intensity/color

    // Initialize for RIS
    vec3 samples[M];
    float p_hatx[M];
    float p_x[M];
    float weights[M];
    int numSamples = 0;

    float sumWeights = 0.0;

    // Generate candidates
    for (int i = 0; i < M; i++) {
        // Generate different random values for each sample
        float seed1 = float(i) * 0.1 + uTime * 0.5;
        float seed2 = float(i) * 0.2 + uTime * 0.7;
        vec2 u = vec2(rand(randUV, seed1), rand(randUV, seed2));

        // Sample point on light
        vec3 lightPos = sampleSphere(light, lightSize, u);
        vec3 lightDir = normalize(lightPos - isect.position);

        // Skip samples that are not visible or facing away
        if (dot(isect.normal, lightDir) <= 0.0) continue;

        // Perform shadow test
        if (!isVisible(isect.position, lightPos)) continue;

        // Calculate PDFs and weights
        float cosLight = max(0.0, dot(-lightDir, normalize(lightPos - light)));
        float area = 4.0 * PI * lightSize * lightSize;

        // Probability of sampling this point on the light
        float p_light = 1.0 / area;

        // Account for distance falloff
        float dist2 = length(lightPos - isect.position);
        dist2 = dist2 * dist2;

        // BRDF evaluation
        vec3 f = (isect.albedo / PI) * max(dot(isect.normal, lightDir), 0.0);

        // Target function (this will be our estimate of radiance)
        vec3 targetFunction = f * lightEmission * cosLight / dist2;
        float p_hat = length(targetFunction); // Use luminance as target PDF

        if (p_hat <= 0.0) continue;

        // Store the candidate
        samples[numSamples] = lightPos;
        p_hatx[numSamples] = p_hat;
        p_x[numSamples] = p_light;

        // Calculate weight for RIS
        weights[numSamples] = p_hat / p_light;
        sumWeights += weights[numSamples];

        numSamples++;
    }

    // No valid samples found
    if (numSamples == 0 || sumWeights <= 0.0) {
        fragColor = vec4(vec3(0.0), 1.0);
        return;
    }

    // Normalize weights
    for (int i = 0; i < numSamples; i++) {
        weights[i] /= sumWeights;
    }

    // Select one sample based on weights
    float r = rand(randUV, uTime + 123.456);
    int selectedIdx = 0;
    float accumWeight = 0.0;

    for (int i = 0; i < numSamples; i++) {
        accumWeight += weights[i];
        if (r <= accumWeight) {
            selectedIdx = i;
            break;
        }
    }

    // Get the selected sample
    vec3 selectedLightPos = samples[selectedIdx];
    vec3 selectedLightDir = normalize(selectedLightPos - isect.position);

    // Calculate final weight for the selected sample
    float W = sumWeights / float(numSamples);

    // Calculate final contribution
    float dist = length(selectedLightPos - isect.position);
    float cosTheta = max(0.0, dot(isect.normal, selectedLightDir));
    float cosLight = max(0.0, dot(-selectedLightDir, normalize(selectedLightPos - light)));
    vec3 brdf = isect.albedo / PI;

    // Final lighting calculation with correct weighting
    vec3 L = (W * brdf * lightEmission * cosTheta * cosLight) / (dist * dist);

    // Apply a gamma correction to make the image brighter
    L = pow(L, vec3(1.0/2.2));

    // Final color
    fragColor = vec4(L, 1.0);
}