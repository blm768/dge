module dge.graphics.shader.expression;

import dge.graphics.shader.types;

abstract class ShaderExpression {
    @property GLSLType type() const;
    @property string code() const;
}

version(none) {
    //TODO: figure out how to handle the fact that we don't always know the correct return type.
    class PostfixOperatorExpression: ShaderExpression {
        this(ShaderExpression operand) {
            _operand = operand;
            _operator = _operator;
        }

        private:
        const ShaderExpression _operand;
        string _operator;
    }
}
