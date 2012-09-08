module dge.graphics.renderPass;

import std.exception;

public import dge.graphics.scene;
public import dge.util.array;


struct PassInfo {
	string name;
}

alias immutable(PassInfo)* PassId;

abstract class PassData {
	void onStartPass();
}

struct RenderPass {
	PassId id;
	PassData data;
}

/++ A rendering pass that renders standard opaque objects. +/
private immutable opaque = PassInfo("Opaque");
PassId opaquePass = &opaque;

private immutable transparent = PassInfo("Transparent");
PassId transparentPass = &transparent;
