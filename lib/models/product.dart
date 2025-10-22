enum JewelryType { earring, necklace }

class Product {
  final String name;
  final String image;
  final JewelryType type;

  const Product({
    required this.name,
    required this.image,
    required this.type,
  });
}

// Sample jewelry products
final List<Product> demoProducts = [

  Product(
    name: ' Necklace',
    image: 'assets/jewelry/necklace.png',
    type: JewelryType.necklace,
  ),
  Product(
    name: 'earring',
    image: 'assets/jewelry/earring_right.png',
    type: JewelryType.earring,
  ),
];
