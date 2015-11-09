module dge.graphics.shader.func;

import std.algorithm.iteration;
import std.array;
import std.exception;

import dge.graphics.shader.expression;
import dge.graphics.shader.types;

/++

+/
abstract class ShaderFunction {
    /++
    The function's return type
    +/
    @property GLSLType returnType() const;
    /++
    The function's argument types
    +/
    @property immutable(GLSLType[]) argTypes() const;

    /++
    Returns the GLSL code for the function's definition
    +/
    @property string definition() const;
    /++
    The function's name
    +/
    @property string name() const;

    /++
    Returns a ShaderExpression that represents a call to this function
    with the given arguments
    +/
    ShaderExpression bind(ShaderExpression[] args ...) const {
        return new FunctionCallExpression(this, args);
    }
}

class FunctionCallExpression: ShaderExpression {
    //TODO: validate arg types.
    this(const ShaderFunction func, const(ShaderExpression)[] args) {
        //TODO: better message?
        enforce(args.length == func.argTypes.length, "Lengths of argument lists don't match");

        _func = func;
        _args = args;
    }

    override @property GLSLType type() const {
        return _func.returnType;
    }

    override @property string code() const {
        //TODO: use StringBuilder?
        string code = "(" ~ _func.name ~ "(";
        code ~= _args.map!((arg) => arg.code).join(",");
        code ~= ")";
        return code;
    }

    private:
    const ShaderFunction _func;
    const(ShaderExpression)[] _args;
}
