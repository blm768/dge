module dge.graphics.fbo;

import derelict.opengl3.gl3;

import dge.graphics.material;

enum FramebufferTarget: GLenum {
	all = GL_FRAMEBUFFER,
	read = GL_READ_FRAMEBUFFER,
	draw = GL_DRAW_FRAMEBUFFER
}

enum FramebufferAttachment {
	color0 = GL_COLOR_ATTACHMENT0,
	depth = GL_DEPTH_ATTACHMENT,
	stencil = GL_STENCIL_ATTACHMENT,
	depthAndStencil = GL_DEPTH_STENCIL_ATTACHMENT
}

class Framebuffer {
	this() {
		glGenFramebuffers(1, &_id);
	}

	void bind(FramebufferTarget target = FramebufferTarget.all) {
		glBindFramebuffer(target, id);
	}

	//To do: store target for use w/ unbind()? (Probably not; could cause issues if used carelessly)
	void unbind(FramebufferTarget target = FramebufferTarget.all) {
		glBindFramebuffer(target, 0);
	}

	void attach(Texture2D tex, FramebufferAttachment attachment, FramebufferTarget target = FramebufferTarget.draw) {
		GLuint texId = tex ? tex.id : 0;
		glFramebufferTexture2D(target, attachment, GL_TEXTURE_2D, texId, 0);
	}

	~this() {
		glDeleteFramebuffers(1, &_id);
	}

	@property GLuint id() {
		return _id;
	}

	private:
	GLuint _id;
}
