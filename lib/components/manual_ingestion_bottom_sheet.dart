import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

@NowaGenerated()
class ManualIngestionBottomSheet extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ManualIngestionBottomSheet({super.key, required this.secretKey});

  final SecretKey? secretKey;

  @override
  State<ManualIngestionBottomSheet> createState() {
    return _ManualIngestionBottomSheetState();
  }
}

@NowaGenerated()
class _ManualIngestionBottomSheetState
    extends State<ManualIngestionBottomSheet> {
  String _activityType = 'Running';

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _intensityController = TextEditingController();

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Secure Data Ingestion',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All data is encrypted before leaving this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildDropdown(theme),
            const SizedBox(height: 16),
            _buildTextField(
              theme,
              _durationController,
              'Duration (minutes)',
              Icons.timer_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              theme,
              _intensityController,
              'Intensity (1-10)',
              Icons.speed_outlined,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Encrypt & Vault Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activityType,
          isExpanded: true,
          items: [
            'Running',
            'Cycling',
            'Swimming',
            'Walking',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) => setState(() => _activityType = val!),
        ),
      ),
    );
  }

  Widget _buildTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: theme.cardTheme.color,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _saveData() async {
    if (_durationController.text.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      final data = {
        'type': _activityType,
        'duration': int.tryParse(_durationController.text) ?? 0,
        'intensity': int.tryParse(_intensityController.text) ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final jsonString = jsonEncode(data);
      final secretKey = widget.secretKey;
      if (secretKey == null) {
        throw StateError('Vault is locked. Unlock before saving data.');
      }
      final encryptedBlob = await EncryptionService().encryptString(
        jsonString,
        secretKey,
      );
      await LocalVault().saveWorkout(encryptedBlob, secretKey);
      await SupabaseService().syncLocalToSupabase(encryptedBlob);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity securely encrypted and vaulted!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save error: ${e}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
