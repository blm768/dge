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

			float distance = velocity.magnitude * result.t;

			//If we're far enough away, move toward the collision point.
			if(distance >= veryCloseDistance) {
				Vector3 v = velocity.normalized();
				position = position + (v * (distance - veryCloseDistance));
			}

			//Slide.
			//To do: adjust.
			Plane slidingPlane = Plane(result.normal, position);

			//Vector3 newDest = dest - slidingPlane.signedDistanceTo(dest) * slidingPlane.normal;

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

		//writeln(position);
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

	//To do: remove collisionPoint?
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

		//To do: keep t1? (could be moderately useful)
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
			//Normal is already a unit vector.
			result.registerCollision(t, fromESpace(position - collisionPoint).normalized, obstacle);
		}
	}

	//To do: fix clipping on center-center collisions.
	void checkAgainstObject(CollisionObject other, ref CollisionResult result) {
		float halfHeight0 = (heightRadius - widthRadius);
		float halfHeight1 = (other.heightRadius - other.widthRadius);
		float radius0 = widthRadius, radius1 = other.widthRadius;

		//Sweep against the cylindrical section of the capsule.
		float paddedRadius = radius0 + radius1;

		//The time of collision
		//To do: use t0, t1?
		float t;

		//The start and direction of the line segment representing the first capsule
		Vector3 segStart = worldPosition;
		Vector3 segDir = worldRotation * Vector3(0, 1, 0);

		//The center and direction of the cylinder
		Vector3 cylStart = other.worldPosition;
		Vector3 cylDir = other.worldRotation * Vector3(0, 1, 0);

		//The velocity of the second object relative to the first
		Vector3 velocity = other.velocity - this.velocity;

		//To do: center-center collisions

		//Is there a center-end collision?
		int i = -1;
		do {
			//Consolidate multiplications?
			Vector3 end1Start = cylStart + i * cylDir * halfHeight1;
			Vector3 end1StartToSeg = segStart - end1Start;
			float end1StartOnSeg = dot(end1StartToSeg, segDir);
			end1StartToSeg -= end1StartOnSeg * segDir;

			float end1DistToSeg = end1StartToSeg.magnitude;
			Vector3 dir = end1StartToSeg / end1DistToSeg;

			float vDotDir = dot(velocity, dir);

			t = (end1DistToSeg - paddedRadius) / vDotDir;

			if(t > 0 && t <= 1) {
				//To do: consolidate dot products?
				float end1EndOnSeg = end1StartOnSeg + t * dot(velocity, segDir);

				//Is there a collision?
				if(end1EndOnSeg > -halfHeight0 && end1EndOnSeg < halfHeight0) {
					result.registerCollision(t, -dir, other);
				}
			}
			i *= -1;
		} while (i > 0);

		//Is there an end-center collision?
		i = -1;
		do {
			//Consolidate multiplications?
			Vector3 end0Start = segStart + i * segDir * halfHeight0;
			Vector3 end0StartToCyl = cylStart - end0Start;
			float end0StartOnCyl = dot(end0StartToCyl, cylDir);
			end0StartToCyl -= end0StartOnCyl * cylDir;

			float end0DistToCyl = end0StartToCyl.magnitude;
			Vector3 dir = end0StartToCyl / end0DistToCyl;

			float vDotDir = dot(velocity, dir);

			t = (end0DistToCyl - paddedRadius) / vDotDir;

			if(t > 0 && t <= 1) {
				//To do: consolidate dot products?
				float end0EndOnCyl = end0StartOnCyl + t * dot(velocity, cylDir);

				//Is there a collision?
				if(end0EndOnCyl > -halfHeight1 && end0EndOnCyl < halfHeight1) {
					result.registerCollision(t, -dir, other);
				}
			}
			i *= -1;
		} while (i > 0);

		//Test the endpoints:
		Vector3 vNormalized = velocity.normalized();
		i = -1;
		int j = -1;
		//i and j alternate between positive and negative.
		do {
			do {
				Vector3 end0 = segStart + i * segDir * halfHeight0;
				Vector3 end1 = cylStart + j * cylDir * halfHeight1;
				TraceResult tResult = traceAgainstSphere(end0, -vNormalized, end1, paddedRadius);
				if(tResult.foundIntersection && tResult.distance <= velocity.mag) {
					Vector3 normal = (end0 - end1).normalized;
					result.registerCollision(tResult.distance / velocity.mag, normal, other);
				}
				j *= -1;
			} while (j > 0);
			i *= -1;
		} while (i > 0);
	}
}

struct CollisionResult {
	bool foundCollision;
	//The time in the frame that the collision happens
	float t;
	Vector3 normal;
	union {
		CollisionObstacle obstacle;
		CollisionObject object;
	}

	void registerCollision(float t, Vector3 normal, CollisionObstacle obstacle) {
		//Is this collision closer than the last one?
		if(!foundCollision || t < this.t) {
			foundCollision = true;
			this.t = t;
			this.normal = normal;
			this.obstacle = obstacle;
		}
	}

	//To do: integrate with above?
	void registerCollision(float t, Vector3 normal, CollisionObject object) {
		//Is this collision closer than the last one?
		if(!foundCollision || t < this.t) {
			foundCollision = true;
			this.t = t;
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

