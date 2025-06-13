import {BaseRenderer} from "./BaseRenderer";
import {RenderPass} from "../../lib/webglutils/RenderPass";
import {pathTracerVSText, RISFSText} from "../Shaders";
import {PathTracer} from "../App";

export default class RISRenderer extends BaseRenderer {
    protected initialize(pathTracer: PathTracer): void {
        this.renderPasses.ris = new RenderPass(this.gl, pathTracerVSText, RISFSText);
        const numIndices = this.setupRayRenderPass(this.renderPasses.ris, pathTracer);
        this.renderPasses.ris.setDrawData(this.gl.TRIANGLES, numIndices, this.gl.UNSIGNED_SHORT, 0);
        this.renderPasses.ris.setup();
    }

    public render(): void {
        this.renderPasses.ris.draw();
    }
}