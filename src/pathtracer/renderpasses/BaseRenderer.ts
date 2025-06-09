import {RenderPass} from "../../lib/webglutils/RenderPass";
import {PathTracer} from "../App";

export interface TextureConfig {
    count: number;
    textures: WebGLTexture[];
}

// Abstract base class for all renderers
export abstract class BaseRenderer {
    protected gl: WebGL2RenderingContext;
    protected canvas: HTMLCanvasElement;
    protected frameBuffer: WebGLFramebuffer | null = null;
    protected textureConfig: TextureConfig | null = null;
    protected renderPasses: { [key: string]: RenderPass } = {};

    constructor(gl: WebGL2RenderingContext, canvas: HTMLCanvasElement, pathTracer: PathTracer) {
        this.gl = gl;
        this.canvas = canvas;
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
}