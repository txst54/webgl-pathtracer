// MIS Path Tracer Renderer
import {BaseRenderer} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerFSText, pathTracerVSText} from "../Shaders";
import {PathTracer} from "../App";

export default class MISRenderer extends BaseRenderer {

    protected initialize(pathTracer: PathTracer): void {
        this.frameBuffer = this.gl.createFramebuffer();

        this.renderPasses.pathTracer = new RenderPass(this.gl, pathTracerVSText, pathTracerFSText);
        this.setupPathTracerPass(pathTracer);
        console.log("DONE INITIALIZING");
    }

    private setupPathTracerPass(pathTracer: PathTracer): void {
        console.log("SETTING UP PATH TRACER PASS");
        const numIndices = this.setupRayRenderPass(this.renderPasses.pathTracer, pathTracer);
        this.renderPasses.pathTracer.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        this.renderPasses.pathTracer.setup();
    }

    public render(): void {
        const gl = this.gl as WebGL2RenderingContext;

        gl.bindFramebuffer(gl.FRAMEBUFFER, null);
        this.renderPasses.pathTracer.draw();
    }
}