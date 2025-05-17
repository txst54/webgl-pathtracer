#version 300 es
precision highp float;

uniform vec3 uEye;
uniform float uTime;
in vec3 initialRay;

uniform sampler2D uTexture;
uniform float uTextureWeight;
uniform vec2 uRes;

// use_macro{CONSTANTS}
// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}

out vec4 fragColor;

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);

    float roulette = random(vec3(1.0), dot(gl_FragCoord.xy, vec2(12.9898, 78.233)) + uTime * 51.79);
    int num_iters = int(ceil(log(1.0 - roulette) / log(0.9)));
    float total_dist = 0.0;
    for (int bounce = 0; bounce < 100; bounce++) {
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }
        float sampleStrategy = random(vec3(1.0), uTime + float(bounce) * 23.0 + 79.0 + ray.x + ray.y);
        bool usedCosine = sampleStrategy < 0.5;
        if (usedCosine) {
            ray = cosineWeightedDirection(uTime + float(bounce) * 17.0 + ray.x + ray.y, isect.normal);
        } else {
            ray = uniformSphereDirection(isect.position, uTime + float(bounce) * 11.0 + ray.x + ray.y, light, lightSize);
        }
        origin = isect.position + isect.normal * epsilon;
        float pdfCosine = pdfCosineWeighted(ray, isect.normal);
        float pdfLight = pdfUniformSphere(ray, isect.position);
        float weightCosine = pdfCosine / (pdfCosine + pdfLight + epsilon);
        float weightLight = pdfLight / (pdfCosine + pdfLight + epsilon);

        float misWeight = usedCosine ? weightCosine : weightLight;
        float pdfX = max(epsilon, usedCosine ? pdfCosine : pdfLight);
        vec3 brdf = isect.albedo / pi;
        accumulatedColor += isect.isLight ? lightIntensity * colorMask : vec3(0.0);
        float ndotr = dot(isect.normal, ray);
        if (ndotr > 0.0) {
            colorMask *= brdf * abs(ndotr) * misWeight / pdfX;
        } else {
            break;
        }

        if (bounce > num_iters) {
            break;
        }
    }

    return accumulatedColor;
}

void main() {

    // Avoid using 'texture' as a variable name
    vec3 texColor = texture(uTexture, gl_FragCoord.xy / uRes).rgb;

    vec3 color = mix(calculateColor(uEye, initialRay, light), texColor, uTextureWeight);
    fragColor = vec4(color, 1.0);
}