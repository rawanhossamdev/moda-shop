import '../theme/moda_icons.dart';
import 'package:flutter/material.dart';
import '../models/shipping_address.dart';
import '../services/products_api.dart';
import '../theme/moda_theme.dart';
import '../widgets/commerce_scope.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, this.select = false});
  final bool select;
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  List<ShippingAddress> _addresses = [];
  bool _started = false, _busy = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to update addresses. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetch() async {
    final addresses = await CommerceScope.of(context).repository.addresses();
    if (mounted) setState(() => _addresses = addresses);
  }

  Future<void> _load() => _run(_fetch);
  Future<void> _edit([ShippingAddress? address]) async {
    final saved = await Navigator.of(context).push<ShippingAddress>(
      MaterialPageRoute(builder: (_) => AddressEditScreen(address: address)),
    );
    if (!mounted || saved == null) return;
    if (widget.select) {
      Navigator.of(context).pop(saved);
    } else {
      await _load();
    }
  }

  Future<void> _delete(ShippingAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shipping address?'),
        content: const Text('Existing orders keep their delivery details.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await CommerceScope.of(context).repository.deleteAddress(address.id);
      if (mounted) await _fetch();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.select ? 'CHOOSE ADDRESS' : 'SHIPPING ADDRESSES',
        style: ModaStyle.label.copyWith(fontSize: 12),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FilledButton.icon(
                key: const Key('add-address'),
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(ModaIcons.add),
                label: const Text('ADD ADDRESS'),
              ),
              const SizedBox(height: 20),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (!_busy && _addresses.isEmpty && _error == null)
                const Text(
                  'No saved addresses. Add your delivery details to get started.',
                ),
              for (final address in _addresses)
                Card(
                  color: ModaStyle.cream,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (address.isDefault)
                          const Text('DEFAULT ADDRESS', style: ModaStyle.label),
                        const SizedBox(height: 8),
                        Text(
                          address.summary,
                          style: const TextStyle(height: 1.6),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (widget.select)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pop(context, address),
                                child: const Text('DELIVER HERE'),
                              ),
                            TextButton(
                              onPressed: _busy ? null : () => _edit(address),
                              child: const Text('EDIT'),
                            ),
                            if (!address.isDefault)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        await CommerceScope.of(
                                          context,
                                        ).repository.saveAddress({
                                          ...address.fields,
                                          'isDefault': true,
                                        }, id: address.id);
                                        if (mounted) await _fetch();
                                      }),
                                child: const Text('MAKE DEFAULT'),
                              ),
                            TextButton(
                              onPressed: _busy ? null : () => _delete(address),
                              child: const Text('DELETE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('RETRY'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class AddressEditScreen extends StatefulWidget {
  const AddressEditScreen({super.key, this.address});
  final ShippingAddress? address;
  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final key in addressLabels.keys)
      key: TextEditingController(
        text: widget.address?.data[key] as String? ?? '',
      ),
  };
  late bool _default = widget.address?.isDefault ?? false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await CommerceScope.of(context).repository.saveAddress({
        for (final field in _fields.entries) field.key: field.value.text.trim(),
        'isDefault': _default,
      }, id: widget.address?.id);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to save address. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.address == null ? 'ADD ADDRESS' : 'EDIT ADDRESS',
          style: ModaStyle.label.copyWith(fontSize: 12),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in addressLabels.entries) ...[
                      TextFormField(
                        key: Key(entry.key),
                        controller: _fields[entry.key],
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: entry.value,
                          counterText: '',
                        ),
                        maxLength: addressLimits[entry.key],
                        keyboardType: entry.key == 'mobile'
                            ? TextInputType.phone
                            : TextInputType.text,
                        textInputAction: entry.key == 'deliveryNotes'
                            ? TextInputAction.done
                            : TextInputAction.next,
                        validator: (value) =>
                            validateAddressField(entry.key, value),
                      ),
                      const SizedBox(height: 14),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Default shipping address'),
                      value: _default,
                      onChanged: _busy || widget.address?.isDefault == true
                          ? null
                          : (value) => setState(() => _default = value!),
                    ),
                    if (widget.address?.isDefault == true)
                      const Text(
                        'Choose another saved address as default to change this.',
                        style: TextStyle(color: ModaStyle.muted),
                      ),
                    if (_error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('save-address'),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'SAVING…' : 'SAVE ADDRESS'),
                    ),
                    if (_busy)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
