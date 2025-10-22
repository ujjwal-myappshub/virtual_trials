import 'package:flutter/material.dart';
import '../models/product.dart';
import 'product_detail_page.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jewelry Collection')),
      body: ListView.builder(
        itemCount: demoProducts.length,
        itemBuilder: (context, index) {
          final product = demoProducts[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              leading: Image.asset(
                product.image,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
              title: Text(product.name),
              subtitle: Text(product.type.name),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(product: product),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
