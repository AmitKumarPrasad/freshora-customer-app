import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class CampaignBanners extends StatefulWidget {
  const CampaignBanners({super.key, required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  State<CampaignBanners> createState() => _CampaignBannersState();
}

class _CampaignBannersState extends State<CampaignBanners> {
  final _client = http.Client();
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      const baseUrl = String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://talegaon-fresh-ai-backend.onrender.com');
      final response = await _client
          .get(Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/campaigns'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);
      if (data is! Map || data['banners'] is! List) return;
      final banners = (data['banners'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() => _banners = banners);
    } catch (_) {
      // The catalog remains usable when campaigns cannot be loaded.
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: _banners.length,
        itemBuilder: (context, index) {
          final banner = _banners[index];
          final title = banner['title'] is String ? banner['title'] as String : '';
          final description = banner['description'] is String ? banner['description'] as String : '';
          final imageUrl = banner['image_url'] is String ? banner['image_url'] as String : '';
          final code = banner['promo_code'] is String ? banner['promo_code'] as String : '';
          return Card(
            color: const Color(0xFFE9F1DF),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (description.isNotEmpty)
                        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (code.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Code $code copied')));
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: Text('Copy $code'),
                        ),
                      TextButton(onPressed: widget.onBrowse, child: const Text('Shop now')),
                    ],
                  ),
                ),
                if (imageUrl.startsWith('https://'))
                  SizedBox(
                    width: 100,
                    child: Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.local_offer_outlined)),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
