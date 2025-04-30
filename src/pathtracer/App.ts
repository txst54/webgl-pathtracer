import { Debugger } from "../lib/webglutils/Debugging.js";
import {
  CanvasAnimation,
  WebGLUtilities
} from "../lib/webglutils/CanvasAnimation.js";
import { GUI } from "./Gui.js";
import {
  pathTracerVSText,
  pathTracerFSText,
  spatialReuseVSText,
    spatialReuseFSText
} from "./Shaders.js";
import { Mat4, Vec4, Vec3 } from "../lib/TSM.js";
import { RenderPass } from "../lib/webglutils/RenderPass.js";
import { Camera } from "../lib/webglutils/Camera.js";
import { Cube } from "./Cube.js";
import { Chunk } from "./Chunk.js";

export class MinecraftAnimation extends CanvasAnimation {
  private gui: GUI;
  
  chunk : Chunk;
  
  /*  Cube Rendering */
  private cubeGeometry: Cube;
  private pathTracerRenderPass: RenderPass;
  private spatialRenderPass: RenderPass;
  private textures: WebGLTexture[];
  private sampleCount: number;
  private framebuffer: WebGLFramebuffer;
  private cachedCameraRays: { ray00: Vec3, ray01: Vec3, ray10: Vec3, ray11: Vec3 };
  private pingpong: number = 0;
  private reservoirSampleTexPrev: WebGLTexture;
  private reservoirMetaTexPrev: WebGLTexture;
  private reservoirSampleTexNext: WebGLTexture;
  private reservoirMetaTexNext: WebGLTexture;
  private pathTrace : boolean;

  /* Global Rendering Info */
  private lightPosition: Vec4;
  private backgroundColor: Vec4;

  private canvas2d: HTMLCanvasElement;
  
  // Player's head position in world coordinate.
  // Player should extend two units down from this location, and 0.4 units radially.
  private playerPosition: Vec3;
  
  
  constructor(canvas: HTMLCanvasElement) {
    super(canvas);
    this.pathTrace = true;
    this.canvas2d = document.getElementById("textCanvas") as HTMLCanvasElement;
  
    this.ctx = Debugger.makeDebugContext(this.ctx);
    let gl = this.ctx;
        
    this.gui = new GUI(this.canvas2d, this);
    this.playerPosition = this.gui.getCamera().pos();
    
    // Generate initial landscape
    this.chunk = new Chunk(0.0, 0.0, 64);
    this.framebuffer = gl.createFramebuffer();

    const type = gl.getExtension('OES_texture_float') ? gl.FLOAT : gl.UNSIGNED_BYTE;
    this.textures = [];
    for(let i = 0; i < 2; i++) {
      this.textures.push(gl.createTexture());
      gl.bindTexture(gl.TEXTURE_2D, this.textures[i]);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, this.canvas2d.width, this.canvas2d.height, 0, gl.RGB, type, null);
    }
    gl.bindTexture(gl.TEXTURE_2D, null);
    this.sampleCount = 0;
    this.updateCameraRays();
    this.reservoirSampleTexPrev = gl.createTexture();
    this.reservoirMetaTexPrev = gl.createTexture();
    this.reservoirSampleTexNext = gl.createTexture();
    this.reservoirMetaTexNext = gl.createTexture();

    this.pathTracerRenderPass = new RenderPass(gl, pathTracerVSText, pathTracerFSText);
    this.initPathTracer();
    this.spatialRenderPass = new RenderPass(gl, spatialReuseVSText, spatialReuseFSText);
    this.initSpatialRestir();

    this.lightPosition = new Vec4([-1000, 1000, -1000, 1]);
    this.backgroundColor = new Vec4([0.0, 0.37254903, 0.37254903, 1.0]);    
  }

  /**
   * Setup the simulation. This can be called again to reset the program.
   */
  public reset(): void {    
      this.gui.reset();
      
      this.playerPosition = this.gui.getCamera().pos();
      
  }

  public updateCameraRays() {
    const camera = this.gui.getCamera();
    const invPV = camera.projMatrix().copy()
        .multiply(camera.viewMatrix()).inverse();
    function getRay(x: number, y: number, camera: Camera): Vec3 {
      const clip = new Vec4([x, y, -1, 1.0]); // Near plane (-1 in NDC z)
      const world = invPV.multiplyVec4(clip);
      const ray = new Vec3(world.scale(1.0/world.w).xyz).subtract(camera.pos());
      // console.log(ray.xyz + " " + clip.xyz);
      return ray;
    }

    this.cachedCameraRays = {
      ray00: getRay(-1, -1, camera),
      ray01: getRay(-1, 1, camera),
      ray10: getRay(1, -1, camera),
      ray11: getRay(1, 1, camera)
    };
  }

  private getCameraRays(): {ray00: Vec3, ray01: Vec3, ray10: Vec3, ray11: Vec3} {
    return this.cachedCameraRays;
  }
  
  /**
   * Sets up the blank cube drawing
   */
  private initPathTracer(): void {
    const quadVertices = new Float32Array([
      -1, -1,
      -1, 1,
      1, -1,
      1, 1
    ]);
    const indices = new Uint16Array([
      0, 2, 1,   // first triangle
      2, 3, 1    // second triangle
    ]);
    const gl = this.ctx;
    this.pathTracerRenderPass.setIndexBufferData(indices);
    this.pathTracerRenderPass.addAttribute("aVertPos",
      2,
      this.ctx.FLOAT,
      false,
      2 * Float32Array.BYTES_PER_ELEMENT,
      0,
      undefined,
      quadVertices
    );
    this.pathTracerRenderPass.addUniform("uEye",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform3fv(loc, this.gui.getCamera().pos().xyz);
        });
    this.pathTracerRenderPass.addUniform("uRay00",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform3fv(loc, this.getCameraRays().ray00.xyz);
        });
    this.pathTracerRenderPass.addUniform("uRay01",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform3fv(loc, this.getCameraRays().ray01.xyz);
        });
    this.pathTracerRenderPass.addUniform("uRay10",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform3fv(loc, this.getCameraRays().ray10.xyz);
        });
    this.pathTracerRenderPass.addUniform("uRay11",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform3fv(loc, this.getCameraRays().ray11.xyz);
        });
    this.pathTracerRenderPass.addUniform("uTime",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform1f(loc, performance.now() * 0.001);
        });
    this.pathTracerRenderPass.addUniform("uTextureWeight",
        (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
          gl.uniform1f(loc, this.getTextureWeight());
        });
    this.pathTracerRenderPass.addUniform("uTexture", (gl, loc) => {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.getTexture());
      gl.uniform1i(loc, 0);
    });
    this.pathTracerRenderPass.addUniform("uRes", (gl, loc) => {
      gl.uniform2f(loc, this.canvas2d.width, this.canvas2d.height);
    })

    this.pathTracerRenderPass.setDrawData(this.ctx.TRIANGLES, indices.length, this.ctx.UNSIGNED_SHORT, 0);
    this.pathTracerRenderPass.setup();
  }

  private getTextureWeight(): number {
    return this.sampleCount / (this.sampleCount + 1);
  }

  private setupTexture(tex, internalFormat) {
    const gl = this.ctx;
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, this.canvas2d.width, this.canvas2d.height, 0,
        gl.RGBA, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  }

  private initSpatialRestir(): void {
    this.spatialRenderPass.addUniform("uRes", (gl, loc) => {
      gl.uniform2f(loc, this.canvas2d.width, this.canvas2d.height);
    });

    this.pathTracerRenderPass.addUniform("uTime",
      (gl: WebGLRenderingContext, loc: WebGLUniformLocation) => {
        gl.uniform1f(loc, performance.now() * 0.001);
      });


    const gl = this.ctx;
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);


    const attachments = [gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1];

    this.setupTexture(this.reservoirSampleTexNext, gl.RGBA32F);
    this.setupTexture(this.reservoirMetaTexNext, gl.RGBA32F);

    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.reservoirSampleTexNext, 0);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, this.reservoirMetaTexNext, 0);
    gl.drawBuffers(attachments);

    this.spatialRenderPass.addUniform("uReservoirSampleTex", (gl, loc) => {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.reservoirSampleTexPrev);
      gl.uniform1i(loc, 0);
    });

    this.spatialRenderPass.addUniform("uReservoirMetaTex", (gl, loc) => {
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, this.reservoirMetaTexPrev);
      gl.uniform1i(loc, 1);
    });
  }

  private swapReservoirTextures() {
    [
      this.reservoirSampleTexPrev,
      this.reservoirSampleTexNext
    ] = [
      this.reservoirSampleTexNext,
      this.reservoirSampleTexPrev
    ];

    [
      this.reservoirMetaTexPrev,
      this.reservoirMetaTexNext
    ] = [
      this.reservoirMetaTexNext,
      this.reservoirMetaTexPrev
    ];
  }

  private getTexture() {
    return this.textures[this.pingpong];
  }

  public resetSamples(): void {
    this.sampleCount = 0;
  }

  /**
   * Draws a single frame
   *
   */
  public draw(): void {
    // Update player movement
    this.playerPosition.add(this.gui.walkDir().copy().scale(0.1));
    this.gui.getCamera().setPos(this.playerPosition);

    const gl: WebGLRenderingContext = this.ctx;
    const bg: Vec4 = this.backgroundColor;
    gl.clearColor(bg.r, bg.g, bg.b, bg.a);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.CULL_FACE);
    gl.enable(gl.DEPTH_TEST);
    gl.frontFace(gl.CCW);
    gl.cullFace(gl.BACK);

    const writeIndex = 1 - this.pingpong;

    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.textures[writeIndex], 0);

    this.drawScene(0, 0, 1280, 960);

    gl.bindFramebuffer(gl.FRAMEBUFFER, null);

    // 6. Swap textures (ping-pong)
    this.pingpong = writeIndex;
    this.sampleCount++;

    this.drawScene(0, 0, 1280, 960);
  }

  private drawScene(x: number, y: number, width: number, height: number): void {
    const gl: WebGLRenderingContext = this.ctx;
    gl.viewport(x, y, width, height);

    //TODO: Render multiple chunks around the player, using Perlin noise shaders
    // gl.bindTexture(gl.TEXTURE_2D, this.textures[0]);
    if (this.pathTrace) {
      this.pathTracerRenderPass.draw();
    } else {
      // do the temporal and 1 ray path trace here
      this.spatialRenderPass.draw();
      this.swapReservoirTextures();
    }

  }

  public getGUI(): GUI {
    return this.gui;
  }  
  
  
  public jump() {
      //TODO: If the player is not already in the lair, launch them upwards at 10 units/sec.
  }
}

export function initializeCanvas(): void {
  const canvas = document.getElementById("glCanvas") as HTMLCanvasElement;
  console.log('WebGL version:',
      (document.createElement('canvas').getContext('webgl2') && 'WebGL 2.0') ||
      (document.createElement('canvas').getContext('webgl') && 'WebGL 1.0') ||
      'WebGL not supported');
  /* Start drawing */
  const canvasAnimation: MinecraftAnimation = new MinecraftAnimation(canvas);
  canvasAnimation.start();  
}
