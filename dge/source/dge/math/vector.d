module dge.math.vector;

import std.conv;
import std.math;

import dge.math.matrix;

/++
A 3-component vector

TODO: optimize
TODO: use an external math lib?
TODO: allow use of double, etc.?
+/
struct Vector3 {
	alias values this;

	this()(float x, float y, float z) pure {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	this()(const auto ref float[3] values) pure {
		this.values = values;
	}

	@property float x() pure const {
		return values[0];
	}

	@property void x(float x) pure {
		values[0] = x;
	}

	@property float y() pure const {
		return values[1];
	}

	@property void y(float y) pure {
		values[1] = y;
	}

	@property float z() pure const {
		return values[2];
	}

	@property void z(float z) pure {
		values[2] = z;
	}

	@property float magnitude() const pure {
		return sqrt(magSquared);
	}

	alias magnitude mag;

	@property float magSquared() const pure {
		return dot(this, this);
	}

	Vector3 normalized() {
		return this / magnitude;
	}

	Vector3 opUnary(string s: "-")() {
		Vector3 result = this;
		result.values[] *= -1;
		return result;
	}

	void opOpAssign(string op)(Vector3 other) pure {
		foreach(size_t i; 0 .. 3) {
			mixin("values[i] " ~ op ~ "= other.values[i];");
		}
	}

	Vector3 opBinary(string op)(Vector3 other) pure const {
		Vector3 result;
		result.values[] = this.values[];
		result.opOpAssign!op(other);
		return result;
	}

	Vector3 opBinary(string op: "*")(float other) {
		Vector3 result = Vector3(values);
		result.values[] *= other;
		return result;
	}

	Vector3 opBinary(string op: "/")(float other) {
		Vector3 result = Vector3(values);
		result.values[] /= other;
		return result;
	}

	//Handle commutative property of multiplication with a scalar.
	Vector3 opBinaryRight(string op)(float other) {
		return opBinary!op(other);
	}

	//TODO: un-hack.
	//Hack to get DMD to work :)
	alias Matrix!(4, 1) Vec4;
	Vector3 opBinaryRight(string op: "*")(const TransformMatrix m) const {
		Vector3 result;

		Vec4 vec4;
		vec4.values[0][0 .. 3] = values[];
		vec4.values[0][3] = 1;
		result.values[0 .. 3] = (m * vec4).values[0][0 .. 3];
		return result;
	}

	Vector3 opBinaryRight(string op: "*")(const Matrix!(3, 3) m) const {
		Vector3 result;

		Matrix!(3, 1) vec3;
		vec3.values[0][] = values[];
		result.values = (m * vec3).values[0][0 .. 3];
		return result;
	}

	string toString() const {
		return "(" ~ to!string(x) ~ ", " ~ to!string(y) ~ ", " ~ to!string(z) ~ ")";
	}

	float[3] values = [0, 0, 0];
	@property float* ptr() {return values.ptr;}
}

float dot(Vector3 a, Vector3 b) pure {
	Vector3 result = a;
	foreach(size_t i; 0 .. 3) {
		result.values[i] *= b.values[i];
	}
	float f = 0.0;
	foreach(float fv; result.values) {
		f += fv;
	}
	return f;
}

Vector3 cross(Vector3 a, Vector3 b) pure {
	return Vector3(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x);
}

//TODO: move these to Mesh?
alias Vector3 Vertex;
alias Vector3 Normal;
