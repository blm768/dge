/++
Scenegraph objects

To do: use linked-list tree instead of AAs.
+/
module dge.graphics.scene;

import core.exception;
import std.bitmanip;
import std.math;
import std.stdio;

import derelict.opengl3.gl3;

import dge.config;

public import dge.collision;
public import dge.graphics.mesh;
public import dge.graphics.mirror;
public import dge.graphics.renderPass;
import dge.math;
import dge.util.array;
import dge.util.list;

class Scene: NodeGroup {
	this() {
		scene = this;
		parent = this;
	}

	void render() {
		assert(activeCamera, "No active camera");
		activeCamera.render();
		++_currentFrame;
	}

	void addNodeToPass(RenderPass pass, Node n) {
		Set!Node* layer = pass in renderLayers;
		if(!layer) {
			scene.renderLayers[pass] = Set!Node();
			layer = pass in renderLayers;
		}
		layer.add(n);
	}

	void removeNodeFromPass(RenderPass pass, Node n) {
		try {
			renderLayers[pass].remove(n);
		} catch (Error e) {
			throw new Error(`Render pass "` ~ pass.name ~ `" has no associated layer.`);
		}
	}

	Set!Node[RenderPass] renderLayers;

	Color diffuseLight;

	Set!CameraNode cameras;
	Set!LightNode lights;
	CameraNode activeCamera;

	Set!CollisionObject collisionObjects;
	Set!CollisionObstacle collisionObstacles;

	///Incremented each time the scene is rendered; used to synchronize updates
	@property uint currentFrame() {
		return _currentFrame;
	}

	private:
	uint _currentFrame;
}

class NodeGroup: Node {
	public:

	override void draw() {
		foreach(Node n; children) {
			n.draw();
		}
	}

	Node addNode(Node n) {
		if(n.parent !is null)
			throw new Error("Attempt to add a node to more than one parent");
		children.add(n);
		n.parent = this;
		if(scene !is null) {
			n.onAddToScene();
		}
		return n;
	}

	void removeNode(Node n) {
		if(children.contains(n)) {
			if(scene !is null) {
				n.onRemoveFromScene();
			}
			children.remove(n);
			n.parent = null;
		}
	}

	override void update() {
		foreach(Node n; children) {
			n.update();
		}
	}

	override void onAddToScene() {
		super.onAddToScene();
		foreach(Node n; children) {
			n.onAddToScene();
		}
	}

	override void onRemoveFromScene() {
		foreach(Node n; children) {
			n.onRemoveFromScene();
		}
		super.onRemoveFromScene();
	}

	Set!Node children;
}

abstract class Node {
	this() {}

	void draw() {}

	void update() {}

	void onAddToScene() {
		scene = parent.scene;

		//Synchronize with the scene.
		_lastPositionUpdate = scene.currentFrame - 1;
		_lastRotationUpdate = _lastPositionUpdate;
		_lastTransformUpdate = _lastPositionUpdate;
		_lastInverseTransformUpdate = _lastPositionUpdate;
	}

	void onRemoveFromScene() {scene = null;}

	///Returns a matrix representing the node's local transformation
	@property TransformMatrix transform() {
		return translationMatrix(position) * rotation;
	}

	@property TransformMatrix inverseTransform() {
		return rotation.transposed * translationMatrix(-position);
	}

	///Returns a matrix representing the node's world transformation
	@property TransformMatrix worldTransform() {
		if(_lastTransformUpdate != scene.currentFrame) {
			if(parent !is scene) {
				_worldTransform = parent.worldTransform * transform;
			} else {
				_worldTransform = transform;
			}
			_lastTransformUpdate = scene.currentFrame;
		}
		return _worldTransform;
	}

	@property TransformMatrix inverseWorldTransform() {
		if(_lastInverseTransformUpdate != scene.currentFrame) {
			if(parent !is scene) {
				_inverseWorldTransform = inverseTransform * parent.inverseWorldTransform;
			} else {
				_inverseWorldTransform = inverseTransform;
			}
			_lastInverseTransformUpdate = scene.currentFrame;
		}
		return _inverseWorldTransform;
	}

	@property Vector3 worldPosition() {
		if(_lastPositionUpdate != scene.currentFrame) {
			if(parent !is scene) {
				_worldPosition = parent.worldTransform * position;
			} else {
				_worldPosition = position;
			}
			_lastPositionUpdate = scene.currentFrame;
		}
		return _worldPosition;
	}

	@property TransformMatrix worldRotation() {
		if(_lastRotationUpdate != scene.currentFrame) {
			if(parent !is scene) {
				_worldRotation = parent.worldRotation * rotation;
			} else {
				_worldRotation = rotation;
			}
			_lastRotationUpdate = scene.currentFrame;
		}
		return _worldRotation;
	}

	@property Vector3 position() {
		return _position;
	}

	@property void position(Vector3 value) {
		_position = value;
		if(scene) {
			_lastPositionUpdate = _lastTransformUpdate = _lastInverseTransformUpdate = scene.currentFrame - 1;
		}
	}

	@property TransformMatrix rotation() {
		return _rotation;
	}

	@property void rotation(TransformMatrix value) {
		_rotation = value;
		if(scene) {
			_lastRotationUpdate = _lastTransformUpdate = _lastInverseTransformUpdate = scene.currentFrame - 1;
		}
	}

	Node parent;
	Scene scene;

	private:
	Vector3 _position = Vector3(0.0, 0.0, 0.0);
	TransformMatrix _rotation = identityTransform;

	Vector3 _worldPosition;
	uint _lastPositionUpdate;
	TransformMatrix _worldRotation;
	uint _lastRotationUpdate;
	TransformMatrix _worldTransform;
	uint _lastTransformUpdate;
	TransformMatrix _inverseWorldTransform;
	uint _lastInverseTransformUpdate;
}

/++
A camera
+/
class CameraNode: Node {
	///
	this(TransformMatrix projection) {
		this.projection = projection;
		passes = [mirrorPass, opaquePass];
	}

	override void onAddToScene() {
		super.onAddToScene();
		scene.cameras.add(this);
		if(scene.cameras.length == 1) {
			scene.activeCamera = this;
		}
	}

	override void onRemoveFromScene() {
		if(scene.activeCamera == this) {
			scene.activeCamera = null;
		}
		scene.cameras.remove(this);
		super.onRemoveFromScene();
	}

	void render() {
		//Run each rendering pass.
		foreach(RenderPass pass; passes) {
			Set!Node* layer = pass in scene.renderLayers;
			if(layer) {
				activePass = pass;
				foreach(Node n; *layer) {
					n.draw();
				}
			}
		}
	}

	void renderExtended()(RenderPass exception) {
		//Run each rendering pass.
		foreach(RenderPass pass; passes) {
			if(pass == exception)
				continue;
			Set!Node* layer = pass in scene.renderLayers;
			if(layer) {
				activePass = pass;
				foreach(Node n; *layer) {
					n.draw();
				}
			}
		}
	}

	TransformMatrix projection;

	private:
	RenderPass[] passes;
	RenderPass activePass;
}

class MeshNode: Node {
	public:
	this() {}

	this(Mesh mesh) {
		this.mesh = mesh;
	}

	override void draw() {
		mesh.draw(scene, worldTransform, scene.activeCamera.activePass == transparentPass);
	}

	override void onAddToScene() {
		super.onAddToScene();
		scene.addNodeToPass(opaquePass, this);
		scene.addNodeToPass(transparentPass, this);
	}

	override void onRemoveFromScene() {
		scene.removeNodeFromPass(opaquePass, this);
		scene.removeNodeFromPass(transparentPass, this);
		super.onRemoveFromScene();
	}

	Mesh mesh;
}

class AnimatedMeshNode: MeshNode {
	this(AnimatedMesh am) {
		animatedMesh = am;
	}

	override void draw() {
		animatedMesh.draw(scene, worldTransform, action, frame, false);
	}

	override void update() {
		if(animating)
			nextFrame();
	}

	void nextFrame() {
		frame = (frame + 1) % animatedMesh.vertexActions[action].frames.length;
	}

	void startAction(size_t action) {
		this.action = action;
		frame = 0;
	}

	size_t actionByName(const(char)[] name) {
		return animatedMesh.vertexActionLookup[name];
	}

	AnimatedMesh animatedMesh;
	size_t action;
	size_t frame;
	bool animating;
}

class LightNode: Node {
	this(Vector3 position, Color diffuse, Color specular = Color(0.0, 0.0, 0.0, 1.0)) {
		this.position = position;
		this.diffuse = diffuse;
		this.specular = specular;
	}

	override void onAddToScene() {
		super.onAddToScene();
		scene.lights.add(this);
	}

	override void onRemoveFromScene() {
		scene.lights.remove(this);
		super.onRemoveFromScene();
	}

	Color ambient, diffuse, specular;
	Vector3 direction = Vector3(0.0, 0.0, -1.0);
	float spotCutoff = 2.0;
	float quadraticAttenuation = 0.0;
	float spotExponent = 0.0;

	static void setProgramLights(DGEShaderProgram program, Scene scene) {
		//Only actually runs once.
		foreach(LightNode light; scene.lights) {
			setProgramLight(program, light, 0);
			break;
		}
	}

	//To do: make a normal method?
	static void setProgramLight(DGEShaderProgram program, LightNode light, size_t num) {
		program.setUniform(program.matUniforms.lights[num].position, light.worldPosition);
		program.setUniform(program.matUniforms.lights[num].diffuse, light.diffuse);
		program.setUniform(program.matUniforms.lights[num].ambient, light.ambient);
		program.setUniform(program.matUniforms.lights[num].specular, light.specular);

		program.setUniform(program.matUniforms.lights[num].direction, light.worldRotation * light.direction);
		program.setUniform(program.matUniforms.lights[num].spotCutoff, light.spotCutoff);
		program.setUniform(program.matUniforms.lights[num].quadraticAttenuation, light.quadraticAttenuation);
		program.setUniform(program.matUniforms.lights[num].spotExponent, light.spotExponent);
	}
}
