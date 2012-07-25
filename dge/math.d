/++
Matrices, vectors, and other math stuff
+/

module dge.math;

import std.conv;
public import std.math;
import std.stdio;

import dge.config;
import dge.util.array;

/++
A 3-component vector

To do: optimize
+/
struct Vector3 {

	this()(float x, float y, float z) pure {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	this()(const auto ref float[3] values) {
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
		return sqrt(dot(this, this));
	}

	alias magnitude mag;

	@property float magSquared() const pure {
		return dot(this, this);
	}

	Vector3 normalized() {
		return this / magnitude;
	}

	Vector3 opUnary(string s)() {
		static if(s == "-") {
			Vector3 result = this;
			result.values[] *= -1;
			return result;
		} else {
			static assert(0, `"` ~ s ~ `" is an invalid operator for dge.math.Vector3.opUnary().`);
		}
	}

	Vector3 opBinary(string op: "+")(Vector3 other) const {
		Vector3 result = Vector3(values);
		result.values[] += other.values[];
		return result;
	}

	Vector3 opBinary(string op: "-")(Vector3 other) {
		Vector3 result = Vector3(values);
		result.values[] -= other.values[];
		return result;
	}

	Vector3 opBinary(string op: "*")(Vector3 other) {
		Vector3 result = Vector3(values);
		result.values[] *= other.values[];
		return result;
	}

	Vector3 opBinary(string op: "/")(Vector3 other) {
		Vector3 result = Vector3(values);
		result.values[] /= other.values[];
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

	string toString() const {
		return "(" ~ to!string(x) ~ ", " ~ to!string(y) ~ ", " ~ to!string(z) ~ ")";
	}

	float[3] values;
	@property float* ptr() {return values.ptr;}
}

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

float dot(Vector3 a, Vector3 b) pure {
	Vector3 result = a;
	result.values[] *= b.values[];
	float f = 0;
	foreach(float fv; result.values) {
		f += fv;
	}
	return f;
}

Vector3 cross(Vector3 a, Vector3 b) pure {
	return Vector3(a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x);
}

alias Vector3 Vertex;

alias Vector3 Normal;

/++
A matrix

Elements are stored internally in column-major order to allow interopability with OpenGL; therefore, the
array passed to the constructor will be the transposed version of the desired matrix.
+/

struct Matrix(size_t numRows, size_t numCols) {
	static enum size_t rows = numRows;
	static enum size_t cols = numCols;

	float[numRows][numCols] values;

	@property float* ptr() pure const {
		return cast(float*) values.ptr;
	}

	///Performs a standard matrix multiplication
	Matrix!(rows, OtherMatrix.cols) opBinary(string op: "*", OtherMatrix)(OtherMatrix other) const if(__traits(compiles, OtherMatrix.rows) && cols == OtherMatrix.rows) {
		Matrix!(rows, OtherMatrix.cols) result;
		for(uint i = 0; i < rows; ++i) {
			for(uint j = 0; j < OtherMatrix.cols; ++j) {
				//Do the row-column multiply/add thing:
				float sum = 0;
				foreach(uint n, float v; other.values[j]) {
					sum += v * values[n][i];
				}
				result.values[j][i] = sum;
			}
		}
		return result;
	}

	@property Matrix!(numCols, numRows) transposed() pure const {
		Matrix!(cols, rows) result;
		foreach(size_t colNum, const float[numRows] col; values) {
			foreach(size_t rowNum, float f; col) {
				result.values[rowNum][colNum] = f;
			}
		}
		return result;
	}

	string toString() {
		string text;
		for(size_t row = 0; row < numRows; ++row) {
			for(size_t col = 0; col < numCols - 1; ++col) {
				text ~= to!string(values[col][row]) ~ ", ";
			}
			text ~= to!string(values[numCols - 1][row]);
			text ~= "\n";
		}
		return text;
	}
}

alias Matrix!(4, 4) TransformMatrix;

immutable identityTransform = TransformMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]);

TransformMatrix translationMatrix(Vector3 v) {
	return TransformMatrix([[1f, 0f, 0f, 0f], [0f, 1f, 0f, 0f], [0f, 0f, 1f, 0f], [v.x, v.y, v.z, 1f]]);
}

TransformMatrix rotationMatrix(float x, float y, float z) {
	float sx, cx, sy, cy, sz, cz;
	sx = sin(x);
	cx = cos(x);
	sy = sin(y);
	cy = cos(y);
	sz = sin(z);
	cz = cos(z);
	return TransformMatrix([[cy * cz,					cy * sz,					-sy,		0f],
							[-cx * sz + sx * sy * cz,	cx * cz + sx * sy * sz,		sx * cy,	0f],
							[sx * sz + cx * sy * cz,	-sx * cz + cx * sy * sz,	cx * cy,	0f],
							[0f,						0f,							0f,			1f]]);
}

TransformMatrix scaleMatrix(Vector3 s) {
	return TransformMatrix([[s.x, 0.0, 0.0, 0.0], [0.0, s.y, 0.0, 0.0], [0.0, 0.0, s.z, 0.0], [0.0, 0.0, 0.0, 1.0]]);
}

TransformMatrix perspectiveMatrix(float aspectRatio, float angle, float near, float far) {
	//Width and height of the frustum at the near plane
	float right = near * tan(angle / 2);
	float top = right / aspectRatio;

	float depth = far - near;
	float q = -(far + near) / depth;
	float qn = -2 * (far * near) / depth;

	//For debugging, just return an orthographic projection.
	return scaleMatrix(Vector3(1.0/12.0, 1.0/12.0, 1.0/12.0));
			/+TransformMatrix([[near/right,	0.0,			0.0,	0.0 ],
							[0.0,			near/top,		0.0,	0.0 ],
							[0.0, 			0.0,			q,		-1.0],
							[0.0,			0.0,			qn,		0.0 ]]);+/
}
