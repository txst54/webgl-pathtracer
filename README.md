# WebGL Pathtracer

This is a custom implementation of path tracing via Monte-Carlo integration in WebGL 2.0 and also serves as an experimental rendering engine for me to test various SoTA algorithms. 

<img width="1530" height="818" alt="path_tracer" src="https://github.com/user-attachments/assets/b05a3f4e-4770-4a77-806d-6597192a3bf8" />

<img width="800" height="706" alt="1753821928767" src="https://github.com/user-attachments/assets/be40e449-2a15-49d3-8787-5d8a74d1c339" />
ReSTIR - Global Illumination, less noise

<img width="800" height="702" alt="1753822190197" src="https://github.com/user-attachments/assets/c8a40d19-e411-4d0f-9c0a-b351bded0fce" />
MIS - more noise, less luminance, less global illumination


Modes Supported: 
 - Multiple Importance Sampling (MIS, keybind `1`)
 - Resampled Importance Sampling (RIS, keybind `2`)
 - Reservoir-based Spatial Importance Resampling (ReSTIR Spatial Pass, keybind `3`)
 - Reservoir-based Temporal Importance Resampling (ReSTIR Temporal Pass, keybind `4`)

The pathtracer is bundled using Vite and can be run using `npm run dev`. 

Shaders are compiled using a custom glsl parser (`glsl-parser.cjs`) and can be recompiled using `node glsl-parser.cjs` to compile shaders to `src/pathtracer/Shaders.ts`. 
