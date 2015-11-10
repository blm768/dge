module dge.graphics.shader.global;

import dge.graphics.shader.expression;
import dge.graphics.shader.types;

class Global {
    @property string name() const pure;
    @property GLSLType type() const pure;

    @property ShaderExpression expression() {
        //TODO: don't reallocate every time?
        return new GlobalReferenceExpression(this);
    }

    @property string declaration() {
        return type.glslName ~ " " ~ name ~ ";";
    }
}

class GlobalReferenceExpression: ShaderExpression {
    this(Global global) {
        _global = global;
    }

    override @property string code() const pure {
        return _global.name;
    }

    override @property GLSLType type() const pure {
        return _global.type;
    }

    private:
    Global _global;
}

class Uniform: Global {
    override @property string declaration() {
        return "uniform " ~ super.declaration;
    }
}
