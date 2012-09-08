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
		auto passData = cast(MirrorPassData)(scene.activeCamera.activePass.data);
		assert(passData);

		if(passData.currentMirror is this) {
			return;
		}

		auto camera = scene.activeCamera;
		auto projection = camera.projection;

		//Put the scene at the mirror's world-space origin and undo its rotation.
		auto mirrorTransform =  worldRotation.transposed * translationMatrix(-worldPosition) * camera.worldTransform;
		//Scale the scene.
		mirrorTransform = scaleMatrix(Vector3(1.0, 1.0, -1.0)) * mirrorTransform;
		//Return the scene to its position.
		mirrorTransform = camera.inverseWorldTransform * translationMatrix(worldPosition) * worldRotation * mirrorTransform;

		auto maskProjection = zTransform * projection;

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

		//Render the reflection:
		//To do: set up the clipping plane.

		//Set up the Z-buffer to mask the scene:
		glClearDepth(0);
		glClear(GL_DEPTH_BUFFER_BIT);
		glClearDepth(1);
		//Set up the projection matrix
		camera.projection = maskProjection;
		glDepthFunc(GL_GREATER);
		glColorMask(0, 0, 0, 0);
		mesh.draw(scene, worldTransform, false);
		glDepthFunc(GL_LESS);
		glColorMask(1, 1, 1, 1);

		//Render the reflected objects:
		camera.projection = projection;
		camera.viewPostTransform = mirrorTransform;
		camera.useViewPostTransform = true;
		glFrontFace(GL_CW);

		auto lastMirror = passData.currentMirror;
		passData.currentMirror = this;
		scene.activeCamera.renderSubPass();
		passData.currentMirror = lastMirror;

		glFrontFace(GL_CCW);
		camera.useViewPostTransform = false;

		//To do: reset the clipping plane.

		//Clear the Z-buffer to allow normal drawing of the scene.
		glClear(GL_DEPTH_BUFFER_BIT);

		//Render the mirror surface.
		camera.projection = projection;
		mesh.draw(scene, worldTransform, true);
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

	enum TransformMatrix zTransform = TransformMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 1]]);
}

private immutable mirror = PassInfo("Mirror");
PassId mirrorPass = &mirror;

class MirrorPassData: PassData {
	override void onStartPass() {
		iterations = maxMirrorReflections;
		currentMirror = null;
	}

	///The number of remaining iterations
	size_t iterations;
	///The mirror from which the scene is currently being rendered
	MirrorNode currentMirror;
}
