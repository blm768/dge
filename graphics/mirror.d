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

		auto camera = scene.activeCamera;

		//Put the scene at the mirror's world-space origin and undo its rotation.
		auto mirrorTransform =  worldRotation.transposed * translationMatrix(-worldPosition) * camera.worldTransform;
		//Scale the scene.
		mirrorTransform = scaleMatrix(Vector3(1.0, 1.0, -1.0)) * mirrorTransform;
		//Return the scene to its position.
		mirrorTransform = camera.inverseWorldTransform * translationMatrix(worldPosition) * worldRotation * mirrorTransform;

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

		//Set up the stencil buffer.

		//Render the reflection:
		//To do: set up the clipping plane.
		//Render the mirror to the depth buffer:
		glColorMask(0, 0, 0, 0);
		glDepthMask(false);
		if(pass.iterations == 0) {
			//Set the mirror bit to 0.
			glStencilMask(stencilMask);
			glClearStencil(0);
			glStencilMask(stencilMaskAll);
			glClear(GL_STENCIL_BUFFER_BIT);
			//Ignore the mirror bit so we can draw the mirror.
			glStencilFunc(GL_EQUAL, stencilAccept, ~stencilMask);
		} else {
			glStencilFunc(GL_EQUAL, stencilAccept, stencilMaskAll);
		}
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
		//To do: how to place this in the optimal location for the pipeline?
		glEnable(GL_STENCIL_TEST);
		mesh.draw(scene, worldTransform, false);
		glColorMask(1, 1, 1, 1);
		glDepthMask(true);

		//Render the reflected objects:
		bool usePostTransform = camera.useViewPostTransform;
		auto postTransform = camera.viewPostTransform;
		if(usePostTransform) {
			camera.viewPostTransform = mirrorTransform * camera.viewPostTransform;
		} else {
			camera.viewPostTransform = mirrorTransform;
		}
		camera.useViewPostTransform = true;
		glFrontFace(GL_CW);

		auto lastMirror = pass.currentMirror;
		pass.currentMirror = this;
		++pass.iterations;
		glStencilFunc(GL_EQUAL, stencilAccept, stencilMaskAll);
		scene.activeCamera.renderSubPass();
		--pass.iterations;
		pass.currentMirror = lastMirror;
		glFrontFace(GL_CCW);
		camera.viewPostTransform = postTransform;
		camera.useViewPostTransform = usePostTransform;

		//To do: reset the clipping plane.

		//Clear the Z-buffer to allow normal drawing of the scene.
		glClear(GL_DEPTH_BUFFER_BIT);

		//Render the mirror surface.
		mesh.draw(scene, worldTransform, true);

		if(pass.iterations == 0) {
			glStencilFunc(GL_EQUAL, stencilAccept, ~stencilMask);
		}
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
		iterations = 0;
		currentMirror = null;
	}

	override @property bool shouldDraw() {
		return iterations < maxMirrorReflections;
	}

	///The number of iterations
	size_t iterations;
	///The mirror from which the scene is currently being rendered
	MirrorNode currentMirror;
}
