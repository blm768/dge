/++Ellipsoid/mesh collision
Based on "Improved Collision Detection and Response," <www.peroxide.dk/papers/collision/collision.pdf>
+/
module dge.collision;

import dge.graphics.scene;
import dge.math;

//To do: remove when done.
import std.stdio;

class CollisionObject: NodeGroup {
	this(Vector3 ellipsoidRadius) {
		this.ellipsoidRadius = ellipsoidRadius;
	}

	override void onAddToScene() {
		super.onAddToScene();
		scene.collisionObjects.add(this);
	}

	override void onRemoveFromScene() {
		scene.collisionObjects.remove(this);
		super.onRemoveFromScene();
	}

	override void update() {
		//Update children.
		super.update();
		handleCollisions();
	}

	void onCollision(CollisionObstacle other) {}

	protected:
	void handleCollisions() {
		CollisionInput input;
		CollisionResult result;

		size_t recursionDepth = 0;

		//Will be set by newPosition()
		Vector3 newVelocity;
		bool hasNewVelocity;

		Vector3 newPosition(Vector3 position, Vector3 velocity) {
			enum float veryCloseDistance = 0.005;
			if(recursionDepth > 5)
				return input.position;

			input.velocity = velocity;
			input.normalizedVelocity = velocity.normalized();
			input.position = position;
			result.foundCollision = false;

			checkCollisions(input, result);

			if(!result.foundCollision)
				return position + velocity;

			//Otherwise, there's a collision.
			Vector3 dest = position + velocity;
			Vector3 newBasePoint = position;

			//If we're far enough away, move toward the collision point.
			if(result.nearestDistance >= veryCloseDistance) {
				Vector3 v = velocity.normalized();
				newBasePoint = position + (v * (result.nearestDistance - veryCloseDistance));
				result.collisionPoint = result.collisionPoint - veryCloseDistance*v;
			}

			//Slide.
			Vector3 slidePlaneOrigin = result.collisionPoint;
			Vector3 slidePlaneNormal = (newBasePoint - result.collisionPoint).normalized();
			Plane slidingPlane = Plane(slidePlaneNormal, slidePlaneOrigin);

			Vector3 newDest = dest - slidingPlane.signedDistanceTo(dest) * slidePlaneNormal;
			//Declared in containing function
			newVelocity = newDest - result.collisionPoint;
			hasNewVelocity = true;

			if(newVelocity.magnitude < veryCloseDistance) {
				return newBasePoint;
			}

			++recursionDepth;
			return newPosition(newBasePoint, newVelocity);
		}

		Vector3 eSpacePos = worldPosition / ellipsoidRadius;
		Vector3 eSpaceV = worldRotation * this.velocity / ellipsoidRadius;

		this.position = newPosition(eSpacePos, eSpaceV) * ellipsoidRadius;
		if(hasNewVelocity) this.velocity = newVelocity * ellipsoidRadius;
	}

	void checkCollisions(const ref CollisionInput input, ref CollisionResult result) {
		foreach(CollisionObstacle ob; scene.collisionObstacles) {
			checkAgainstObject(ob, input, result);
		}
	}

	void checkAgainstObject(CollisionObstacle obstacle, const ref CollisionInput input, ref CollisionResult lastCollision) {
		foreach(const Mesh.FaceGroup fg; obstacle.collisionMesh.faceGroups) {
			foreach(const Face f; fg.faces) {
				Vector3[3] vertices;
				foreach(i, vIndex; f.vertices) {
					vertices[i] = obstacle.worldTransform * obstacle.collisionMesh.vertices[vIndex];
				}
				checkAgainstTriangle(vertices, input, lastCollision);
			}
		}
	}

	void checkAgainstTriangle(Vector3[3] p, const ref CollisionInput input, ref CollisionResult lastCollision) {
		//Convert to ellipsoid space.
		p[0] = p[0] / ellipsoidRadius;
		p[1] = p[1] / ellipsoidRadius;
		p[2] = p[2] / ellipsoidRadius;

		Vector3 position = input.position;
		Vector3 velocity = input.velocity;

		auto plane = Plane(cross(p[1] - p[0], p[2] - p[0]).normalized(), p[0]);
		//To do: check for back-facing planes.
		float nDotVelocity = dot(plane.normal, velocity);
		float planeDist = plane.signedDistanceTo(position);

		float t0, t1;
		bool embeddedInPlane;

		//Moving parallel to plane?
		if(nDotVelocity == 0f) {
			//Is sphere embedded?
			if(abs(planeDist) >= 1f) {
				//Nope.
				return;
			} else {
				//The collision lasts the entire frame.
				embeddedInPlane = true;
				t0 = 0f;
				t1 = 1f;
			}
		} else {
			t0 = (-1f - planeDist) / nDotVelocity;
			t1 = (1f - planeDist) / nDotVelocity;

			if(t0 > t1) {
				float tmp = t1;
				t1 = t0;
				t0 = tmp;
			}

			//Is the anticipated collision time in this frame?
			if(t0 > 1f || t1 < 0f) return;

			//Clamp values.
			if(t0 < 0f) t0 = 0f;
			if(t1 < 0f) t0 = 0f;
			if(t0 > 1f) t0 = 1f;
			if(t1 > 1f) t1 = 1f;
		}

		Vector3 collisionPoint;
		bool foundCollision;
		float t = 1f;

		if(!embeddedInPlane) {
			Vector3 planeIntersection = position - plane.normal + t0 * velocity;

			if(pointIsInTriangle(planeIntersection, p[0], p[1], p[2])) {
				foundCollision = true;
				t = t0;
				collisionPoint = planeIntersection;
			}
		}

		//If needed, perform sweep tests.
		if(!foundCollision) {
			float vSquared = velocity.magSquared;
			float a, b, c;
			float newT;

			//Point sweep:
			a = vSquared;

			foreach(Vector3 point; p) {
				b = 2.0 * dot(velocity, position - point);
				c = (point - position).magSquared - 1.0;
				newT = lowestRoot(a, b, c, t);

				if(!isNaN(newT)) {
					t = newT;
					foundCollision = true;
					collisionPoint = point;
				}
			}

			void checkEdge(Vector3 p1, Vector3 p2) {
				Vector3 edge = p2 - p1;
				Vector3 posToVertex = p1 - position;
				float edgeSquaredLength = edge.magSquared;
				float edgeDotV = dot(edge, velocity);
				float edgeDotPosToVertex = dot(edge, posToVertex);
				float a, b, c;

				a = edgeSquaredLength * -vSquared + edgeDotV*edgeDotV;
				b = edgeSquaredLength * (2.0 * dot(velocity, posToVertex)) - 2.0 * edgeDotV * edgeDotPosToVertex;
				c = edgeSquaredLength * (1 - posToVertex.magSquared()) + edgeDotPosToVertex * edgeDotPosToVertex;

				newT = lowestRoot(a, b, c, t);
				if(!isNaN(newT)) {
					//Is the intersection within the segment?
					float f = (edgeDotV * newT - edgeDotPosToVertex) / edgeSquaredLength;
					if(f >= 0.0 && f <= 1.0) {
						t = newT;
						foundCollision = true;
						collisionPoint = p1 + f * edge;
					}
				}
			}

			checkEdge(p[0], p[1]);
			checkEdge(p[1], p[2]);
			checkEdge(p[2], p[0]);
		}

		if(foundCollision) {
			float distance = t * velocity.magnitude;

			//Is this collision closer than the last one?
			if(!lastCollision.foundCollision || distance < lastCollision.nearestDistance) {
				lastCollision.foundCollision = true;
				lastCollision.nearestDistance = distance;
				lastCollision.collisionPoint = collisionPoint;
			}
		}
	}

	Vector3 ellipsoidRadius;
	Vector3 velocity = Vector3(0f, 0f, 0f);
}

struct CollisionResult {
	bool foundCollision;
	float nearestDistance;
	Vector3 collisionPoint;
}

struct CollisionInput {
	Vector3 position, velocity, normalizedVelocity;
}

class CollisionObstacle: NodeGroup {
	override void onAddToScene() {
		super.onAddToScene();
		scene.collisionObstacles.add(this);
	}

	override void onRemoveFromScene() {
		scene.collisionObstacles.remove(this);
		super.onRemoveFromScene();
	}

	Mesh collisionMesh;
}

bool pointIsInTriangle(Vector3 point, Vector3 pa, Vector3 pb, Vector3 pc) pure {
	auto e10 = pb - pa;
	auto e20 = pc - pa;

	float a = dot(e10, e10);
	float b = dot(e10, e20);
	float c = dot(e20, e20);
	//Is this needed?
	float ac_bb = a*c - b*b;
	auto vp = point - pa;

	float d = dot(vp, e10);
	float e = dot(vp, e20);
	float x = d*c - e*b;
	float y = e*a - d*b;
	float z = x + y - ac_bb;

	return ((reinterpret!uint(z) & ~(reinterpret!int(x) | reinterpret!int(y))) & 0x80000000) != 0;
}

To reinterpret(To, From)(From from) if(To.sizeof == From.sizeof){
	return *(cast(To*)&from);
}

float lowestRoot(float a, float b, float c, float maxR) {
	float det = b*b - 4*a*c;

	if(det < 0.0) return float.nan;

	float sqrtD = sqrt(det);
	float r1 = (-b - sqrtD) / (2*a);
	float r2 = (-b + sqrtD) / (2*a);

	if(r1 > r2) {
		float tmp = r2;
		r2 = r1;
		r1 = tmp;
	}

	if(r1 > 0 && r1 < maxR)
		return r1;

	if(r2 > 0 && r2 < maxR)
		return r2;

	return float.nan;
}
