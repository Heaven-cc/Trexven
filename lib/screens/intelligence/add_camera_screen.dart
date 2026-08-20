import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/camera_service.dart';
import '../../services/vision_service.dart';

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  static const _blue = Color(0xFF2563EB);
  static const _bg = Color(0xFFF8FAFC);
  static const _dark = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rtspCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _aiEnabled = true;
  bool _testingConnection = false;
  bool _saving = false;
  String? _testResult;
  bool? _testSuccess;

  final _visionService = VisionService();
  final _cameraService = CameraService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _rtspCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _buildRtspUrl() {
    final raw = _rtspCtrl.text.trim();
    if (raw.isEmpty) return '';
    // If user typed raw IP/host without rtsp:// prefix, keep as-is for now
    return raw;
  }

  Future<void> _testConnection() async {
    final url = _buildRtspUrl();
    if (url.isEmpty) {
      setState(() {
        _testResult = 'Please enter an RTSP URL first.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
      _testSuccess = null;
    });

    final result = await _visionService.testConnection(url);
    if (!mounted) return;

    setState(() {
      _testingConnection = false;
      _testSuccess = result['success'] == true;
      _testResult = result['message']?.toString() ?? 'Unknown result';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await _cameraService.addCamera(
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        cameraType: 'ip',
        streamUrl: _buildRtspUrl(),
        provider: 'rtsp',
        aiEnabled: _aiEnabled,
        settings: {
          'source': _buildRtspUrl(),
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Add Camera',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _section('Camera Info'),
            _field(
              controller: _nameCtrl,
              label: 'Camera Name',
              hint: 'Front Store Camera',
              icon: Icons.videocam_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _locationCtrl,
              label: 'Location',
              hint: 'Main entrance, stockroom…',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 24),
            _section('Stream Configuration'),
            _field(
              controller: _rtspCtrl,
              label: 'RTSP URL',
              hint: 'rtsp://192.168.1.100:554/stream1',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'RTSP URL required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _usernameCtrl,
              label: 'Camera Username (optional)',
              hint: 'admin',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _passwordCtrl,
              label: 'Camera Password (optional)',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            // Test Connection button
            OutlinedButton.icon(
              onPressed: _testingConnection ? null : _testConnection,
              icon: _testingConnection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(
                _testingConnection ? 'Testing…' : 'Test Connection',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_testResult != null) ...[  
              const SizedBox(height: 10),
              _testBanner(),
            ],
            const SizedBox(height: 24),
            _section('AI Settings'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Enable AI Detection',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                subtitle: const Text(
                  'AI will detect people, objects and generate security events',
                  style: TextStyle(fontSize: 12, color: _muted),
                ),
                value: _aiEnabled,
                activeThumbColor: _blue,
                onChanged: (v) => setState(() => _aiEnabled = v),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 2),
        ),
      ),
    );
  }

  Widget _testBanner() {
    final success = _testSuccess ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: success
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResult!,
              style: TextStyle(
                fontSize: 13,
                color: success
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
