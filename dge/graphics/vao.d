module dge.graphics.vao;

import derelict.opengl3.gl3;

import std.stdio;

import std.conv;

class VAO {
	this() {
		glGenVertexArrays(1, &id);
    }

	void bind() {
		glBindVertexArray(id);
	}

	~this() {
		glDeleteVertexArrays(1, &id);
	}

	private:
	uint id;
}

struct AttributeArray {
	this(int elementsPerVertex, GLenum elementType = GL_FLOAT) {
		glGenBuffers(1, &id);
		this.elementType = elementType;
		this.elementsPerVertex = elementsPerVertex;
		setData([]);
	}

	void bind() {
		glBindBuffer(GL_ARRAY_BUFFER, id);
	}

	@property void bindToAttribute(int attNum) {
		attributeNum = attNum;
		if(attNum > -1) {
			bind();
			glVertexAttribPointer(attributeNum, elementsPerVertex, elementType, GL_FALSE, 0, null);
		}
	}

	void setData(T)(T[] data) {
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

    ~this() {
        disable();
        glDeleteBuffers(1, &id);
    }

    private:
    uint id;
    int attributeNum;
	uint elementType;
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
