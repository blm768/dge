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

	override void draw() {
		/++
		GLdouble[4] planeValues;
		Vector3 normal = worldRotation * Vector3(0, 0, 1);
		GLdouble d = -dot(normal, worldPosition);
		if(dot(normal, scene.activeCamera.worldPosition) + d < 0) {
			normal = -normal;
			d = -d;
		}
		foreach(size_t i, GLfloat v; normal.values) {
			planeValues[i] = v;
		}
		planeValues[3] = d;

		//Render the reflection:
		//Set up the clipping plane.
		//glEnable(GL_CLIP_PLANE0);
		glClipPlane(GL_CLIP_PLANE0, cast(GLdouble*)planeValues.ptr);

		//Set up the Z-buffer to mask the scene:
		glPushMatrix();
			//To do: optimize.
			//Point for optimization here; we're doing the mirror's transformation twice.
			glPushMatrix();
				glMultMatrixf(worldTransform.ptr);
				glClearDepth(0);
				glClear(GL_DEPTH_BUFFER_BIT);
				glClearDepth(1);
				//Set up the projection matrix
				glMatrixMode(GL_PROJECTION);
				TransformMatrix projection = projectionMatrix();
				glLoadMatrixf(zTransform.ptr);
				glMultMatrixf(projection.ptr);
				glDepthFunc(GL_GREATER);
				glColorMask(0, 0, 0, 0);
				mesh.draw();
				glDepthFunc(GL_LESS);
				glColorMask(1, 1, 1, 1);
				glLoadMatrixf(projection.ptr);
				glMatrixMode(GL_MODELVIEW);
			glPopMatrix();

			//Render the reflected objects:
			glPushMatrix();
				TransformMatrix mirrorMatrix = translationMatrix(-worldPosition);
				mirrorMatrix = worldRotation * scaleMatrix(Vector3(1.0, 1.0, -1.0)) * worldRotation.transposed * mirrorMatrix;
				mirrorMatrix = translationMatrix(worldPosition) * mirrorMatrix;
				glMultMatrixf(mirrorMatrix.ptr);
				glFrontFace(GL_CW);
				scene.activeCamera.renderExtended(Set!RenderPass(mirrorPass), false);
				glFrontFace(GL_CCW);
			glPopMatrix();

			//Reset the clipping plane.
			glDisable(GL_CLIP_PLANE0);

			//Clear the Z-buffer to allow normal drawing of the scene.
			glClear(GL_DEPTH_BUFFER_BIT);

			//Render the mirror surface.
			glMultMatrixf(worldTransform.ptr);
			mesh.draw();
		glPopMatrix();
		+/
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

	enum TransformMatrix zTransform = TransformMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 0], [0, 0, 1, 1]]);
}

private immutable mirror = PassData("Mirror");
RenderPass mirrorPass = &mirror;
