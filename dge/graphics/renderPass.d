module dge.graphics.renderPass;

import std.exception;

public import dge.graphics.scene;
public import dge.util.array;


struct PassData {
	alias void function(Scene s, Set!Node layer) DrawFunction;
	string name;
}

alias const(PassData)* RenderPass;

/++ A rendering pass that renders standard opaque objects. +/
private immutable opaque = PassData("Opaque");
RenderPass opaquePass = &opaque;

private immutable transparent = PassData("Transparent");
RenderPass transparentPass = &transparent;
