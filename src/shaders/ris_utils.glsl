//begin_macro{RIS_UTIL}
float evaluate_target_function_at_center(vec3 light_sample, Isect isect, vec3 brdf) {
    vec3 sample_direction = normalize(light_sample - isect.position);
    Isect light_isect = intersect(sample_direction, isect.position);
    float visibility = light_isect.isLight ? 1.0 : 0.0;
    float ndotr = dot(isect.normal, sample_direction);
    vec3 contribution = brdf * abs(ndotr) * visibility;
    return dot(contribution, vec3(0.3086, 0.6094, 0.0820));
}
//end_macro