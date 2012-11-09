module dge.graphics.renderPass;

import std.exception;

public import dge.graphics.scene;
public import dge.util.array;

class RenderPass {
	void onStartPass() {}
	@property bool shouldDraw() {
		return true;
	}
}

/++ A rendering pass that renders standard opaque objects. +/
RenderPass opaquePass;

RenderPass transparentPass;

static this() {
	opaquePass = new RenderPass;
	transparentPass = new RenderPass;
}
