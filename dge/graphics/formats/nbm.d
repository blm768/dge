/**
Handles the NBTMesh format
*/

module dge.graphics.formats.nbm;

import core.exception;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.stdio;
import std.stream;
import std.string;
import std.zlib;
import etc.c.zlib;

import derelict.opengl3.gl3;

import dge.graphics.formats.common;
import dge.resource;

//To do: eliminate duplication on big-endian machines?
T fromBytes(T)(ubyte[] bytes)
in {
	assert(bytes.length >= T.sizeof, to!string(T.sizeof) ~ " bytes expected, not " ~ to!string(bytes.length));
}
body {
	ubyte[] copiedBytes = bytes[0 .. T.sizeof].dup;
	version(LittleEndian) {
		copiedBytes.reverse;
	}
	return *(cast(T*)copiedBytes);
}

ubyte[] toBytes(T)(T value) {
	ubyte[] bytes = (cast(ubyte*)&value)[0 .. T.sizeof];
	version(BigEndian) {
		bytes.reverse;
	}
	return bytes.dup;
}

ubyte[] decompressGzip(ubyte[] compressed) {
	return cast(ubyte[])uncompress(compressed, 0, 15 + 16);
}

void compressGzipFile(string filename, ubyte[] uncompressed) {
	gzFile file = gzopen(cast(char*)toStringz(filename.dup), cast(char*)toStringz("wb".dup));
	assert(file != null, "Unable to open file " ~ filename ~ " for writing");
	scope(exit) gzclose(file);
	int status = gzwrite(file, uncompressed.ptr, cast(uint)uncompressed.length);
	assert(status == uncompressed.length, "Error while writing " ~ filename);
}

enum TagType: byte {End = 0, Byte, Short, Int, Long, Float, Double, ByteArray, String, List, Compound, Invalid = byte.max}

private bool isScalarType(TagType type) pure {
	return (type >= TagType.Byte && type <= TagType.Double);
}

private template translatesToScalar(T) {
	static if(Tag.typeId!T == TagType.Invalid) {
		enum bool translatesToScalar = false;
	} else {
		enum bool translatesToScalar = true;
	}
}

//To do: figure out how to efficiently extract data without keeping references to the whole uncompressed file.
class NBTFile {
	this(const char[] filename) {
		ubyte[] compressed = cast(ubyte[])read(filename);
		bytes = cast(ubyte[])decompressGzip(compressed);
		root = cast(TagCompound)parseNamedTag();
		assert(root !is null, "The root tag of an NBT file must be a named TagCompound.");
		//Free up memory. Sort of.
		bytes.length = 0;
	}

	this(ubyte[] zlibArray) {
		bytes = cast(ubyte[])uncompress(zlibArray);
		root = cast(TagCompound)parseNamedTag();
		assert(root !is null, "The root tag of an NBT file must be a named TagCompound.");
	}

	void serialize(string filename) {
		ubyte[] data = root.serializeName() ~ root.serialize();
		compressGzipFile(filename, data);
	}

	TagCompound root;

	private:
	Tag parseNamedTag() {
		TagType type = cast(TagType)bytes[0];
		bytes = bytes[1 .. $];
		if(type == TagType.End) {
			return new TagEnd;
		} else {
			string name = (cast(TagString)parseTag(TagType.String)).value;
			Tag tag = parseTag(type);
			tag.name = name;
			return tag;
		}
	}
	Tag parseTag(TagType type) {
		switch(type) {
			case TagType.Byte:
				TagByte tag = new TagByte;
				tag.value = bytes[0];
				bytes = bytes[byte.sizeof .. $];
				return tag;
				//break;
			case TagType.Short:
				TagShort tag = new TagShort;
				tag.value = fromBytes!short(bytes);
				bytes = bytes[short.sizeof .. $];
				return tag;
				//break;
			case TagType.Int:
				TagInt tag = new TagInt;
				tag.value = fromBytes!int(bytes);
				bytes = bytes[int.sizeof .. $];
				return tag;
				//break;
			case TagType.Long:
				TagLong tag = new TagLong;
				tag.value = fromBytes!long(bytes);
				bytes = bytes[long.sizeof .. $];
				return tag;
				//break;
			case TagType.Float:
				TagFloat tag = new TagFloat;
				tag.value = fromBytes!float(bytes);
				bytes = bytes[float.sizeof .. $];
				return tag;
				//break;
			case TagType.Double:
				TagDouble tag = new TagDouble;
				tag.value = fromBytes!double(bytes);
				bytes = bytes[double.sizeof .. $];
				return tag;
				//break;
			case TagType.String:
				TagString tag = new TagString;
				short chars = fromBytes!short(bytes);
				bytes = bytes[short.sizeof .. $];
				tag.value = cast(string)(bytes[0 .. chars].idup);
				bytes = bytes[chars .. $];
				return tag;
				//break;
			case TagType.ByteArray:
				TagByteArray tag = new TagByteArray;
				int numBytes = fromBytes!int(bytes);
				bytes = bytes[int.sizeof .. $];
				tag.value = cast(byte[])(bytes[0 .. numBytes]);
				bytes = bytes[numBytes .. $];
				return tag;
				//break;
			case TagType.List:
				TagList tag = new TagList;
				tag.elementType = cast(TagType)bytes[0];
				bytes = bytes[1 .. $];
				uint len = cast(size_t)fromBytes!uint(bytes);
				bytes = bytes[int.sizeof .. $];
				if(isScalarType(tag.elementType)) {
					tag.value = parseArray(tag.elementType, len);
				} else {
					Tag[] tags;
					tags.length = len;
					for(int i = 0; i < tags.length; ++i) {
						tags[i] = parseTag(tag.elementType);
					}
					tag.value = cast(void[])tags;
				}
				return tag;
				//break;
			case TagType.Compound:
				TagCompound tag = new TagCompound;
				Tag nextTag = parseNamedTag();
				while(cast(TagEnd)nextTag is null) {
					tag.addTag(nextTag);
					nextTag = parseNamedTag();
				}
				return tag;
				//break;
			default:
				assert(false);
		}
	}

	//Provides raw parsing of an array of scalars to make TagList more efficient
	void[] parseArray(TagType type, size_t len) {
		ubyte[] array;
		const size_t totalLen = len * Tag.nativeSizes[type];
		version(LittleEndian) {
			//To do: needed?
			array = bytes[0 .. totalLen].dup;
			bytes = bytes[totalLen .. $];
			//Flip bytes.
			for(size_t offset = 0; offset < totalLen; offset += Tag.nativeSizes[type]) {
				array[offset .. offset + Tag.nativeSizes[type]].reverse;
			}
		} else {
			array = bytes[0 .. totalLen];
		}
		return cast(void[]) array;
	}

	//Used only when parsing the file
	ubyte[] bytes;

}

abstract class Tag {
	@property TagType type();
	@property string typeName();

	ubyte[] serialize();
	final ubyte[] serializeName() {
		return cast(ubyte)type() ~ toBytes!short(cast(short)name.length) ~ cast(ubyte[])name;
	}

	string name;

	static:
	//Maps scalar tag types to the D types that represent them
	enum string[] nativeTypes = ["void", "byte", "short", "int", "long", "float", "double"];
	enum size_t[] nativeSizes = [0, 1, short.sizeof, int.sizeof, long.sizeof, float.sizeof, double.sizeof];
	template nativeTypeFromId(TagType tId) if(isScalarType(tId)) {
		mixin("alias " ~ nativeTypes[tId] ~ " typeFromId;");
	}

	//Maps D scalar types to tag types
	//Catch types that don't map to scalars.
	template typeId(T) {enum typeId = TagType.Invalid;}
	//Map types that can be mapped.
	template typeId(T: byte) {enum typeId = TagType.Byte;}
	template typeId(T: short) {enum typeId = TagType.Short;}
	template typeId(T: int) {enum typeId = TagType.Int;}
	template typeId(T: long) {enum typeId = TagType.Long;}
	template typeId(T: float) {enum typeId = TagType.Float;}
	template typeId(T: double) {enum typeId = TagType.Double;}
}

class TagEnd: Tag {
	override @property TagType type() {return TagType.End;}
	override @property string typeName() {return "end";}

	override ubyte[] serialize() {assert(false);}
}

//A tag that carries a payload of type T
abstract class PayloadTag(T): Tag {
	alias T contentType;
	this() {}
	this(T value) {this.value = value;}

	override @property string typeName() {return T.stringof;};

	override ubyte[] serialize() {
		return toBytes(value);
	}

	T value;
}

class TagByte: PayloadTag!byte {
	override @property TagType type() {return TagType.Byte;}
}

class TagShort: PayloadTag!short {
	override @property TagType type() {return TagType.Short;}
}

class TagInt: PayloadTag!int {
	override @property TagType type() {return TagType.Int;}
}

class TagLong: PayloadTag!long {
	override @property TagType type() {return TagType.Long;}
}

class TagFloat: PayloadTag!float {
	override @property TagType type() {return TagType.Float;}
}

class TagDouble: PayloadTag!double {
	override @property TagType type() {return TagType.Double;}
}

class TagString: PayloadTag!string {
	override @property TagType type() {return TagType.String;}

	override ubyte[] serialize() {
		return toBytes!short(cast(short)value.length) ~ cast(ubyte[])value;
	}
}

class TagByteArray: PayloadTag!(byte[]) {
	override @property TagType type() {return TagType.ByteArray;}
	override @property string typeName() {return "byte-array";}

	override ubyte[] serialize() {
		return toBytes!int(cast(int)value.length) ~ cast(ubyte[])value;
	}

	alias value bytes;
}

//To do: add more safety checks.
class TagList: PayloadTag!(void[]) {
	override @property TagType type() {return TagType.List;}
	override @property string typeName() {return "list";}

	override ubyte[] serialize() {
		ubyte[] result;
		result ~= cast(ubyte)elementType;
		if(isScalarType(elementType)) {
			assert(false, "Must flip byte order. Implement!");
			//result ~= toBytes!int(value.length / NBTFile.tagNativeSizes[elementType]);
			//result ~= cast(ubyte[])value;
		} else {
			result ~= toBytes!int(cast(int)(value.length / (void*).sizeof));
			foreach(Tag t; cast(Tag[])value) {
				result ~= t.serialize();
			}
		}
		return result;
	}

	@property T[] scalars(T)() if(translatesToScalar!T) {
		if(elementType == Tag.typeId!T) {
			return cast(T[]) value;
		} else {
			assert(false, "Attempt to retrieve " ~ T.stringof ~ " from TagList of " ~ Tag.nativeTypes[elementType]);
		}
	}

	/++@property T[] scalars(T)(T[] array) if(translatesToScalar!T) {
		elementType = NBTFile.typeId!T;
		value = cast(void[])array;
	}+/

	@property Tag[] tags() {
		if(isScalarType(elementType)) {
			assert(false, "Attempt to retrieve non-scalar tags from a TagList of scalars");
		} else {
			return cast(Tag[])value;
		}
	}

	//To do: protect this from being randomly changed.
	TagType elementType;
}

class TagCompound: PayloadTag!(Tag[][string]) {
	override @property TagType type() {return TagType.Compound;}
	override @property string typeName() {return "compound";}

	override ubyte[] serialize() {
		ubyte[] result;
		foreach(Tag[] tagList; tags) {
			foreach(Tag t; tagList) {
				result ~= t.serializeName ~ t.serialize();
			}
		}
		result ~= cast(ubyte)0;
		return result;
	}

	void addTag(Tag t) {
		auto tagsByName = t.name in tags;
		if(tagsByName) {
			*tagsByName ~= t;
		} else {
			tags[t.name] = [t];
		}
	}

	int opApply (int delegate(ref Tag x) dg) {
		int result;
		foreach(Tag[] tagList; tags) {
			foreach(ref Tag t; tagList) {
				result = dg(t);
				if(result)
					return result;
			}
		}
		return result;
	}

	Tag get()(string name, TagType type, Tag defaultValue = null) {
		auto tagsByName = name in tags;
		if(tagsByName) {
			foreach(Tag tag; *tagsByName) {
				if(tag.type == type)
					return tag;
			}
		}
		return defaultValue;
	}

	Tag get(Type)(string name, Type defaultValue = null) if(is(Type: Tag)) {
		return cast(Type)get(name, Tag.typeId!Type, defaultValue);
	}

	alias value tags;
	alias value this;
}

class NBMFile {
	this(const(char)[] filename, const(char[])[] path = [getcwd()]) {
		searchPath = path;

		auto file = new NBTFile(filename);

		auto tagMeshes = cast(TagCompound)file.root.get("Meshes", TagType.Compound);
		enforce(tagMeshes, "NBM file lacks mesh data");

		foreach(Tag t; tagMeshes) {
			//Is this a mesh?
			TagCompound tagMesh = cast(TagCompound)t;
			if(tagMesh) {
				processMesh(tagMesh);
			}
		}

		auto tagMaterials = cast(TagCompound)file.root.get("Materials", TagType.Compound);
		if(tagMaterials) {
			foreach(Tag t; tagMaterials) {
				auto tagMat = cast(TagCompound)t;
				if(tagMat) {
					processMaterial(tagMat);
				}
			}
		}

		//Convert source meshes to DGE meshes.
		foreach(string name, SourceMesh src; sourceMeshes) {
			meshes[name] = sourceMeshToMesh(src, materials);
		}

	}

	Mesh[string] meshes;
	Material[string] materials;

	private:
	void processMesh(TagCompound tagMesh) {
		SourceMesh m = new SourceMesh;

		//Find the data tags.
		auto tagList = cast(TagList)tagMesh.get("Vertices", TagType.List);
		if(tagList) {
			float[] floats = tagList.scalars!float;
			assert(floats.length % 3 == 0);
			//The floats should pack right down into the proper structs.
			m.vertices = cast(Vector3[])floats;
		}

		tagList = cast(TagList)tagMesh.get("Vertex normals", TagType.List);
		if(tagList) {
			float[] floats = tagList.scalars!float;
			assert(floats.length % 3 == 0);
			m.normals = cast(Vector3[])floats;
		}

		tagList = cast(TagList)tagMesh.get("Texture coordinates", TagType.List);
		if(tagList) {
			float[] floats = tagList.scalars!float;
			assert(floats.length % 2 == 0);
			m.texCoords = cast(TexCoord2[])floats;
		}

		auto tagCompound = cast(TagCompound)tagMesh.get("Triangle groups", TagType.Compound);
		if(tagCompound) {
			foreach(Tag t; tagCompound) {
				//Is this tag a triangle group?
				auto tagTriGroup = cast(TagCompound)t;
				if(tagTriGroup) {
					processTriangleGroup(tagTriGroup, m);
				}
			}
		}

		tagCompound = cast(TagCompound)tagMesh.get("Actions", TagType.Compound);
		if(tagCompound) {
			foreach(Tag t; tagCompound) {
				auto tagAction = cast(TagCompound)t;
				if(tagAction) {
					processAction(tagAction, m);
				}
			}
		}

		sourceMeshes[tagMesh.name] = m;
	}

	void processTriangleGroup(TagCompound tagGroup, SourceMesh m) {
		auto fg = new SourceFaceGroup;
		m.faceGroups[tagGroup.name] = fg;

		auto tagVertices = cast(TagList)tagGroup.get("Vertices", TagType.List);
		assert(tagVertices && tagVertices.elementType == TagType.Int, "Missing or invalid vertex data for face group " ~ tagGroup.name);
		int[] vertices = tagVertices.scalars!int;
		assert(vertices.length % 3 == 0);

		auto tagNormals = cast(TagList)tagGroup.get("Vertex normals", TagType.List);
		assert(tagNormals && tagNormals.elementType == TagType.Int, "Missing or invalid vertex normal data for face group " ~ tagGroup.name);
		int[] normals = tagNormals.scalars!int;
		assert(normals.length == vertices.length);

		int[] texCoords;
		auto tagTexCoords = cast(TagList)tagGroup.get("Texture coordinates", TagType.List);
		if(tagTexCoords && tagTexCoords.elementType == TagType.Int) {
			texCoords = tagTexCoords.scalars!int;
			assert(texCoords.length == vertices.length);
		}

		for(size_t faceOffset = 0; faceOffset < vertices.length; faceOffset += 3) {
			SourceFace f;
			f.vertices = cast(uint[])vertices[faceOffset .. faceOffset + 3];
			f.normals = cast(uint[])normals[faceOffset .. faceOffset + 3];
			if(texCoords.length > 0)
				f.texCoords = cast(uint[])texCoords[faceOffset .. faceOffset + 3];
			//To do: optimize
			fg.faces ~= f;
		}
	}

	void processAction(TagCompound tagAction, SourceMesh m) {
		VertexAction act;

		auto tagFrames = cast(TagList)tagAction.get("Frames", TagType.List);
		if(tagFrames && tagFrames.elementType == TagType.Compound) {
			act.frames.length = tagFrames.tags.length;
			foreach(size_t i, Tag t; tagFrames.tags) {
				auto tagFrame = cast(TagCompound)t;
				auto tagVertices = cast(TagList)tagFrame.get("Vertices", TagType.List);
				auto tagNormals = cast(TagList)tagFrame.get("Vertex normals", TagType.List);
				assert(tagVertices && tagNormals, "No vertex/normal data for vertex action frame");
				assert(tagVertices.elementType == TagType.Float && tagNormals.elementType == TagType.Float);

				float[] vData = tagVertices.scalars!float;
				float[] nData = tagNormals.scalars!float;
				assert(vData.length % 3 == 0 && nData.length % 3 == 0);

				act.frames[i] = VertexAnimationFrame(cast(Vector3[])vData, cast(Vector3[])nData);
			}
		}
		m.vertexActions[tagAction.name] = act;
	}

	void processMaterial(TagCompound tagMat) {
		Material mat = new Material;

		auto tagList = cast(TagList)tagMat.get("Diffuse", TagType.List);
		if(tagList && tagList.elementType == TagType.Float) {
			mat.diffuse = processColor(tagList, false);
		}

		tagList = cast(TagList)tagMat.get("Specular", TagType.List);
		if(tagList && tagList.elementType == TagType.Float) {
			mat.specular = processColor(tagList, false);
		}

		tagList = cast(TagList)tagMat.get("Emission", TagType.List);
		if(tagList && tagList.elementType == TagType.Float) {
			mat.emission = processColor(tagList, false);
		}

		auto tagFloat = cast(TagFloat)tagMat.get("Shininess", TagType.Float);
		if(tagFloat) {
			mat.shininess = tagFloat.value;
		}

		//To do: multitexturing
		auto tagString = cast(TagString)tagMat.get("Texture", TagType.String);
		if(tagString) {
			mat.texture = load!Texture(tagString.value, searchPath);
		}

		tagString = cast(TagString)tagMat.get("Fragment shader", TagType.String);

		materials[tagMat.name] = mat;
	}

	Color processColor(TagList tagColor, bool useAlpha) {
		float[] values = tagColor.scalars!float;
		Color c;
		if(useAlpha) {
			assert(values.length == 4);
		} else {
			assert(values.length == 3);
		}
		c.values[0 .. values.length] = values[];
		return c;
	}

	SourceMesh[string] sourceMeshes;
	const(char[])[] searchPath;
}
