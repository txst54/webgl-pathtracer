const randomSLibText = `
float random(vec3 scale, float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
}

vec3 uniformlyRandomDirection(float seed) {
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    float z = 1.0 - 2.0 * u;
    float r = sqrt(1.0 - z * z);
    float angle = 6.283185307179586 * v;
    return vec3(r * cos(angle), r * sin(angle), z);
}

vec3 uniformlyRandomVector(float seed) {
    return uniformlyRandomDirection(seed) * sqrt(random(vec3(36.7539, 50.3658, 306.2759), seed));
}

float genSeed(vec3 ray, int i) {
    return ray.x * 11.87 + ray.y * 78.77 + ray.z * 26.63 + uTime * 51.79 + float(i) * 93.71;
}
`

const sphereSLibText = `
float intersectSphere(vec3 origin, vec3 ray, vec3 sphereCenter, float sphereRadius) {
    vec3 toSphere = origin - sphereCenter;
    float a = dot(ray, ray);
    float b = 2.0 * dot(toSphere, ray);
    float c = dot(toSphere, toSphere) - sphereRadius*sphereRadius;
    float discriminant = b*b - 4.0*a*c;
    if(discriminant > 0.0) {
        float t = (-b - sqrt(discriminant)) / (2.0 * a);
        if(t > 0.0) return t;
    }
    return infinity;
}

vec3 normalForSphere(vec3 hit, vec3 sphereCenter, float sphereRadius) {
    return (hit - sphereCenter) / sphereRadius;
}
`

const cubeSLibText = `
vec2 intersectCube(vec3 origin, vec3 ray, vec3 cubeMin, vec3 cubeMax) {
    vec3 tMin = (cubeMin - origin) / ray;
    vec3 tMax = (cubeMax - origin) / ray;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
}

vec3 normalForCube(vec3 hit, vec3 cubeMin, vec3 cubeMax) {
  if (hit.x < cubeMin.x + epsilon) 
    return vec3(-1.0, 0.0, 0.0);
  else if (hit.x > cubeMax.x - epsilon) 
    return vec3(1.0, 0.0, 0.0);
  else if (hit.y < cubeMin.y + epsilon) 
    return vec3(0.0, -1.0, 0.0);
  else if (hit.y > cubeMax.y - epsilon) 
    return vec3(0.0, 1.0, 0.0);
  else if (hit.z < cubeMin.z + epsilon) 
    return vec3(0.0, 0.0, -1.0);
  else 
    return vec3(0.0, 0.0, 1.0);
}
`

const constantsSLibText = `
vec3 roomCubeMin = vec3(-10.0, -10.0, -10.0);
vec3 roomCubeMax = vec3(10.0, 10.0, 10.0);
vec3 light = vec3(0.0, 5.0, 0.0);
float infinity = 10000.0;
float epsilon = 0.0001;
float lightSize = 0.1;
int numCandidates = 4;
`

export const pathTracerVSText = `
attribute vec2 aVertPos;
uniform vec3 uEye, uRay00, uRay01, uRay10, uRay11;
varying vec3 initialRay;

void main() {
    vec2 percent = aVertPos.xy * 0.5 + 0.5;
    initialRay = mix(mix(uRay00, uRay01, percent.y), mix(uRay10, uRay11, percent.y), percent.x);
    gl_Position = vec4(aVertPos, 0.0, 1.0);
}
`;

export const pathTracerFSText = `
precision highp float;

uniform vec3 uEye;
uniform float uTime;
varying vec3 initialRay;
uniform vec2 uRes;
${constantsSLibText}

struct Reservoir {
    vec3 sample;       // Light sample direction or position
    float weight;      // Importance weight
    float sumWeight;   // Sum of weights over all candidates
    int count;         // Number of samples seen
};

${randomSLibText}
${cubeSLibText}
${sphereSLibText}

vec3 cosineWeightedDirection(float seed, vec3 normal) {
    // Simple cosine-weighted random direction
    float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    float r = sqrt(u);
    float angle = 6.28318530718 * v;
    vec3 sdir, tdir;
    if (abs(normal.x) < .5) {
        sdir = cross(normal, vec3(1,0,0));
    } else {
        sdir = cross(normal, vec3(0,1,0));
    }
    tdir = cross(normal, sdir);
    return r*cos(angle)*sdir + r*sin(angle)*tdir + sqrt(1.-u)*normal;
}

float shadow(vec3 origin, vec3 ray, vec3 sphereCenter, float sphereRadius) {
    float t = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    if (t < 1.0) return 0.0;
    return 1.0;
}

Reservoir initializeReservoir() {
    Reservoir r;
    r.sample = vec3(0.0);
    r.weight = 0.0;
    r.sumWeight = 0.0;
    r.count = 0;
    return r;
}

vec4 calculateColor(vec3 origin, vec3 ray, vec3 light) {
    vec3 colorMask = vec3(1.0);
    vec3 accumulatedColor = vec3(0.0);
    
    // Simple scene: sphere at center
    vec3 sphereCenter = vec3(0.0, 0.0, 0.0);
    float sphereRadius = 1.0;
    float roulette = random(vec3(1.0), ray.x * 11.87 + ray.y * 78.77 + ray.z * 26.63 + uTime * 51.79);
    int num_iters = int(ceil(log(1.0-roulette)/log(0.9)));
    
    // for (int bounce = 0; bounce < 100; bounce++) {
    vec2 tRoom = intersectCube(origin, ray, roomCubeMin, roomCubeMax);
    float isect = intersectSphere(origin, ray, sphereCenter, sphereRadius);
    float t = infinity;
    if (tRoom.x < tRoom.y) t = tRoom.y;
    if (isect < t) t = isect;
    
    vec3 hit = origin + ray * t;
    vec3 surfaceColor = vec3(0.75);
    float specularHighlight = 0.0;
    vec3 normal;
    
    if (t == tRoom.y) {
        normal = -normalForCube(hit, roomCubeMin, roomCubeMax);
        if(hit.x < -9.9999) surfaceColor = vec3(0.1, 0.5, 1.0);
        else if(hit.x > 9.9999) surfaceColor = vec3(1.0, 0.9, 0.1);
        // ray = cosineWeightedDirection(uTime + float(bounce), normal);
    } else if (t == infinity) {
        // TODO return a default reservoir [weightage 0]
    }
    else {
        normal = normalForSphere(hit, sphereCenter, sphereRadius);
        // ray = cosineWeightedDirection(uTime + float(bounce), normal);
    }
    vec3 position = ray * t + origin;
    
    Reservoir localReservoir = initializeReservoir();
    for (int i = 0; i < numCandidates; i++) {
        vec3 lightSample = light + uniformlyRandomVector(genSeed(ray, i)) * lightSize;
        vec3 toLight = lightSample - position;
        vec3 lightDir = normalize(toLight);
        if (shadow(position + normal * epsilon, lightDir, sphereCenter, sphereRadius) < 0.5) continue;
        float distance2 = dot(toLight, toLight);
        float cosine = max(dot(normal, lightDir), 0.0);
    
        float Li = cosine / distance2;
        float pdf = 1.0 / (4.0 * 3.14159 * lightSize * lightSize);
        float weight = Li / pdf;
        
        localReservoir.count += 1;
        localReservoir.sumWeight += weight;
        if (random(genSeed(ray, i+23)) < weight / localReservoir.sumWeight) {
            localReservoir.sample = lightSample;
            localReservoir.weight = weight;
        }
    }
    return vec4(localReservoir.sample, localReservoir.sumWeight);
}

void main() {
    vec3 newLight = light + uniformlyRandomVector(uTime - 53.0) * lightSize;
    vec4 color = calculateColor(uEye, initialRay, newLight);
    gl_FragColor = vec4(color);
}
`;