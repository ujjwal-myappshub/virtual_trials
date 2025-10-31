enum JewelryType { earring, necklace }

class Product {
  final String id;
  final String name;
  final String image;
  final JewelryType type;
  final double price;
  final String description;

  const Product({
    required this.id,
    required this.name,
    required this.image,
    required this.type,
    this.price = 0.0,
    this.description = '',
  });
}

// Sample jewelry products
final List<Product> demoProducts = [
  const Product(
    id: '1',
    name: 'Necklace',
    image: 'assets/jewelry/necklace.png',
    type: JewelryType.necklace,
    price: 299.99,
    description: 'Elegant diamond necklace for special occasions',
  ),
  const Product(
    id: '2',
    name: 'Earrings',
    image: 'assets/jewelry/earring_left.png',
    type: JewelryType.earring,
    price: 199.99,
    description: 'Beautiful gold earrings that match any outfit',
  ),
];
