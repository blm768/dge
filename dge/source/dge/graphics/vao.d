module dge.graphics.vao;

import derelict.opengl3.gl3;

import std.stdio;

import std.conv;

struct VAO {
	@disable this();

	private this(uint id) {
		this.id = id;
	}

	@disable this(this);

	static VAO create() {
		uint id;
		glGenVertexArrays(1, &id);
		return VAO(id);
    }

	void bind() {
		glBindVertexArray(id);
	}

	void unbind() {
		glBindVertexArray(0);
	}

	void dispose() {
		glDeleteVertexArrays(1, &id);
	}

	~this() {
		dispose();
	}

	private:
	uint id;
}

/++
TODO: abstract the buffer into its own object?
+/
struct AttributeArray {
	this(int elementsPerVertex, GLenum elementType, size_t elementSize) {
		glGenBuffers(1, &id);
		this.elementType = elementType;
		this.elementSize = elementSize;
		this.elementsPerVertex = elementsPerVertex;
		setData([]);
	}

	///AttributeArray objecs should not be copied.
	//TODO: implement some kind of ref-counting instead?
	@disable this(this);

	void bind() {
		glBindBuffer(GL_ARRAY_BUFFER, id);
	}

	void unbind() {
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	@property void bindToAttribute(int attNum) {
		attributeNum = attNum;
		if(attNum > -1) {
			bind();
			glVertexAttribPointer(attributeNum, elementsPerVertex, elementType, GL_FALSE, cast(int)elementSize, null);
		}
	}

	void setData(T)(const(T)[] data) {
		bind();
		glBufferData(GL_ARRAY_BUFFER, data.length * T.sizeof, data.ptr, GL_STATIC_DRAW);
	}

	/++
	Enables the shader attribute that this represents

	This must be called $(em, after) bindToAttribute() in order to work.

	To do:
	Throw error instead of eating unbound attributes?
	+/
	void enable() {
		if(attributeNum > -1) {
			glEnableVertexAttribArray(attributeNum);
		}
	}

	void disable() {
		if(attributeNum > -1) {
			glDisableVertexAttribArray(attributeNum);
		}
	}

	void dispose() {
		disable();
		glDeleteBuffers(1, &id);
		id = 0;
	}

    ~this() {
		dispose();
    }

    private:
    uint id;
    int attributeNum = -1;
	uint elementType;
	size_t elementSize;
	int elementsPerVertex;
}

struct ElementArray {
	this(GLenum elementType) {
		this.elementType = elementType;
		glGenBuffers(1, &id);
		setData([]);
	}

	void bind() {
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, id);
	}

	void setData(T)(T[] data) {
		bind();
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.length * T.sizeof, data.ptr, GL_STATIC_DRAW);
	}

	private:
	uint id;
	uint elementType;
}
