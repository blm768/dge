module dge.math.plane;

public import dge.math.vector;

struct Plane {
	Vector3 normal;
	float d;

	this(Vector3 normal, Vector3 pos) {
		this.normal = normal;
		d = -dot(normal, pos);
	}

	float signedDistanceTo(Vector3 pos) {
		return dot(normal, pos) + d;
	}
}
