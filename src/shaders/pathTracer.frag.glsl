precision highp float;

uniform vec3 uEye;
uniform float uTime;
varying vec3 initialRay;
uniform sampler2D uTexture;
uniform float uTextureWeight;
uniform vec2 uRes;
// use_macro{CONSTANTS}

// use_macro{RAND_LIB}
// use_macro{CUBE_LIB}
// use_macro{SPHERE_LIB}
// use_macro{SCENE_LIB}
// use_macro{RAY_LIB}

vec3 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);

    // Simple scene: sphere at center
    float roulette = random(vec3(1.0), ray.x * 11.87 + ray.y * 78.77 + ray.z * 26.63 + uTime * 51.79);
    int num_iters = int(ceil(log(1.0-roulette)/log(0.9)));

    for (int bounce = 0; bounce < 100; bounce++) {
        Isect isect = intersect(ray, origin);
        if (isect.t == infinity) {
            break;
        }
        ray = cosineWeightedDirection(uTime + float(bounce), isect.normal);
        vec3 toLight = light - isect.position;
        float diffuse = max(0.0, dot(normalize(toLight), isect.normal));

        float shadowIntensity = shadow(isect.position + isect.normal * epsilon, toLight, sphereCenter, sphereRadius);

        colorMask *= isect.albedo;
        accumulatedColor += colorMask * (0.5 * diffuse * shadowIntensity);
        origin = isect.position;

        if (bounce > num_iters) {
            break;
        }
    }
    return accumulatedColor;
}

void main() {
    vec3 newLight = light + uniformlyRandomVector(uTime - 53.0) * lightSize;
    vec3 texture = texture2D(uTexture, gl_FragCoord.xy / uRes).rgb;
    vec3 color = mix(calculateColor(uEye, initialRay, newLight), texture, uTextureWeight);
    gl_FragColor = vec4(color, 1.0);
}