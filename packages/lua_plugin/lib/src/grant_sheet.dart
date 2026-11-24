import 'package:flutter/material.dart';

import 'bridge.dart';
import 'dto.dart';
import 'grant_store.dart';

/// Shows a grant review sheet. Returns stored grants if the user allows, else null.
Future<StoredPluginGrants?> showPluginGrantSheet({
  required BuildContext context,
  required PluginManifestDto manifest,
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

  final PluginManifestDto manifest;
  final StoredPluginGrants? previous;

  @override
  State<_GrantSheetBody> createState() => _GrantSheetBodyState();
}

class _GrantSheetBodyState extends State<_GrantSheetBody> {
  late final Map<String, HostApiInfoDto> _info;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _info = {
      for (final i in LuaPluginBridge.instance.listHostApiInfo()) i.id: i,
    };
    final prev = widget.previous?.hostApis.toSet() ?? {};
    _selected = {
      for (final req in widget.manifest.permissions.host)
        if (req.isRequired || prev.contains(req.id) || prev.isEmpty) req.id,
    };
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
                  final domains = _domains(req.constraints);
                  final selected = _selected.contains(req.id);
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    onChanged: req.isRequired
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
                          label: Text(req.isRequired ? 'Required' : 'Optional'),
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
                        ...req.constraints.entries
                            .where((e) => e.key != 'domains')
                            .map((e) => '${e.key}: ${e.value}'),
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
                          .where((r) => r.isRequired)
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

  List<String> _domains(Map<String, dynamic> constraints) {
    final d = constraints['domains'];
    if (d is List) {
      return d.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
