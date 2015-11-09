module dge.graphics.shader.types;

import dge.math;

struct GLSLType {
    string glslName;
    TypeInfo dType;
}

enum Types {
    _bool = GLSLType("bool", typeid(bool)),
    _int = GLSLType("int", typeid(int)),
    _uint = GLSLType("uint", typeid(uint)),
    _float = GLSLType("float", typeid(float)),
    matrix4x4 = GLSLType("mat4", typeid(Matrix!(4, 4))),
}
