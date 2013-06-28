/++
Real-time planar mirrors
+/

module dge.graphics.mirror;

import derelict.opengl3.gl3;

import std.stdio;

import dge.config;
import dge.graphics.mesh;
import dge.graphics.renderPass;
import dge.graphics.scene;

//To do: use sfail to update stencil buffer? Disable some depth tests?
class MirrorNode: Node {
	this(Mesh m) {
		mesh = m;
	}
	/++
	To do: optimize repeated worldTransform() accesses?
	+/
	override void draw() {
		//To do: eliminate dynamic cast?
		auto pass = cast(MirrorPass)scene.activeCamera.activePass;
		assert(pass);

		if(pass.currentMirror is this) {
			return;
		}
		
		//If we're not reflecting, just draw the surface.
		if(pass.depth == maxMirrorReflections) {
			mesh.draw(scene, worldTransform, false);
			return;
		}

		auto camera = scene.activeCamera;

		//Put the scene at the mirror's world-space origin and undo its rotation.
		auto mirrorTransform =  worldRotation.transposed * translationMatrix(-worldPosition);
		//Flip the scene.
		mirrorTransform = scaleMatrix(Vector3(1.0, 1.0, -1.0)) * mirrorTransform;
		//Return the scene to its position.
		mirrorTransform = translationMatrix(worldPosition) * worldRotation * mirrorTransform;

		GLdouble[4] planeValues;
		Vector3 normal = worldRotation * Vector3(0, 0, 1);
		GLdouble d = -dot(normal, worldPosition);
		if(dot(normal, camera.worldPosition) + d < 0) {
			normal = -normal;
			d = -d;
		}
		foreach(size_t i, GLfloat v; normal.values) {
			planeValues[i] = v;
		}
		planeValues[3] = d;
		
		//To do: move? add glDisable?
		glEnable(GL_STENCIL_TEST);

		//Render the reflection:
		
		//To do: set up the clipping plane.
		//Render the mirror to the stencil buffer and clear the depth buffer to 1.0 under it:
		glColorMask(0, 0, 0, 0);
		if(pass.depth == 0) {
			//Set the mirror bits to 0.
			//To do: fix.
			glStencilMask(stencilMaskAll);
			glClearStencil(0);
			glClear(GL_STENCIL_BUFFER_BIT);
			glStencilMask(stencilMaskAll);
			glStencilFunc(GL_ALWAYS, 0, 0);
		} else {
			glStencilFunc(GL_EQUAL, cast(GLint)pass.depth, stencilMaskAll);
		}
		glDepthRange(1.0, 1.0);
		glStencilOp(GL_KEEP, GL_KEEP, GL_INCR);
		//To do: how to place this in the optimal location for the pipeline?
		mesh.draw(scene, worldTransform, false);
		glColorMask(1, 1, 1, 1);
		glDepthRange(0.0, 1.0);

		//Push data.
		bool usePreTransform = camera.usePreTransform;
		auto preTransform = camera.preTransform;
		if(usePreTransform) {
			camera.preTransform = mirrorTransform * camera.preTransform;
		} else {
			camera.preTransform = mirrorTransform;
		}
		camera.usePreTransform = true;
		glFrontFace(GL_CW);
		auto lastMirror = pass.currentMirror;
		pass.currentMirror = this;
		++pass.depth;
		
		//Render.
		glStencilFunc(GL_EQUAL, cast(GLint)pass.depth, stencilMaskAll);
		scene.activeCamera.renderSubPass();
		
		//Pop data.
		--pass.depth;
		pass.currentMirror = lastMirror;
		glFrontFace(GL_CCW);
		camera.preTransform = preTransform;
		camera.usePreTransform = usePreTransform;

		//To do: reset the clipping plane.

		//Render the mirror surface, decrementing the stencil value to undo our changes to the stencil buffer.
		if(true || pass.depth == 0) {
			glStencilFunc(GL_ALWAYS, 0, 0);
		} else {
			glStencilFunc(GL_EQUAL, cast(GLint)pass.depth, stencilMaskAll);
		}
		glStencilOp(GL_KEEP, GL_KEEP, GL_DECR);
		mesh.draw(scene, worldTransform, true);

		//To do: reset stencil?
	}

	override void onAddToScene() {
		super.onAddToScene();
		scene.addNodeToPass(mirrorPass, this);
	}

	override void onRemoveFromScene() {
		scene.removeNodeFromPass(mirrorPass, this);
		super.onRemoveFromScene();
	}

	Mesh mesh;

	//enum TransformMatrix zTransform = TransformMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 1]]);

	enum GLuint stencilMask = 1;
}

RenderPass mirrorPass;

static this() {
	mirrorPass = new MirrorPass;
}

class MirrorPass: RenderPass {
	override @property string name() {
		return "mirror";
	}

	override void onStartPass() {
		depth = 0;
		currentMirror = null;
	}

	override @property bool shouldDraw() {
		return depth < maxMirrorReflections;
	}

	///The depth of the reflection (0 = first reflection, 1 = reflection in first reflection, etc.)
	size_t depth;
	///The mirror from which the scene is currently being rendered
	MirrorNode currentMirror;
}
