/++
Scenegraph objects
+/
module dge.graphics.scene;

import core.exception;
//import std.bitmanip;
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

/++
A scene containing meshes, cameras, etc.
+/
class Scene: NodeGroup {
	///
	this() {
		_scene = this;
		_parent = this;
	}

	/++
	Renders the scene from the viewpoint of the active camera
	+/
	void render() {
		assert(activeCamera, "No active camera");
		activeCamera.render();
		++_currentFrame;
	}

	/++
	Adds a node to a rendering pass
	+/
	void addNodeToPass(RenderPass pass, Node n) {
		Set!Node* layer = pass in renderLayers;
		if(!layer) {
			scene.renderLayers[pass] = Set!Node();
			layer = pass in renderLayers;
		}
		layer.add(n);
	}

	/++
	Removes a node from a rendering pass
	+/
	void removeNodeFromPass(RenderPass pass, Node n) {
		try {
			renderLayers[pass].remove(n);
		} catch (Error e) {
			throw new Error(`Render pass "` ~ pass.toString ~ `" has no associated layer.`);
		}
	}

	Set!Node[RenderPass] renderLayers;

	Color diffuseLight;

	///
	Set!CameraNode cameras;
	///
	Set!LightNode lights;
	///
	CameraNode activeCamera;

	///
	Set!CollisionObject collisionObjects;
	///
	Set!CollisionObstacle collisionObstacles;

	///Incremented each time the scene is rendered; used to synchronize updates
	@property uint currentFrame() {
		return _currentFrame;
	}

	private:
	uint _currentFrame;
}

/++
A node containing child nodes
+/
class NodeGroup: Node {
	public:
	/++
	Draws the node's children
	+/
	override void draw() {
		foreach(Node n; children) {
			n.draw();
		}
	}

	///
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

	void onAddChild(Node child) {
		if(scene) {
			child.onAddToScene();
		}
	}
	void onRemoveChild(Node child) {
		if(scene) {
			child.onRemoveFromScene();
		}
	}

	mixin parentNode!(Node, true);
}

/++
A scenegraph node
+/
abstract class Node {
	this() {}

	/++
	Draws the node
	+/
	void draw() {}

	/++
	Updates the node
	+/
	void update() {}

	/++
	Called when the node is added to a NodeGroup
	+/
	void onAdd () {}
	/++
	Called when the node is removed from a NodeGroup
	+/
	void onRemove() {}

	/++
	Called when the node is added to the scene
	+/
	void onAddToScene() {
		_scene = parent.scene;

		//Synchronize with the scene.
		_lastPositionUpdate = scene.currentFrame - 1;
		_lastRotationUpdate = _lastPositionUpdate;
		_lastTransformUpdate = _lastPositionUpdate;
		_lastInverseTransformUpdate = _lastPositionUpdate;
	}

	/++
	Called when the node is removed from the scene
	+/
	void onRemoveFromScene() {_scene = null;}

	///The node's local transformation
	@property TransformMatrix transform() {
		return translationMatrix(position) * rotation;
	}

	///The node's inverse local transformation
	@property TransformMatrix inverseTransform() {
		return rotation.transposed * translationMatrix(-position);
	}

	/++
	Returns a matrix representing the node's world transformation
	Warning: world transform properties may not respond to changes in the parents' transforms until the next frame.
	+/
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

	///
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

	///
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

	///
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

	///
	@property Vector3 position() const {
		return _position;
	}

	///
	@property void position(Vector3 value) {
		_position = value;
		if(scene) {
			_lastPositionUpdate = _lastTransformUpdate = _lastInverseTransformUpdate = scene.currentFrame - 1;
		}
	}

	///
	@property TransformMatrix rotation() const {
		return _rotation;
	}

	///
	@property void rotation(TransformMatrix value) {
		_rotation = value;
		if(scene) {
			_lastRotationUpdate = _lastTransformUpdate = _lastInverseTransformUpdate = scene.currentFrame - 1;
		}
	}

	mixin childNode!(NodeGroup, true);
	mixin commonNode!(NodeGroup, Node);

	@property Scene scene() {
		return _scene;
	}

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

	Scene _scene;
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

	///Renders the scene
	void render() {
		setUpPasses();
		renderSubPass();
	}

	///Renders the scene without re-initializing pass data; used for recursive rendering methods
	void renderSubPass()() {
		//Run each rendering pass.
		foreach(RenderPass pass; passes) {
			if(pass.shouldDraw) {
				Set!Node* layer = pass in scene.renderLayers;
				if(layer) {
					_activePass = pass;
					writeln(_activePass);
					writeln(*layer);
					foreach(Node n; *layer) {
						writeln(n);
						n.draw();
					}
				}
			}
		}
	}

	///
	@property RenderPass activePass() {
		return _activePass;
	}

	/++
	The view matrix
	+/
	@property TransformMatrix view() {
		if(useViewPostTransform) {
			return viewPostTransform * inverseWorldTransform;
		} else {
			return inverseWorldTransform;
		}
	}

	///The projection matrix
	TransformMatrix projection;

	///Applied to objects after the viewing transform if useViewPostTransform is set
	TransformMatrix viewPostTransform;
	///
	bool useViewPostTransform;

	private:
	void setUpPasses() {
		foreach(RenderPass pass; passes) {
			pass.onStartPass();
		}
	}
	RenderPass[] passes;
	RenderPass _activePass;
}

/++
A node that draws a mesh
+/
class MeshNode: Node {
	public:
	this() {}

	this(Mesh mesh) {
		this.mesh = mesh;
	}

	override void draw() {
		mesh.draw(scene, worldTransform, scene.activeCamera.activePass is transparentPass);
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

/++
A node that draws an animated mesh
+/
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

	/++
	Moves to the next frame of animation
	+/
	void nextFrame() {
		frame = (frame + 1) % animatedMesh.vertexActions[action].frames.length;
	}

	/++
	Switches to the first frame of the given action
	+/
	void startAction(size_t action) {
		this.action = action;
		frame = 0;
	}

	///
	size_t actionByName(const(char)[] name) {
		return animatedMesh.vertexActionLookup[name];
	}

	AnimatedMesh animatedMesh;
	size_t action;
	size_t frame;
	bool animating;
}

///
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

	///
	Color ambient, diffuse, specular;
	///
	Vector3 direction = Vector3(0.0, 0.0, -1.0);
	///
	float spotCutoff = 2.0;
	///
	float quadraticAttenuation = 0.0;
	///
	float spotExponent = 0.0;

	/++
	Sets up lights for a program

	To do: move to the program?
	+/
	static void setProgramLights(DGEShaderProgram program, Scene scene) {
		size_t i = 0;
		foreach(LightNode light; scene.lights) {
			setProgramLight(program, light, i);
			++i;
			if(i >= maxLightsPerObject)
				break;
		}
		program.setUniform(program.matUniforms.numLights, cast(int)i);
	}

	//To do: make a normal method? Move to program?
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
