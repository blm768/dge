module dge.graphics.renderPass;

import std.exception;

public import dge.graphics.scene;
public import dge.util.array;

abstract class RenderPass {
	void onStartPass() {}
	@property bool shouldDraw() {
		return true;
	}
	@property string name();
}

/++ A rendering pass that renders standard opaque objects. +/
class OpaquePass: RenderPass {
	override @property string name() {
		return "opaque";
	}
}

OpaquePass opaquePass;

class TransparentPass: RenderPass {
	override @property string name() {
		return "transparent";
	}
}

TransparentPass transparentPass;

static this() {
	opaquePass = new OpaquePass;
	transparentPass = new TransparentPass;
}
