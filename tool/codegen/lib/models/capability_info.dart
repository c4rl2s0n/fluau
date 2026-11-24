/// Models for @LuaCapability / @LuaCapabilityDto codegen.

class CapabilityDtoField {
  CapabilityDtoField({
    required this.name,
    required this.typeName,
    required this.isNullable,
    required this.isRequired,
    this.isList = false,
    this.listElementType,
    this.isMap = false,
    this.isDto = false,
    this.dtoClassName,
  });

  final String name;
  final String typeName;
  final bool isNullable;
  final bool isRequired;
  final bool isList;
  final String? listElementType;
  final bool isMap;
  final bool isDto;
  final String? dtoClassName;
}

class CapabilityDtoInfo {
  CapabilityDtoInfo({
    required this.className,
    required this.luauName,
    required this.sourceFile,
    required this.fields,
  });

  final String className;
  final String luauName;
  final String sourceFile;
  final List<CapabilityDtoField> fields;
}

class CapabilityMethodInfo {
  CapabilityMethodInfo({
    required this.dartName,
    required this.dispatchName,
    required this.returnType,
    this.argsType,
    this.argsOptional = true,
  });

  final String dartName;
  final String dispatchName;
  final String returnType;
  final String? argsType;
  final bool argsOptional;
}

class CapabilityInfo {
  CapabilityInfo({
    required this.className,
    required this.capabilityId,
    required this.sourceFile,
    required this.methods,
    required this.implClassName,
  });

  final String className;
  final String capabilityId;
  final String sourceFile;
  final List<CapabilityMethodInfo> methods;
  final String implClassName;
}

class CapabilityParseResult {
  CapabilityParseResult({
    required this.capabilities,
    required this.dtos,
  });

  final List<CapabilityInfo> capabilities;
  final List<CapabilityDtoInfo> dtos;
}
