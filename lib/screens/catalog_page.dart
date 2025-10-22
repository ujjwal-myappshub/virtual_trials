import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_detail_page.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jewelry Items')),
      body: ListView.builder(
        itemCount: demoProducts.length,
        itemBuilder: (context, index) {
          final p = demoProducts[index];
          final icon = p.type == JewelryType.earring
              ? Icons.earbuds
              : p.type == JewelryType.necklace
                  ? Icons.diamond
                  : Icons.circle_outlined;
          return ListTile(
            leading: Icon(icon),
            title: Text(p.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)),
            ),
          );
        },
      ),
    );
  }
}
