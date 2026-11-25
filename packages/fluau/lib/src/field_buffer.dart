/// Local form-field values buffered in Flutter until flushed into Lua.
class FieldBuffer {
  final Map<String, String> _values = {};
  bool dirty = false;

  void setField(String id, String value) {
    final previous = _values[id];
    if (previous == value) return;
    _values[id] = value;
    dirty = true;
  }

  /// Initialize from a Lua render without marking dirty.
  void seedField(String id, String value) {
    _values[id] = value;
  }

  /// Snapshot current fields and clear the dirty flag.
  Map<String, String>? takeIfDirty() {
    if (!dirty) return null;
    dirty = false;
    return Map<String, String>.from(_values);
  }

  void clear() {
    _values.clear();
    dirty = false;
  }
}
