import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:luatest/lua/grant_store.dart';
import 'package:luatest/src/rust/api/plugin.dart';

/// Shows a grant review sheet. Returns stored grants if the user allows, else null.
Future<StoredPluginGrants?> showPluginGrantSheet({
  required BuildContext context,
  required PluginManifest manifest,
  StoredPluginGrants? previous,
}) {
  return showModalBottomSheet<StoredPluginGrants>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _GrantSheetBody(manifest: manifest, previous: previous),
  );
}

class _GrantSheetBody extends StatefulWidget {
  const _GrantSheetBody({required this.manifest, this.previous});

  final PluginManifest manifest;
  final StoredPluginGrants? previous;

  @override
  State<_GrantSheetBody> createState() => _GrantSheetBodyState();
}

class _GrantSheetBodyState extends State<_GrantSheetBody> {
  late final Map<String, HostApiInfo> _info;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _info = {
      for (final i in listHostApiInfo()) i.id: i,
    };
    final prev = widget.previous?.hostApis.toSet() ?? {};
    _selected = {
      for (final req in widget.manifest.permissions.host)
        if (req.required_ || prev.contains(req.id) || prev.isEmpty) req.id,
    };
    // First install: default optional on as well (prev.isEmpty above).
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = widget.manifest.permissions.host;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Allow ${widget.manifest.name}?',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${widget.manifest.version}. Required APIs cannot be turned off.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: host.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final req = host[index];
                  final info = _info[req.id];
                  final domains = _domains(req.constraintsJson);
                  final selected = _selected.contains(req.id);
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    onChanged: req.required_
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selected.add(req.id);
                              } else {
                                _selected.remove(req.id);
                              }
                            });
                          },
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(info?.summary ?? 'host.${req.id}'),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(req.required_ ? 'Required' : 'Optional'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      [
                        'API: ${req.id}',
                        if (domains.isNotEmpty)
                          'Domains: ${domains.join(', ')}',
                      ].join('\n'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final missingRequired = host
                          .where((r) => r.required_)
                          .any((r) => !_selected.contains(r.id));
                      if (missingRequired) return;
                      final stored = StoredPluginGrants.fromManifestSelection(
                        manifest: widget.manifest,
                        selectedHostApis: _selected,
                      );
                      Navigator.pop(context, stored);
                    },
                    child: const Text('Allow & run'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _domains(String constraintsJson) {
    try {
      final map = jsonDecode(constraintsJson);
      if (map is Map && map['domains'] is List) {
        return (map['domains'] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }
}
