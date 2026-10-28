import 'package:flutter/material.dart';
import 'json_ops.dart';
import 'theme.dart';

class JsonTreeEditor extends StatefulWidget {
  const JsonTreeEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<JsonTreeEditor> createState() => _JsonTreeEditorState();
}

enum _NodeMenuAction {
  editValue,
  renameKey,
  moveUp,
  moveDown,
  addChild,
  duplicate,
  delete,
}

class _TreeRow {
  const _TreeRow({
    required this.path,
    required this.pathKey,
    required this.depth,
    required this.keyOrIndex,
    required this.value,
    required this.isContainer,
    required this.isExpanded,
    required this.parentIsMap,
    required this.parentIsList,
    required this.listLength,
  });

  final JsonPath path;
  final String pathKey;
  final int depth;
  final Object? keyOrIndex; // null for root, String for map entry, int for list item
  final dynamic value;
  final bool isContainer;
  final bool isExpanded;
  final bool parentIsMap;
  final bool parentIsList;
  final int listLength;

  bool get isRoot => path.isEmpty;
}

class _JsonTreeEditorState extends State<JsonTreeEditor> {
  late dynamic _root;
  final Set<String> _expandedPaths = <String>{'/'};
  late List<_TreeRow> _visibleRows;

  @override
  void initState() {
    super.initState();
    _root = widget.value;
    _rebuildRows();
  }

  @override
  void didUpdateWidget(covariant JsonTreeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.value, oldWidget.value) &&
        !identical(widget.value, _root)) {
      _root = widget.value;
      _rebuildRows();
    }
  }

  String _encodePath(JsonPath path) {
    if (path.isEmpty) return '/';
    final sb = StringBuffer();
    for (final segment in path) {
      sb.write('/');
      if (segment is String) {
        final escaped = segment
            .replaceAll(r'\', r'\\')
            .replaceAll('/', r'\/');
        sb.write('k:$escaped');
      } else if (segment is int) {
        sb.write('i:$segment');
      }
    }
    return sb.toString();
  }

  void _rebuildRows() {
    final rows = <_TreeRow>[];
    void visit(
      dynamic node,
      JsonPath path,
      int depth,
      Object? keyOrIndex,
      bool parentIsMap,
      bool parentIsList,
      int listLength,
    ) {
      final isContainer = node is Map || node is List;
      final pathKey = _encodePath(path);
      final isExpanded = isContainer && _expandedPaths.contains(pathKey);

      rows.add(
        _TreeRow(
          path: path,
          pathKey: pathKey,
          depth: depth,
          keyOrIndex: keyOrIndex,
          value: node,
          isContainer: isContainer,
          isExpanded: isExpanded,
          parentIsMap: parentIsMap,
          parentIsList: parentIsList,
          listLength: listLength,
        ),
      );

      if (isExpanded) {
        if (node is Map) {
          for (final entry in node.entries) {
            final key = entry.key.toString();
            final childPath = List<Object>.unmodifiable(<Object>[...path, key]);
            visit(
              entry.value,
              childPath,
              depth + 1,
              key,
              true,
              false,
              0,
            );
          }
        } else if (node is List) {
          final len = node.length;
          for (var i = 0; i < len; i++) {
            final childPath = List<Object>.unmodifiable(<Object>[...path, i]);
            visit(
              node[i],
              childPath,
              depth + 1,
              i,
              false,
              true,
              len,
            );
          }
        }
      }
    }

    visit(_root, const <Object>[], 0, null, false, false, 0);
    _visibleRows = rows;
  }

  void _applyNewRoot(dynamic newRoot) {
    setState(() {
      _root = newRoot;
      _rebuildRows();
    });
    widget.onChanged(newRoot);
  }

  void _toggleExpand(_TreeRow row) {
    if (!row.isContainer) return;
    setState(() {
      if (_expandedPaths.contains(row.pathKey)) {
        _expandedPaths.remove(row.pathKey);
      } else {
        _expandedPaths.add(row.pathKey);
      }
      _rebuildRows();
    });
  }

  dynamic _deepCloneJson(dynamic value) {
    if (value is Map) {
      final copy = <String, dynamic>{};
      for (final entry in value.entries) {
        copy[entry.key.toString()] = _deepCloneJson(entry.value);
      }
      return copy;
    } else if (value is List) {
      return List<dynamic>.generate(
        value.length,
        (i) => _deepCloneJson(value[i]),
      );
    }
    return value;
  }

  String _uniqueDuplicateKey(Map<dynamic, dynamic> map, String baseKey) {
    var candidate = '${baseKey}_copy';
    var counter = 2;
    while (map.containsKey(candidate)) {
      candidate = '${baseKey}_copy$counter';
      counter++;
    }
    return candidate;
  }

  void _updateExpandedPathsOnKeyRename(
    JsonPath oldPath,
    JsonPath newPath,
  ) {
    final oldPrefix = _encodePath(oldPath);
    final newPrefix = _encodePath(newPath);
    final toAdd = <String>[];
    final toRemove = <String>[];

    for (final p in _expandedPaths) {
      if (p == oldPrefix) {
        toRemove.add(p);
        toAdd.add(newPrefix);
      } else if (p.startsWith('$oldPrefix/')) {
        toRemove.add(p);
        toAdd.add('$newPrefix${p.substring(oldPrefix.length)}');
      }
    }
    _expandedPaths.removeAll(toRemove);
    _expandedPaths.addAll(toAdd);
  }

  void _removeExpandedPathsUnder(JsonPath removedPath) {
    final prefix = _encodePath(removedPath);
    _expandedPaths.removeWhere(
      (p) => p == prefix || p.startsWith('$prefix/'),
    );
  }

  Future<void> _handleEditValue(_TreeRow row) async {
    if (row.isContainer) return;
    final result = await showDialog<_EditValueResult>(
      context: context,
      builder: (ctx) => _EditValueDialog(initialValue: row.value),
    );
    if (result == null || !mounted) return;
    final newRoot = jsonSet(_root, row.path, result.value);
    _applyNewRoot(newRoot);
  }

  Future<void> _handleRenameKey(_TreeRow row) async {
    if (!row.parentIsMap || row.keyOrIndex is! String) return;
    final currentKey = row.keyOrIndex as String;
    final parentPath = row.path.sublist(0, row.path.length - 1);
    final parentMap = jsonGet(_root, parentPath) as Map;

    final newKey = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameKeyDialog(
        initialKey: currentKey,
        existingKeys: parentMap.keys.map((e) => e.toString()).toSet(),
      ),
    );
    if (newKey == null || newKey == currentKey || !mounted) return;

    final newRoot = jsonRename(_root, row.path, newKey);
    final newPath = <Object>[...parentPath, newKey];
    _updateExpandedPathsOnKeyRename(row.path, newPath);
    _applyNewRoot(newRoot);
  }

  void _handleMove(_TreeRow row, int delta) {
    if (!row.parentIsList || row.keyOrIndex is! int) return;
    final newRoot = jsonMove(_root, row.path, delta);
    _applyNewRoot(newRoot);
  }

  Future<void> _handleAddChild(_TreeRow row) async {
    if (!row.isContainer) return;
    final isMap = row.value is Map;
    final existingKeys = isMap
        ? (row.value as Map).keys.map((e) => e.toString()).toSet()
        : const <String>{};

    final result = await showDialog<_AddChildResult>(
      context: context,
      builder: (ctx) => _AddChildDialog(
        isMap: isMap,
        existingKeys: existingKeys,
      ),
    );
    if (result == null || !mounted) return;

    final newRoot = jsonInsert(
      _root,
      row.path,
      isMap ? result.key : null,
      result.initialValue,
    );
    _expandedPaths.add(row.pathKey);
    _applyNewRoot(newRoot);
  }

  void _handleDuplicate(_TreeRow row) {
    if (row.isRoot) return;
    final parentPath = row.path.sublist(0, row.path.length - 1);
    final clonedValue = _deepCloneJson(row.value);

    if (row.parentIsMap && row.keyOrIndex is String) {
      final parentMap = jsonGet(_root, parentPath) as Map;
      final newKey = _uniqueDuplicateKey(parentMap, row.keyOrIndex as String);
      final newRoot = jsonInsert(_root, parentPath, newKey, clonedValue);
      _applyNewRoot(newRoot);
    } else if (row.parentIsList && row.keyOrIndex is int) {
      final idx = row.keyOrIndex as int;
      final newRoot = jsonInsert(_root, parentPath, idx + 1, clonedValue);
      _applyNewRoot(newRoot);
    }
  }

  Future<void> _handleDelete(_TreeRow row) async {
    if (row.isRoot) return;
    if (row.isContainer) {
      final label = row.parentIsMap
          ? '"${row.keyOrIndex}"'
          : '[${row.keyOrIndex}]';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: StudioColors.panel,
          title: const Text(
            'Delete node?',
            style: TextStyle(color: StudioColors.ink),
          ),
          content: Text(
            'Delete $label and all of its children?',
            style: const TextStyle(color: StudioColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: StudioColors.accentDark,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final newRoot = jsonRemove(_root, row.path);
    _removeExpandedPathsUnder(row.path);
    _applyNewRoot(newRoot);
  }

  String _rowTitle(_TreeRow row) {
    if (row.isRoot) return 'root';
    if (row.parentIsList) return '[${row.keyOrIndex}]';
    return '${row.keyOrIndex}';
  }

  String _previewText(dynamic value) {
    if (value is Map) {
      final n = value.length;
      return '{$n ${n == 1 ? 'key' : 'keys'}}';
    }
    if (value is List) {
      final n = value.length;
      return '[$n ${n == 1 ? 'item' : 'items'}]';
    }
    if (value is String) {
      final singleLine = value
          .replaceAll('\r\n', r'\n')
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r');
      return '"$singleLine"';
    }
    if (value == null) return 'null';
    return value.toString();
  }

  Color _previewColor(dynamic value) {
    final type = jsonTypeName(value);
    switch (type) {
      case 'object':
        return StudioColors.inkSoft;
      case 'array':
        return const Color(0xFF7A6855);
      case 'string':
        return const Color(0xFF3E6B48);
      case 'number':
        return const Color(0xFF2F5D8A);
      case 'boolean':
        return const Color(0xFF8C4A27);
      case 'null':
      default:
        return const Color(0xFF9A8878);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _visibleRows.length,
      itemBuilder: (context, index) {
        final row = _visibleRows[index];
        return _buildRow(context, row);
      },
    );
  }

  Widget _buildRow(BuildContext context, _TreeRow row) {
    final title = _rowTitle(row);
    final preview = _previewText(row.value);
    final typeName = jsonTypeName(row.value);
    final semanticLabel = row.isContainer
        ? '$title, $typeName $preview, ${row.isExpanded ? 'expanded' : 'collapsed'}'
        : '$title, $typeName: $preview';

    return Semantics(
      container: true,
      label: semanticLabel,
      button: true,
      toggled: row.isContainer ? row.isExpanded : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (row.isContainer) {
              _toggleExpand(row);
            } else {
              _handleEditValue(row);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: EdgeInsets.only(
              left: 8.0 + row.depth * 16.0,
              right: 4.0,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: StudioColors.rule, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (row.isContainer)
                  Semantics(
                    label: row.isExpanded ? 'Collapse $title' : 'Expand $title',
                    child: Icon(
                      row.isExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 20,
                      color: StudioColors.inkSoft,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 4),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioColors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _previewColor(row.value),
                      fontSize: 13,
                      fontStyle: row.value == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
                _buildPopupMenu(row, title),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(_TreeRow row, String title) {
    return Semantics(
      label: 'Actions for $title',
      child: PopupMenuButton<_NodeMenuAction>(
        icon: const Icon(
          Icons.more_vert,
          size: 18,
          color: StudioColors.inkSoft,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        color: StudioColors.panel,
        onSelected: (action) {
          switch (action) {
            case _NodeMenuAction.editValue:
              _handleEditValue(row);
              break;
            case _NodeMenuAction.renameKey:
              _handleRenameKey(row);
              break;
            case _NodeMenuAction.moveUp:
              _handleMove(row, -1);
              break;
            case _NodeMenuAction.moveDown:
              _handleMove(row, 1);
              break;
            case _NodeMenuAction.addChild:
              _handleAddChild(row);
              break;
            case _NodeMenuAction.duplicate:
              _handleDuplicate(row);
              break;
            case _NodeMenuAction.delete:
              _handleDelete(row);
              break;
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<_NodeMenuAction>>[];

          if (!row.isContainer) {
            items.add(
              const PopupMenuItem(
                value: _NodeMenuAction.editValue,
                child: Text('Edit value'),
              ),
            );
          }

          if (row.parentIsMap) {
            items.add(
              const PopupMenuItem(
                value: _NodeMenuAction.renameKey,
                child: Text('Rename key'),
              ),
            );
          }

          if (row.parentIsList && row.keyOrIndex is int) {
            final idx = row.keyOrIndex as int;
            items.add(
              PopupMenuItem(
                value: _NodeMenuAction.moveUp,
                enabled: idx > 0,
                child: const Text('Move up'),
              ),
            );
            items.add(
              PopupMenuItem(
                value: _NodeMenuAction.moveDown,
                enabled: idx < row.listLength - 1,
                child: const Text('Move down'),
              ),
            );
          }

          if (row.isContainer) {
            items.add(
              const PopupMenuItem(
                value: _NodeMenuAction.addChild,
                child: Text('Add child'),
              ),
            );
          }

          if (!row.isRoot && (row.parentIsMap || row.parentIsList)) {
            items.add(
              const PopupMenuItem(
                value: _NodeMenuAction.duplicate,
                child: Text('Duplicate'),
              ),
            );
          }

          if (!row.isRoot) {
            items.add(
              const PopupMenuItem(
                value: _NodeMenuAction.delete,
                child: Text('Delete'),
              ),
            );
          }

          return items;
        },
      ),
    );
  }
}

class _EditValueResult {
  const _EditValueResult(this.value);
  final dynamic value;
}

class _EditValueDialog extends StatefulWidget {
  const _EditValueDialog({required this.initialValue});

  final dynamic initialValue;

  @override
  State<_EditValueDialog> createState() => _EditValueDialogState();
}

class _EditValueDialogState extends State<_EditValueDialog> {
  static const List<String> _primitiveTypes = <String>[
    'string',
    'number',
    'boolean',
    'null',
  ];

  late String _selectedType;
  late TextEditingController _stringController;
  late TextEditingController _numberController;
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    final initType = jsonTypeName(widget.initialValue);
    _selectedType = _primitiveTypes.contains(initType) ? initType : 'string';

    _stringController = TextEditingController(
      text: widget.initialValue is String
          ? widget.initialValue as String
          : (widget.initialValue?.toString() ?? ''),
    );
    _numberController = TextEditingController(
      text: widget.initialValue is num ? widget.initialValue.toString() : '0',
    );
    _boolValue = widget.initialValue is bool
        ? widget.initialValue as bool
        : false;
  }

  @override
  void dispose() {
    _stringController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  bool get _isNumberValid =>
      parseJsonNumber(_numberController.text.trim()) != null;

  bool get _canSave {
    if (_selectedType == 'number') {
      return _isNumberValid;
    }
    return true;
  }

  void _save() {
    if (!_canSave) return;
    dynamic result;
    switch (_selectedType) {
      case 'string':
        result = _stringController.text;
        break;
      case 'number':
        result = parseJsonNumber(_numberController.text.trim());
        break;
      case 'boolean':
        result = _boolValue;
        break;
      case 'null':
      default:
        result = null;
        break;
    }
    Navigator.of(context).pop(_EditValueResult(result));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.panel,
      title: const Text(
        'Edit value',
        style: TextStyle(color: StudioColors.ink),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
              ),
              items: _primitiveTypes
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(t),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedType = val;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_selectedType == 'string')
              TextField(
                controller: _stringController,
                maxLines: null,
                minLines: 2,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else if (_selectedType == 'number')
              TextField(
                controller: _numberController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Number',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: _isNumberValid ? null : 'Invalid JSON number',
                ),
                onChanged: (_) => setState(() {}),
              )
            else if (_selectedType == 'boolean')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _boolValue ? 'true' : 'false',
                  style: const TextStyle(color: StudioColors.ink),
                ),
                value: _boolValue,
                activeThumbColor: StudioColors.accentDark,
                onChanged: (v) => setState(() => _boolValue = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: StudioColors.accentDark,
          ),
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _RenameKeyDialog extends StatefulWidget {
  const _RenameKeyDialog({
    required this.initialKey,
    required this.existingKeys,
  });

  final String initialKey;
  final Set<String> existingKeys;

  @override
  State<_RenameKeyDialog> createState() => _RenameKeyDialogState();
}

class _RenameKeyDialogState extends State<_RenameKeyDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _errorText {
    final text = _controller.text;
    if (text.isEmpty) return 'Key cannot be empty';
    if (text != widget.initialKey && widget.existingKeys.contains(text)) {
      return 'Key already exists';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _errorText;
    return AlertDialog(
      backgroundColor: StudioColors.panel,
      title: const Text(
        'Rename key',
        style: TextStyle(color: StudioColors.ink),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Key',
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: error,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (error == null) {
            Navigator.of(context).pop(_controller.text);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: StudioColors.accentDark,
          ),
          onPressed: error == null
              ? () => Navigator.of(context).pop(_controller.text)
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddChildResult {
  const _AddChildResult({this.key, required this.initialValue});
  final String? key;
  final dynamic initialValue;
}

class _AddChildDialog extends StatefulWidget {
  const _AddChildDialog({
    required this.isMap,
    required this.existingKeys,
  });

  final bool isMap;
  final Set<String> existingKeys;

  @override
  State<_AddChildDialog> createState() => _AddChildDialogState();
}

class _AddChildDialogState extends State<_AddChildDialog> {
  static const List<String> _allTypes = <String>[
    'string',
    'number',
    'boolean',
    'null',
    'object',
    'array',
  ];

  final TextEditingController _keyController = TextEditingController();
  String _selectedType = 'string';

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  String? get _keyError {
    if (!widget.isMap) return null;
    final key = _keyController.text;
    if (key.isEmpty) return 'Key cannot be empty';
    if (widget.existingKeys.contains(key)) return 'Key already exists';
    return null;
  }

  dynamic _defaultValueForType(String type) {
    switch (type) {
      case 'string':
        return '';
      case 'number':
        return 0;
      case 'boolean':
        return false;
      case 'null':
        return null;
      case 'object':
        return <String, dynamic>{};
      case 'array':
        return <dynamic>[];
      default:
        return null;
    }
  }

  void _submit() {
    if (_keyError != null) return;
    Navigator.of(context).pop(
      _AddChildResult(
        key: widget.isMap ? _keyController.text : null,
        initialValue: _defaultValueForType(_selectedType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyError = _keyError;
    return AlertDialog(
      backgroundColor: StudioColors.panel,
      title: const Text(
        'Add child',
        style: TextStyle(color: StudioColors.ink),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isMap) ...[
              TextField(
                controller: _keyController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Key',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: keyError,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
              ),
              items: _allTypes
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t,
                      child: Text(t),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedType = val;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: StudioColors.accentDark,
          ),
          onPressed: keyError == null ? _submit : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
