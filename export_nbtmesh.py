#!BPY

"""
Name 'NBTMesh'
Blender: 262
Group: 'Export'
Tooltip 'NBTMesh exporter'
"""

import gzip
import os.path
from types import *
import struct

import bpy

tagEnd, tagByte, tagShort, tagInt, tagLong, tagFloat, tagDouble, tagByteArray, tagString, tagList, tagCompound = range(11)

class Tag:
	def __init__(self, type):
		self.type = type
		self.value = None
		self.name = None

	def serialize(self):
		result = bytearray([])
		serializePrimitive = [
			lambda: [],
			lambda s: bytes([s]),
			lambda s: struct.pack(">h", s),
			lambda s: struct.pack(">i", s),
			lambda s: struct.pack(">l", s),
			lambda s: struct.pack(">f", s),
			lambda s: struct.pack(">d", s),
			lambda s: struct.pack(">I", len(s)) + self.value,
			lambda s: struct.pack(">H", len(s)) + bytes(s, "ascii")]
		#Is the payload a primitive type?
		if self.type < tagList:
			return result + serializePrimitive[self.type](self.value)

		if self.type == tagList:
			result += bytes([self.payloadType])
			result += struct.pack(">i", len(self.value))
			#Is the element type scalar?
			if self.payloadType < tagList:
				for t in self.value:
					result += serializePrimitive[self.payloadType](t)
			else:
				for t in self.value:
					assert t.type == self.payloadType, "Type " + str(self.payloadType) + " expected, not " + str(t.type)
					result += t.serialize()
			return result

		#If we get here, it's a TagCompound.
		for t in self.value:
			result += t.serializeName() + t.serialize()
		return result + bytes([0])

	def serializeName(self):
		return bytearray([self.type]) + struct.pack(">H", len(self.name)) + bytes(self.name, "ascii")

def TagCompound():
	t = Tag(tagCompound)
	t.value = []
	return t

def TagList(type):
	t = Tag(tagList)
	t.payloadType = type
	t.value = []
	return t

def TagFloat(value):
	t = Tag(tagFloat)
	t.value = value
	return t

def TagInt(value):
	t = Tag(tagInt)
	t.value = value
	return t

def TagString(value = ""):
	t = Tag(tagString)
	t.value = value
	return t

def convertCoords(vec):
	return [vec.x, vec.z, -vec.y]

def write(filename):
	out = gzip.open(filename, "wb")
	root = TagCompound()
	root.name = "Scene"
	tagMeshes = TagCompound()
	tagMeshes.name = "Meshes"
	root.value.append(tagMeshes)

	for object in bpy.data.objects:
		if object.type != "MESH":
			continue

		#Apply modifiers.
		mesh = object.to_mesh(bpy.context.scene, True, "PREVIEW")

		tagMesh = TagCompound()
		tagMesh.name = object.data.name
		tagMeshes.value.append(tagMesh)

		actionBounds = {}
		actionTags = {}
		#Only needed for actions
		flatFaces = []

		#Handle mesh properties.
		#To do: handle missing action start/end
		for name, value in mesh.items():
			if name[0:10] == "AnimStart:":
				actionName = name[10:]
				if actionName in actionBounds:
					actionBounds[actionName][0] = int(value)
				else:
					actionBounds[actionName] = [int(value), None]
			elif name[0:9] == "AnimStop:":
				actionName = name[9:]
				if actionName in actionBounds:
					actionBounds[actionName][1] = int(value)
				else:
					actionBounds[actionName] = [None, int(value)]

		hasActions = (len(actionBounds) > 0)

		#Write static mesh data.
		tagVertices = TagList(tagFloat)
		tagVertices.name = "Vertices"
		tagMesh.value.append(tagVertices)

		tagNormals = TagList(tagFloat)
		tagNormals.name = "Vertex normals"
		tagMesh.value.append(tagNormals)

		tagTexCoords = TagList(tagFloat)
		tagTexCoords.name = "Texture coordinates"
		tagMesh.value.append(tagTexCoords)

		for v in mesh.vertices:
			tagVertices.value.extend(convertCoords(v.co))
			tagNormals.value.extend(convertCoords(v.normal))

		tagTriGroups = TagCompound()
		tagTriGroups.name = "Triangle groups"
		tagMesh.value.append(tagTriGroups)

		uvs = None

		if len(mesh.tessface_uv_textures) > 0:
			uvs = mesh.tessface_uv_textures[0]

		faceGroups = {}
		texPaths = {}

		#Sort faces by material and texture.
		for f in mesh.tessfaces:
			if not f.material_index in faceGroups:
				faceGroups[f.material_index] = {}
			byTexture = faceGroups[f.material_index]
			tex = None
			if uvs:
				tex = uvs.data[f.index].image
			#To do: optimize
			if tex in byTexture:
				byTexture[tex].append(f)
			else:
				byTexture[tex] = [f]

#			#Process texture paths.
#			filePath = os.path.dirname(filename)
#			for img in faceGroups.keys():
#				filename = ""
#				if img is not None:
#					filename = os.path.relpath(bpy.path.abspath(img.filepath), filePath)
#				texPaths[img] = filename


		#Iterate over face groups.
		for index, byTexture in faceGroups.items():
			for texture, group in byTexture.items():
				tagGroup = TagCompound()
				tagGroup.name = mesh.materials[index].name
				if texture is not None:
					tagGroup.name = tagGroup.name + " (" + bpy.path.relpath(texture.filepath)[2:] + ")"
				tagTriGroups.value.append(tagGroup)

				tagV = TagList(tagInt)
				tagV.name = "Vertices"
				tagGroup.value.append(tagV)

				tagN = TagList(tagInt)
				tagN.name = "Vertex normals"
				tagGroup.value.append(tagN)

				tagC = TagList(tagInt)
				tagC.name = "Texture coordinates"
				if uvs is not None:
					tagGroup.value.append(tagC)

				#Used for triangulation
				#To do: avoid texture coordinate duplication caused by triangulation.
				def writeTriangle(vertexNumbers, face):
					for vn in vertexNumbers:
						v = face.vertices[vn]
						tagV.value.append(v)
						if(face.use_smooth):
							#The vertex and normal indices will match.
							tagN.value.append(v)
						else:
							tagN.value.append(len(tagNormals.value) // 3 - 1)
						#Write UVs.
						if uvs is not None:
							u, v = uvs.data[face.index].uv[vn]
							tagTexCoords.value.extend([u, v])
							tagC.value.append(len(tagTexCoords.value) // 2 - 1)
				for face in group:
					#If using flat shading, write the normal.
					if not face.use_smooth:
						tagNormals.value.extend(convertCoords(face.normal))
						#We'll deal with actions later.
						if hasActions:
							flatFaces.append(face.index)
					#If this is a quad, add another triangle to fill it out.
					writeTriangle(range(3), face)
					if len(face.vertices) == 4:
						writeTriangle([2, 3, 0], face)

		#Handle actions.
		if hasActions:
			tagActions = TagCompound()
			tagActions.name = "Actions"
			tagMesh.value.append(tagActions)

			for name in actionBounds.keys():
				tagAction = TagCompound()
				tagAction.name = name
				tagActions.value.append(tagAction)

				tagFrames = TagList(tagCompound)
				tagFrames.name = "Frames"
				tagAction.value.append(tagFrames)

				bounds = actionBounds[name]

				#print(name)
				#print(bounds[1] - bounds[0])

				#To do: check for None.
				for frame in range(bounds[0], bounds[1]):
					tagFrame = TagCompound()
					tagFrames.value.append(tagFrame)

					tagActVertices = TagList(tagFloat)
					tagActVertices.name = "Vertices"
					tagFrame.value.append(tagActVertices)

					tagActNormals = TagList(tagFloat)
					tagActNormals.name = "Vertex normals"
					tagFrame.value.append(tagActNormals)

					bpy.context.scene.frame_set(frame)
					frameMesh = object.to_mesh(bpy.context.scene, True, "PREVIEW")

					for v in frameMesh.vertices:
						tagActVertices.value.extend(v.co)
						tagActNormals.value.extend(v.normal)

					#Handle flat faces.
					for index in flatFaces:
						for co in frameMesh.faces[index].normal:
							tagActNormals.value.append(co)

					bpy.data.meshes.remove(frameMesh)

		#Remove the temporary mesh.
		bpy.data.meshes.remove(mesh)

	#Process materials.
	tagMaterials = TagCompound()
	tagMaterials.name = "Materials"
	root.value.append(tagMaterials)

	def materialToTag(mat):
		tagMat = TagCompound()
		tagMat.name = mat.name
		tagMaterials.value.append(tagMat)
		tagMat.value.append(colorToTag(mat.diffuse_color, "Diffuse"))
		tagMat.value.append(colorToTag(mat.specular_color, "Specular"))
		tagShininess = TagFloat(float(mat.specular_hardness))
		tagShininess.name = "Shininess"
		tagMat.value.append(tagShininess)
		return tagMat

	for index, byTexture in faceGroups.items():
		for texture in byTexture.keys():
			#Process materials.
			mat = bpy.data.materials[index]
			tagMat = materialToTag(mat)
			tagMaterials.value.append(tagMat)
			if texture is not None:
				filename = bpy.path.relpath(texture.filepath)[2:]
				tagTex = TagString(filename)
				tagTex.name = "Texture"
				tagMat.value.append(tagTex)
				tagMat.name = tagMat.name + " (" + filename + ")"

	out.write(bytes(root.serializeName() + root.serialize()))
	out.close()

def colorToTag(color, name):
	tagColor = TagList(tagFloat)
	tagColor.name = name
	tagColor.value.extend(color)
	return tagColor


class Exporter(bpy.types.Operator):
    """Exporter for NBTMesh"""
    bl_idname = "export.nbtmesh"
    bl_label = "Export NBTMesh"

    filepath = bpy.props.StringProperty(subtype="FILE_PATH")

    @classmethod
    def poll(cls, context):
        true

    def execute(self, context):
        write(self.filepath)
        return {'FINISHED'}

    def invoke(self, context, event):
        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}

def menu_func(self, context):
    self.layout.operator_context = 'INVOKE_DEFAULT'
    self.layout.operator(Exporter.bl_idname, text="NBTMesh")

#Register and add to the file selector
bpy.utils.register_class(Exporter)
#bpy.types.INFO_MT_file_export.append(menu_func)


#test call
bpy.ops.export.nbtmesh('INVOKE_DEFAULT')
