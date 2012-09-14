/++Hybrid ellipsoid- and capsule-based collision detection
Partially based on "Improved Collision Detection and Response," <www.peroxide.dk/papers/collision/collision.pdf>
+/
module dge.collision;

import dge.graphics.scene;
import dge.math;
import dge.mathext.intersection;

//To do: remove when done.
import std.stdio;

class CollisionObject: NodeGroup {
	this() {}

	this(float heightRadius, float widthRadius) {
		this.heightRadius = heightRadius;
		this.widthRadius = widthRadius;
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

	Vector3 toESpace(Vector3 vec) {
		return worldRotation * ((worldRotation.transposed * vec) / Vector3(widthRadius, heightRadius, widthRadius));
	}

	Vector3 fromESpace(Vector3 vec) {
		return worldRotation * ((worldRotation.transposed * vec) * Vector3(widthRadius, heightRadius, widthRadius));
	}

	//To do: move position tweaking here as well.
	void onCollision(CollisionObstacle obstacle, Vector3 normal) {
		velocity = velocity - normal * dot(velocity, normal);
	}

	float widthRadius, heightRadius;
	Vector3 velocity = Vector3(0f, 0f, 0f);

	protected:
	void handleCollisions() {
		//FloatingPointControl fpctrl;
		//fpctrl.enableExceptions(FloatingPointControl.severeExceptions);
		CollisionResult result;

		size_t recursionDepth = 0;

		void getNewPosition() {
			enum float veryCloseDistance = 0.005;
			if(recursionDepth > 5)
				return;

			result.foundCollision = false;

			checkCollisions(result);

			if(!result.foundCollision) {
				//To do: file a bug; += should either work or not compile.
				position = position + velocity;
				return;
			}

			//Otherwise, there's a collision.
			Vector3 dest = position + velocity;
			Vector3 newBasePoint = position;

			//If we're far enough away, move toward the collision point.
			if(result.nearestDistance >= veryCloseDistance) {
				Vector3 v = velocity.normalized();
				newBasePoint = newBasePoint + (v * (result.nearestDistance - veryCloseDistance));
				result.position = result.position - veryCloseDistance*v;
			}

			//Slide.
			Plane slidingPlane = Plane(result.normal, result.position);

			Vector3 newDest = dest - slidingPlane.signedDistanceTo(dest) * slidingPlane.normal;

			position = newBasePoint;

			onCollision(result.obstacle, slidingPlane.normal);

			//Has the object slowed almost to a stop?
			if(velocity.magnitude < veryCloseDistance) {
				return;
			}

			++recursionDepth;

			getNewPosition();
		}

		getNewPosition();
		//If there's a parent, factor its transformation into the position.
		if(parent !is scene) {
			this.position = parent.inverseWorldTransform * this.position;
		}
	}

	void checkCollisions(ref CollisionResult result) {
		//Input for ellipsoid tests
		CollisionInput eInput;
		eInput.position = toESpace(position);
		eInput.velocity = toESpace(velocity);
		foreach(CollisionObstacle ob; scene.collisionObstacles) {
			checkAgainstObstacle(ob, eInput, result);
		}
		foreach(CollisionObject ob; scene.collisionObjects) {
			//Velocity thing for testing
			if(ob is this || velocity.magnitude < 0.001)
				continue;
			checkAgainstObject(ob, result);
			if(result.foundCollision) {
				//(cast(MeshNode)firstChild).mesh.faceGroups[0].material.diffuse = Color(1, 0, 0);
			}
		}
	}

	void checkAgainstObstacle(CollisionObstacle obstacle, const ref CollisionInput input, ref CollisionResult result) {
		foreach(const Mesh.FaceGroup fg; obstacle.collisionMesh.faceGroups) {
			foreach(const Face f; fg.faces) {
				Vector3[3] vertices;
				foreach(i, vIndex; f.vertices) {
					vertices[i] = obstacle.worldTransform * obstacle.collisionMesh.vertices[vIndex];
				}
				checkAgainstTriangle(obstacle, vertices, input, result);
			}
		}
	}

	//To do: convert results from ellipsoid space.
	void checkAgainstTriangle(CollisionObstacle obstacle, Vector3[3] p, const ref CollisionInput input, ref CollisionResult result) {
		//Convert to ellipsoid space.
		p[0] = toESpace(p[0]);
		p[1] = toESpace(p[1]);
		p[2] = toESpace(p[2]);

		Vector3 position = input.position;
		Vector3 velocity = input.velocity;

		auto plane = Plane(cross(p[1] - p[0], p[2] - p[0]).normalized(), p[0]);

		float nDotVelocity = dot(plane.normal, velocity);

		//Cull tests where object is moving away from the plane.
		if(nDotVelocity > 0) {
			return;
		}
		float planeDist = plane.signedDistanceTo(position);

		//To do: determine if t1 is even needed.
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
			if(t1 < 0f) t1 = 0f;
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
			float distance = t * fromESpace(velocity).magnitude;
			result.registerCollision(fromESpace(collisionPoint + plane.normal), plane.normal, distance, obstacle);
		}
	}

	//Compensate for: radius, relative velocity
	void checkAgainstObject(CollisionObject other, ref CollisionResult result) {
		float halfHeight0 = (heightRadius - widthRadius);
		float halfHeight1 = (other.heightRadius - other.widthRadius);
		float radius0 = widthRadius, radius1 = other.widthRadius;

		//Sweep against the cylindrical section of the capsule.
		float paddedRadius = radius0 + radius1;

		//The time of collision
		float t;

		//The start and direction of the line segment representing the first capsule
		Vector3 segStart = worldPosition;
		Vector3 segDir = worldRotation * Vector3(0, 1, 0);

		//The center and direction of the cylinder
		Vector3 cylStart = other.worldPosition;
		Vector3 cylDir = other.worldRotation * Vector3(0, 1, 0);

		//The velocity of the second object relative to the first
		Vector3 velocity = other.velocity - this.velocity;

		//We pretend to be intersecting a circle and a 2D segment, then generalize it to 3D. Sort of.
		Vector3 cylToSeg = segStart - cylStart;

		//The starting position of the cylinder projected onto the segment
		float startOnSeg = dot(cylToSeg, segDir);
		//Make cylinderToSeg perpendicular to the segment.

		cylToSeg -= segDir * startOnSeg;

		//Flatten the vector along the cylinder's axis.
		Vector3 cylToSegFlat = cylToSeg - cylDir * startOnSeg;
		float distToSeg = cylToSegFlat.magnitude;

		Vector3 dir = cylToSegFlat.normalized;
		float vDotDir = dot(velocity, dir);

		//If vDotDir == 0, we get +-float.infinity, and the next check fails as planned.
		t = distToSeg / vDotDir;

		//Is the collision within this frame?
		if(t > 0 && t <= 1) {
			//Yes; perform a center-center test.
			float endOnSeg = dot(segDir, velocity * t);

			//Is the end position on the segment?
			if(endOnSeg > -halfHeight0 && endOnSeg < halfHeight0) {
				//Equivalent to dot(-velocity * t - cylToSeg; just a little faster.
				float endOnCyl = -dot(velocity * t + cylToSeg, cylDir);

				//Is the collision on the cylinder's center?
				if(endOnCyl > -halfHeight1 && endOnCyl < halfHeight1) {
					//result.registerCollision();
				}
			}

			//Is there a center-end collision?
			int i = -1;
			do {
				//Sweep the endpoints against the first object's center.
				TraceResult tResult = traceAgainstSphere(cylStart + i * cylDir * halfHeight1, dir, segStart + segDir * startOnSeg, paddedRadius);
				if(tResult.foundIntersection) {
					//result.registerCollision(tResult.position - dir * radius1 + segDir * startOnSeg, tResult.distance, other);
				}
				i *= -1;
			} while (i > 0);
		}

		//Test the endpoints:
		Vector3 vNormalized = velocity.normalized();
		int i = -1, j = -1;
		//i and j alternate between positive and negative.
		do {
			do {
				Vector3 center0 = segStart + i * segDir * halfHeight0;
				Vector3 center1 = cylStart + j * cylDir * halfHeight1;
				TraceResult tResult = traceAgainstSphere(center0, -vNormalized, center1, paddedRadius);
				if(tResult.foundIntersection && tResult.distance <= velocity.mag) {
					//result.registerCollision(tResult.position + (center1 - center0).normalized * radius0, tResult.distance, other);
				}
				j *= -1;
			} while (j > 0);
			i *= -1;
		} while (i > 0);
	}
}

struct CollisionResult {
	bool foundCollision;
	float nearestDistance;
	//The position of the object when it collides
	Vector3 position;
	Vector3 normal;
	union {
		CollisionObstacle obstacle;
		CollisionObject object;
	}

	void registerCollision(Vector3 position, Vector3 normal, float distance, CollisionObstacle obstacle) {
		//Is this collision closer than the last one?
		if(!foundCollision || distance < nearestDistance) {
			foundCollision = true;
			nearestDistance = distance;
			this.position = position;
			this.normal = normal;
			this.obstacle = obstacle;
		}
	}

	//To do: integrate with above?
	void registerCollision(Vector3 position, Vector3 normal, float distance, CollisionObject object) {
		//Is this collision closer than the last one?
		if(!foundCollision || distance < nearestDistance) {
			foundCollision = true;
			nearestDistance = distance;
			this.position = position;
			this.normal = normal;
			this.object = object;
		}
	}
}

struct CollisionInput {
	Vector3 position;

	//To do: file enhancement request? (Code using const reference to
	//this object w/o const on the method gives an unhelpful error message.)
	@property Vector3 velocity() const {
		return _velocity;
	}

	@property void velocity(Vector3 value) {
		_velocity = value;
		_normalizedVelocity = value.normalized();
	}

	@property Vector3 normalizedVelocity() const {
		return _normalizedVelocity;
	}

	private:
	Vector3 _velocity, _normalizedVelocity;
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

To reinterpret(To, From)(From from) if(To.sizeof == From.sizeof) {
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

