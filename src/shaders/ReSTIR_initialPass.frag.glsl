#version 300 es
precision highp float;

uniform vec3 uEye;
uniform vec2 uRes;
uniform float uTime;
in vec3 initialRay;

layout(location = 0) out vec4 out_ReservoirData1;
layout(location = 1) out vec4 out_ReservoirData2;

#define M 10       // Increase total number of samples for better convergence
#define M1 5       // num of bsdf sampled candidates
#define M2 5       // num of light candidates
#define PI 3.14159265359

// Assuming the macro expansions from your original shader
// use_macro{CONSTANTS}
// use_macro{SPHERE_LIB}
// use_macro{CUBE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RESTIR_RESERVOIR_LIB}
// use_macro{RAND_LIB}
// use_macro{RAY_LIB}
// use_macro{RIS_UTIL}

void main() {
    vec3 ray = normalize(initialRay);
    vec3 origin = uEye;
    vec2 randUV = gl_FragCoord.xy / uRes;

    // Add time-based jitter for temporal anti-aliasing
    float jitterSeed = uTime * 1234.5678;
    randUV += vec2(rand(randUV, jitterSeed), rand(randUV, jitterSeed + 1.0)) * 0.001;

    Isect isect = intersect(ray, origin);
    ReSTIR_Reservoir r = initializeReservoir();

    // Direct hit on light source
    if (isect.isLight) {
        r.Y = ReSTIR_lightEmission; // Increased light emission value
        out_ReservoirData1 = packReservoir1(r);
        out_ReservoirData2 = packReservoir2(r);
        return;
    }

    // Initialize for RIS
    vec3 samples[M];
    float p_hatx[M];
    float p_x[M];
    float weights[M];
    int numSamples = 0;

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

        float p_light = compute_p(isect.position, lightPos);
        float p_hat = compute_p_hat(isect.position, lightPos, isect.normal, isect.albedo);

        if (p_hat <= 0.0) continue;

        // Store the candidate
        samples[numSamples] = lightPos;
        p_hatx[numSamples] = p_hat;
        p_x[numSamples] = p_light;

        // Calculate weight for RIS
        weights[numSamples] = p_hat / p_light;
        r.w_sum += weights[numSamples];

        numSamples++;
    }

    // No valid samples found
    if (numSamples == 0 || r.w_sum <= 0.0) {
        r.Y = vec3(0.0);
        out_ReservoirData1 = packReservoir1(r);
        out_ReservoirData2 = packReservoir2(r);
        return;
    }

    for (int i = 0; i < numSamples; i++) {
        weights[i] /= r.w_sum;
    }

    float randint = rand(randUV, uTime + 123.456);
    int selectedIdx = 0;
    float accumWeight = 0.0;

    for (int i = 0; i < numSamples; i++) {
        accumWeight += weights[i];
        if (randint <= accumWeight) {
            selectedIdx = i;
            break;
        }
    }

    // Get the selected sample
    // r.Y = samples[selectedIdx];

    // Calculate final weight for the selected sample
    r.W_Y = r.w_sum / float(numSamples);

    // Calculate final contribution
//    float cosTheta = max(0.0, dot(isect.normal, samples[selectedIdx]));
//    vec3 brdf = isect.albedo / PI;

    r.Y = samples[selectedIdx];

    out_ReservoirData1 = packReservoir1(r);
    out_ReservoirData2 = packReservoir2(r);
}