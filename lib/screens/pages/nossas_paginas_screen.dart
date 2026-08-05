import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/awake_app_bar.dart';

class NossasPaginasScreen extends StatelessWidget {
  const NossasPaginasScreen({super.key});

  Future<void> _abrir(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AwakeAppBar(title: 'Nossas páginas', showQrButton: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('Shallom', style: Theme.of(context).textTheme.titleMedium),
          ),
          _paginaTile(
            context,
            icon: Icons.camera_alt_outlined,
            titulo: 'Instagram Shallom',
            url: 'https://www.instagram.com/comunidade.shallom?igsh=bGI2aWtvMjBnNTR2&utm_source=qr',
          ),
          _paginaTile(
            context,
            icon: Icons.facebook_outlined,
            titulo: 'Facebook Shallom',
            url: 'https://www.facebook.com/share/19MdKoMhtj/?mibextid=wwXIfr',
          ),
          _paginaTile(
            context,
            icon: Icons.play_circle_outline,
            titulo: 'YouTube Shallom',
            url: 'https://youtube.com/@shallomonline?si=qrQh11noUx3nrG5v',
          ),
          _paginaTile(
            context,
            icon: Icons.groups_outlined,
            titulo: 'Comunidade WhatsApp Shallom',
            url: 'https://chat.whatsapp.com/FeYDbZ7Ffn57KwX3zuVmTV',
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('Awake', style: Theme.of(context).textTheme.titleMedium),
          ),
          _paginaTile(
            context,
            icon: Icons.camera_alt_outlined,
            titulo: 'Instagram Awake',
            url: 'https://www.instagram.com/awake.shallom?igsh=MTM2bzc1djkzd291ZQ%3D%3D&utm_source=qr',
          ),
          _paginaTile(
            context,
            icon: Icons.groups_outlined,
            titulo: 'Comunidade WhatsApp Awake',
            url: 'https://chat.whatsapp.com/LMnQVz1CzYoDKiVbDawp7j',
          ),
        ],
      ),
    );
  }

  Widget _paginaTile(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String url,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(titulo),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => _abrir(context, url),
      ),
    );
  }
}