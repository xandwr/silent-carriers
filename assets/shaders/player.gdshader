shader_type spatial;

uniform sampler2D skin_texture : filter_nearest_mipmap, repeat_enable;
uniform sampler2D pants_texture : filter_nearest_mipmap;
uniform sampler2D shirt_texture : filter_nearest_mipmap;

// Material properties
uniform float skin_roughness : hint_range(0.3, 0.7) = 0.4;
uniform float skin_subsurface : hint_range(0.0, 1.0) = 0.3;
uniform float clothes_roughness : hint_range(0.5, 1.0) = 0.8;

void fragment() {
    vec4 skin = texture(skin_texture, UV);
    vec4 pants = texture(pants_texture, UV);
    vec4 shirt = texture(shirt_texture, UV);

    vec4 pants_mix = mix(skin, pants, pants.a);
    vec4 shirt_mix = mix(pants_mix, shirt, shirt.a);

    // Calculate roughness based on which material is showing
    float material_roughness;
    if (shirt.a > 0.5) {
        material_roughness = clothes_roughness;
    } else if (pants.a > 0.5) {
        material_roughness = clothes_roughness;
    } else {
        // This is skin
        material_roughness = skin_roughness;
    }

    ALBEDO = shirt_mix.rgb;
    ROUGHNESS = material_roughness;
    METALLIC = 0.0; // Neither skin nor regular clothes are metallic
    SPECULAR = 0.35; // Slight specular for all materials
}