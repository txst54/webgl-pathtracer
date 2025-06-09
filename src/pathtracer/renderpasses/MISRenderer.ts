// MIS Path Tracer Renderer
import {BaseRenderer} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerFSText, pathTracerVSText} from "../Shaders";
import {PathTracer} from "../App";

export default class MISRenderer extends BaseRenderer {
    private pingpong: number = 0;

    protected initialize(pathTracer: PathTracer): void {
        const type = this.gl.getExtension('OES_texture_float') ? this.gl.FLOAT : this.gl.UNSIGNED_BYTE;
        this.frameBuffer = this.gl.createFramebuffer();
        this.textureConfig = this.createTextureConfig(2, type);

        this.renderPasses.pathTracer = new RenderPass(this.gl, pathTracerVSText, pathTracerFSText);
        this.setupPathTracerPass(pathTracer);
    }

    private setupPathTracerPass(pathTracer: PathTracer): void {
        const numIndices = this.setupRayRenderPass(this.renderPasses.pathTracer, pathTracer);
        this.renderPasses.pathTracer.addUniform("uTexture", (gl, loc) => {
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, this.textureConfig.textures[this.pingpong]);
            gl.uniform1i(loc, 0);
        });
        this.renderPasses.pathTracer.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        this.renderPasses.pathTracer.setup();
    }

    public render(): void {
        const gl = this.gl as WebGL2RenderingContext;
        const writeIndex = 1 - this.pingpong;

        gl.bindFramebuffer(gl.FRAMEBUFFER, this.frameBuffer);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.textureConfig.textures[writeIndex], 0);
        gl.bindTexture(gl.TEXTURE_2D, this.textureConfig.textures[this.pingpong]);
        this.renderPasses.pathTracer.draw();

        this.pingpong = writeIndex;

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        this.renderPasses.pathTracer.draw();
    }
}