import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/wallpaper_service.dart';
import '../services/wallpaper_upload_service.dart';

class UploadWallpaperScreen extends StatefulWidget {
  const UploadWallpaperScreen({super.key});

  @override
  State<UploadWallpaperScreen> createState() => _UploadWallpaperScreenState();
}

class _UploadWallpaperScreenState extends State<UploadWallpaperScreen> {
  final _uploadService = WallpaperUploadService();
  final _tagsController = TextEditingController();

  XFile? _selectedImage;
  String _category = kWallpaperCategories.first.id;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _submitted = false;

  @override
  void dispose() {
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _errorMessage = null);
    try {
      final image = await _uploadService.pickImage();
      if (image == null) return;
      setState(() => _selectedImage = image);
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo abrir la galería.');
    }
  }

  Future<void> _submit() async {
    final image = _selectedImage;
    if (image == null) {
      setState(() => _errorMessage = 'Elegí una imagen primero.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await _uploadService.submit(image: image, category: _category, tags: tags);
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });
    } on WallpaperUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo enviar el fondo. Probá de nuevo.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir un fondo')),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Tu fondo quedó pendiente de aprobación.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un moderador lo va a revisar antes de que aparezca en el catálogo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedImage == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Elegir de la galería'),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
        if (_selectedImage != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _pickImage, child: const Text('Cambiar imagen')),
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
          items: kWallpaperCategories
              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}')))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags (separados por coma)',
            hintText: 'nature, sunset, 4k',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mínimo Full HD (1920×1080). Tu fondo queda pendiente de aprobación '
          'antes de aparecer en el catálogo.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar a moderación'),
        ),
      ],
    );
  }
}
