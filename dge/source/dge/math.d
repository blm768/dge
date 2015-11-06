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
	alias values this;

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

alias Vector3 Vertex;

alias Vector3 Normal;

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

///Eigendecomposition of a 3x3 matrix
void eigenDecomposition(Matrix!(3, 3) matrix, out Matrix!(3, 3) eVecs, out Vector3 eVals) pure {
	Vector3 e;
	eVecs = matrix;
	tred2(eVecs, eVals, e);
	tql2(eVecs, eVals, e);
}

private float hypot2(float x, float y) pure {
  return sqrt(x*x+y*y);
}

// Symmetric tridiagonal QL algorithm.
static void tql2(ref Matrix!(3, 3) V, ref Vector3 d, ref Vector3 e) pure {
	enum size_t n = 3;
//  This is derived from the Algol procedures tql2, by
//  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
//  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
//  Fortran subroutine in EISPACK.

  for (int i = 1; i < n; i++) {
    e[i-1] = e[i];
  }
  e[n-1] = 0.0;

  float f = 0.0;
  float tst1 = 0.0;
  float eps = pow(2.0,-52.0);
  for (int l = 0; l < n; l++) {

    // Find small subdiagonal element

    tst1 = fmax(tst1,abs(d[l]) + abs(e[l]));
    int m = l;
    while (m < n) {
      if (abs(e[m]) <= eps*tst1) {
        break;
      }
      m++;
    }

    // If m == l, d[l] is an eigenvalue,
    // otherwise, iterate.

    if (m > l) {
      int iter = 0;
      do {
        iter = iter + 1;  // (Could check iteration count here.)

        // Compute implicit shift

        float g = d[l];
        float p = (d[l+1] - g) / (2.0 * e[l]);
        float r = hypot2(p,1.0);
        if (p < 0) {
          r = -r;
        }
        d[l] = e[l] / (p + r);
        d[l+1] = e[l] * (p + r);
        float dl1 = d[l+1];
        float h = g - d[l];
        for (int i = l+2; i < n; i++) {
          d[i] -= h;
        }
        f = f + h;

        // Implicit QL transformation.

        p = d[m];
        float c = 1.0;
        float c2 = c;
        float c3 = c;
        float el1 = e[l+1];
        float s = 0.0;
        float s2 = 0.0;
        for (int i = m-1; i >= l; i--) {
          c3 = c2;
          c2 = c;
          s2 = s;
          g = c * e[i];
          h = c * p;
          r = hypot2(p,e[i]);
          e[i+1] = s * r;
          s = e[i] / r;
          c = p / r;
          p = c * d[i] - s * g;
          d[i+1] = h + s * (c * g + s * d[i]);

          // Accumulate transformation.

          for (int k = 0; k < n; k++) {
            h = V[k, i+1];
            V[k, i+1] = s * V[k, i] + c * h;
            V[k, i] = c * V[k, i] - s * h;
          }
        }
        p = -s * s2 * c3 * el1 * e[l] / dl1;
        e[l] = s * p;
        d[l] = c * p;

        // Check for convergence.

      } while (fabs(e[l]) > eps*tst1);
    }
    d[l] = d[l] + f;
    e[l] = 0.0;
  }

  // Sort eigenvalues and corresponding vectors.
  for (int i = 0; i < n-1; i++) {
    int k = i;
    float p = d[i];
    for (int j = i+1; j < n; j++) {
      if (d[j] < p) {
        k = j;
        p = d[j];
      }
    }
    if (k != i) {
      d[k] = d[i];
      d[i] = p;
      for (int j = 0; j < n; j++) {
        p = V[j, i];
        V[j, i] = V[j, k];
        V[j, k] = p;
      }
    }
  }
}

private void tred2(ref Matrix!(3, 3) V, ref Vector3 d, ref Vector3 e) pure {
	enum size_t n = 3;

//  This is derived from the Algol procedures tred2 by
//  Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
//  Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
//  Fortran subroutine in EISPACK.

  for (int j = 0; j < n; j++) {
    d[j] = V[n-1, j];
  }

  // Householder reduction to tridiagonal form.

  for (int i = n-1; i > 0; i--) {

    // Scale to avoid under/overflow.

    float scale = 0.0;
    float h = 0.0;
    for (int k = 0; k < i; k++) {
      scale = scale + abs(d[k]);
    }
    if (scale == 0.0) {
      e[i] = d[i-1];
      for (int j = 0; j < i; j++) {
        d[j] = V[i-1, j];
        V[i, j] = 0.0;
        V[j, i] = 0.0;
      }
    } else {

      // Generate Householder vector.

      for (int k = 0; k < i; k++) {
        d[k] /= scale;
        h += d[k] * d[k];
      }
      float f = d[i-1];
      float g = sqrt(h);
      if (f > 0) {
        g = -g;
      }
      e[i] = scale * g;
      h = h - f * g;
      d[i-1] = f - g;
      for (int j = 0; j < i; j++) {
        e[j] = 0.0;
      }

      // Apply similarity transformation to remaining columns.

      for (int j = 0; j < i; j++) {
        f = d[j];
        V[j, i] = f;
        g = e[j] + V[j, j] * f;
        for (int k = j+1; k <= i-1; k++) {
          g += V[k, j] * d[k];
          e[k] += V[k, j] * f;
        }
        e[j] = g;
      }
      f = 0.0;
      for (int j = 0; j < i; j++) {
        e[j] /= h;
        f += e[j] * d[j];
      }
      float hh = f / (h + h);
      for (int j = 0; j < i; j++) {
        e[j] -= hh * d[j];
      }
      for (int j = 0; j < i; j++) {
        f = d[j];
        g = e[j];
        for (int k = j; k <= i-1; k++) {
          V[k, j] -= (f * e[k] + g * d[k]);
        }
        d[j] = V[i-1, j];
        V[i, j] = 0.0;
      }
    }
    d[i] = h;
  }

  // Accumulate transformations.

  for (int i = 0; i < n-1; i++) {
    V[n-1, i] = V[i, i];
    V[i, i] = 1.0;
    float h = d[i+1];
    if (h != 0.0) {
      for (int k = 0; k <= i; k++) {
        d[k] = V[k, i+1] / h;
      }
      for (int j = 0; j <= i; j++) {
        float g = 0.0;
        for (int k = 0; k <= i; k++) {
          g += V[k, i+1] * V[k, j];
        }
        for (int k = 0; k <= i; k++) {
          V[k, j] -= g * d[k];
        }
      }
    }
    for (int k = 0; k <= i; k++) {
      V[k, i+1] = 0.0;
    }
  }
  for (int j = 0; j < n; j++) {
    d[j] = V[n-1, j];
    V[n-1, j] = 0.0;
  }
  V[n-1, n-1] = 1.0;
  e[0] = 0.0;
}
