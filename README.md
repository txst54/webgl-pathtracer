# WebGL Pathtracer

This is a custom implementation of path tracing via Monte-Carlo integration in WebGL 2.0 and also serves as an experimental rendering engine for me to test various SoTA algorithms. 

Modes Supported: 
 - Multiple Importance Sampling (MIS, keybind `1`)
 - Resampled Importance Sampling (RIS, keybind `2`)
 - Reservoir-based Spatial Importance Resampling (ReSTIR Spatial Pass, keybind `3`)
 - Reservoir-based Temporal Importance Resampling (ReSTIR Temporal Pass, keybind `4`)

The pathtracer is bundled using Vite and can be run using `npm run dev`. 

Shaders are compiled using a custom glsl parser (`glsl-parser.cjs`) and can be recompiled using `node glsl-parser.cjs` to compile shaders to `src/pathtracer/Shaders.ts`. 