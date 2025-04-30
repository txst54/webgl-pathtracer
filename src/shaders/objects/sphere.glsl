// begin_macro{SPHERE_LIB}
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
// end_macro