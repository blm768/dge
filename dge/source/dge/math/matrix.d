/++
Matrices, vectors, and other math stuff
+/
module dge.math.matrix;

import std.conv;
import std.math;

import dge.math.vector;

//import dge.config;

/++
A matrix

Elements are stored internally in column-major order to allow interopability with OpenGL.
+/
struct Matrix(size_t numRows, size_t numCols) {
	static enum size_t rows = numRows;
	static enum size_t cols = numCols;

	this(float[numCols][numRows] data) {
		foreach(size_t rowNum, float[numCols] row; data) {
			foreach(size_t colNum, item; row) {
				values[colNum][rowNum] = item;
			}
		}
	}

	float[numRows][numCols] values;

	ref inout(float) opIndex(size_t row, size_t col) pure inout {
		return values[col][row];
	}

	@property float* ptr() pure const {
		return cast(float*) values.ptr;
	}

	///Performs a standard matrix multiplication
	Matrix!(rows, OtherMatrix.cols) opBinary(string op: "*", OtherMatrix)(OtherMatrix other) const
			if(__traits(compiles, OtherMatrix.rows) && cols == OtherMatrix.rows) {
		Matrix!(rows, OtherMatrix.cols) result;
		foreach(uint i; 0 .. rows) {
			foreach(uint j; 0 .. OtherMatrix.cols) {
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

	Matrix!(Other.rows, Other.cols) opCast(Other)() if(__traits(compiles, Other.rows)) {
		Other result;
		foreach(size_t i, float[numRows] col; values) {
			if(i >= Other.cols)
				break;
			static if(Other.rows < numRows) {
				//To do: issue when const?
				result.values[i][0 .. Other.rows] = col[0 .. Other.rows];
			} else {
				result.values[i][0 .. numRows] = col[0 .. numRows][];
			}
		}
		return result;
	}

	string toString() {
		string[numRows][numCols] text;
		size_t maxWidth;
		for(size_t row = 0; row < numRows; ++row) {
			for(size_t col = 0; col < numCols; ++col) {
				string s = to!string(values[col][row]);
				if(s.length > maxWidth) {
					maxWidth = s.length;
				}
				text[col][row] = s;
			}
		}

		//To do: actually pad string.
		string result;
		foreach(string[numRows] col; text) {
			foreach(string item; col[0 .. $ - 1]) {
				result ~= item;
				result ~= ", ";
			}
			result ~= col[$ - 1];
			result ~= '\n';
		}
		return result;
	}
}

alias Matrix!(4, 4) TransformMatrix;

immutable identityTransform = TransformMatrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]);

TransformMatrix translationMatrix(Vector3 v) {
	return TransformMatrix([[1f, 0f, 0f, v.x], [0f, 1f, 0f, v.y], [0f, 0f, 1f, v.z], [0f, 0f, 0f, 1f]]);
}

TransformMatrix rotationMatrix(float x, float y, float z) {
	float sx, cx, sy, cy, sz, cz;
	sx = sin(x);
	cx = cos(x);
	sy = sin(y);
	cy = cos(y);
	sz = sin(z);
	cz = cos(z);
	return TransformMatrix([[cy * cz,	-cx * sz + sx * sy * cz,	sx * sz + cx * sy * cz,		0f],
							[cy * sz,	cx * cz + sx * sy * sz,		-sx * cz + cx * sy * sz,	0f],
							[-sy,		sx * cy,					cx * cy,					0f],
							[0f,		0f,							0f,							1f]]);
}

TransformMatrix scaleMatrix(Vector3 s ...) {
	return TransformMatrix([[s.x, 0.0, 0.0, 0.0], [0.0, s.y, 0.0, 0.0], [0.0, 0.0, s.z, 0.0], [0.0, 0.0, 0.0, 1.0]]);
}

TransformMatrix perspectiveMatrix(float aspectRatio, float angle, float near, float far) {
	//Width and height of the frustum at the near plane
	float right = near * tan(angle / 2);
	float top = right / aspectRatio;

	float depth = far - near;
	float q = -(far + near) / depth;
	float qn = -2 * (far * near) / depth;

	return TransformMatrix([[near/right,	0.0,			0.0,	0.0 ],
							[0.0,			near/top,		0.0,	0.0 ],
							[0.0, 			0.0,			q,		qn	],
							[0.0,			0.0,			-1.0,	0.0 ]]);
}
