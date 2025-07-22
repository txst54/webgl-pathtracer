import {RenderPass} from "../../lib/webglutils/RenderPass";
import {PathTracer} from "../App";
import AnimationManager from "../../animation/AnimationManager";

export interface TextureConfig {
    count: number;
    textures: WebGLTexture[];
}

// Abstract base class for all renderers
export abstract class BaseRenderer {
    protected gl: WebGL2RenderingContext;
    protected canvas: HTMLCanvasElement;
    protected frameBuffer!: WebGLFramebuffer;
    protected textureConfig!: TextureConfig;
    protected sceneTextureConfig!: TextureConfig;
    protected renderPasses: { [key: string]: RenderPass } = {};
    protected animationManager: AnimationManager;

    constructor(gl: WebGL2RenderingContext, canvas: HTMLCanvasElement, pathTracer: PathTracer) {
        this.gl = gl;
        this.canvas = canvas;
        this.animationManager = pathTracer.getAnimationManager();
        this.animationManager.setRenderer(this);
        this.reset();
        this.initialize(pathTracer);
    }

    protected abstract initialize(pathTracer: PathTracer): void;
    public abstract render(): void;

    protected createTextureConfig(count: number, type: number): TextureConfig {
        const textures: WebGLTexture[] = [];

        for (let i = 0; i < count; i++) {
            const texture = this.gl.createTexture();
            this.initializeTexture(texture, type);
            textures.push(texture);
        }

        return { count, textures };
    }

    protected initializeTexture(texture: WebGLTexture, type: number): void {
        this.gl.bindTexture(this.gl.TEXTURE_2D, texture);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
        this.gl.getExtension('EXT_color_buffer_float');

        const zeros = new Float32Array(this.canvas.width * this.canvas.height * 4);
        this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA32F, this.canvas.width, this.canvas.height, 0, this.gl.RGBA, this.gl.FLOAT, zeros);
    }

    protected setupRayRenderPass(renderPass: RenderPass, pathTracer: PathTracer): number {
        const quadVertices = new Float32Array([-1, -1, -1, 1, 1, -1, 1, 1]);
        const indices = new Uint16Array([0, 2, 1, 2, 3, 1]);

        renderPass.setIndexBufferData(indices);
        renderPass.addAttribute("aVertPos", 2, this.gl.FLOAT, false, 2 * Float32Array.BYTES_PER_ELEMENT, 0, undefined, quadVertices);

        this.addCameraUniforms(renderPass, pathTracer);
        this.addTimeUniforms(renderPass, pathTracer);
        this.addRenderingUniforms(renderPass, pathTracer);

        return indices.length;
    }

    protected addCameraUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
        renderPass.addUniform("uEye", (gl, loc) => {
            gl.uniform3fv(loc, pathTracer.getGUI().getCamera().pos().xyz);
        });

        const rayUniforms = ["uRay00", "uRay01", "uRay10", "uRay11"];
        const rayKeys = ["ray00", "ray01", "ray10", "ray11"] as const;

        rayUniforms.forEach((uniform, i) => {
            renderPass.addUniform(uniform, (gl, loc) => {
                gl.uniform3fv(loc, pathTracer.getCachedCameraRays()[rayKeys[i]].xyz);
            });
        });
    }

    protected addTimeUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
        renderPass.addUniform("uTime", (gl, loc) => {
            const timeSinceStart = (new Date().getMilliseconds() - pathTracer.getStartTime().getMilliseconds()) * 0.001;
            gl.uniform1f(loc, timeSinceStart);
        });
    }

    protected addRenderingUniforms(renderPass: RenderPass, pathTracer: PathTracer): void {
        renderPass.addUniform("uTextureWeight", (gl, loc) => {
            gl.uniform1f(loc, pathTracer.getTextureWeight());
        });

        renderPass.addUniform("uRes", (gl, loc) => {
            gl.uniform2f(loc, this.canvas.width, this.canvas.height);
        });

        renderPass.addUniform("uViewMatPrev", (gl, loc) => {
            gl.uniformMatrix4fv(loc, false, pathTracer.getGUI().getCamera().getViewMatrixPrevious());
        });

        renderPass.addUniform("uProjMatPrev", (gl, loc) => {
            gl.uniformMatrix4fv(loc, false, pathTracer.getGUI().getCamera().getProjMatrixPrevious());
        });
    }

    protected writeTexture<T extends Float32Array | Uint8Array | Uint16Array | Uint32Array>(
      gl: WebGL2RenderingContext | WebGLRenderingContext,
      width: number,
      height: number,
      data: T,
      options: {
          internalFormat: number;
          format: number;
          type: number;
      }
    ): WebGLTexture {
        const texture = gl.createTexture();
        if (!texture) throw new Error("Failed to create texture");

        const texelCount = width * height;
        const channels = 4; // assuming RGBA
        const expectedLength = texelCount * channels;

        let paddedData: T;
        if (data.length < expectedLength) {
            const TypedArrayConstructor = (data.constructor as new (length: number) => T);
            paddedData = new TypedArrayConstructor(expectedLength);
            paddedData.set(data);
        } else if (data.length > expectedLength) {
            throw new Error(`Data length ${data.length} exceeds expected length ${expectedLength}`);
        } else {
            paddedData = data;
        }

        gl.bindTexture(gl.TEXTURE_2D, texture);

        gl.texImage2D(
          gl.TEXTURE_2D,
          0,
          options.internalFormat,
          width,
          height,
          0,
          options.format,
          options.type,
          paddedData
        );

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        gl.bindTexture(gl.TEXTURE_2D, null);
        return texture;
    }

    public reset() {
        const DEFAULT_TEXTURE_SIZE = 1024;
        let i = 0;
        // 1 for vertices, 1 for normals, 1 for child indices, 1 for mesh indices, 1 for bounding box
        this.sceneTextureConfig = this.createTextureConfig(5, this.gl.FLOAT);
        let FLOAT_OPTIONS = {internalFormat: this.gl.RGBA32F, format: this.gl.RGBA, type: this.gl.FLOAT};
        this.sceneTextureConfig.textures[i++] = this.writeTexture<Float32Array>(this.gl, DEFAULT_TEXTURE_SIZE, DEFAULT_TEXTURE_SIZE,
          this.animationManager.getAllVertices(), FLOAT_OPTIONS);
        this.sceneTextureConfig.textures[i++] = this.writeTexture<Float32Array>(this.gl, DEFAULT_TEXTURE_SIZE, DEFAULT_TEXTURE_SIZE,
          this.animationManager.getAllNormals(), FLOAT_OPTIONS);
        this.sceneTextureConfig.textures[i++] = this.writeTexture<Float32Array>(this.gl, DEFAULT_TEXTURE_SIZE, DEFAULT_TEXTURE_SIZE,
          this.animationManager.getBoundingBoxes(), FLOAT_OPTIONS);
        this.sceneTextureConfig.textures[i++] = this.writeTexture<Uint32Array>(this.gl, DEFAULT_TEXTURE_SIZE, DEFAULT_TEXTURE_SIZE,
          this.animationManager.getChildIndices(), {internalFormat: this.gl.RGBA32UI, format: this.gl.RGBA_INTEGER, type: this.gl.UNSIGNED_INT});
        this.sceneTextureConfig.textures[i++] = this.writeTexture<Uint32Array>(this.gl, DEFAULT_TEXTURE_SIZE, DEFAULT_TEXTURE_SIZE,
          this.animationManager.getMeshIndices(), {internalFormat: this.gl.RGBA32UI, format: this.gl.RGBA_INTEGER, type: this.gl.UNSIGNED_INT});
    }

    protected addAnimationUniforms(renderPass: RenderPass): number {
        const scene = this.animationManager.getScene();
        if (!scene || scene.meshes.length === 0) return 0;
        renderPass.addUniform("uSceneRootIdx", (gl, loc) => {
            gl.uniform1i(loc, this.animationManager.getRootIdx());
        });
        let i = 0;
        renderPass.addUniform(`uSceneAllVertices`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, this.sceneTextureConfig.textures[i]);
            gl.uniform1i(loc, i++);
        });
        renderPass.addUniform(`uSceneAllNormals`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, this.sceneTextureConfig.textures[i]);
            gl.uniform1i(loc, i++);
        });
        renderPass.addUniform(`uSceneBoundingBoxes`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, this.sceneTextureConfig.textures[i]);
            gl.uniform1i(loc, i++);
        });
        renderPass.addUniform(`uSceneChildIndices`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, this.sceneTextureConfig.textures[i]);
            gl.uniform1i(loc, i++);
        });
        renderPass.addUniform(`uSceneMeshIndices`, (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0 + i);
            gl.bindTexture(gl.TEXTURE_2D, this.sceneTextureConfig.textures[i]);
            gl.uniform1i(loc, i++);
        });
        return i;
    }
}