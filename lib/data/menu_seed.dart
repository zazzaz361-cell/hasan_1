import '../models/restaurant.dart';

const seedCategories = <Category>[
  Category(id: 'rizo', nameAr: 'الريزو', sortOrder: 0),
  Category(id: 'chicken', nameAr: 'الدجاج', sortOrder: 1),
  Category(id: 'pizza', nameAr: 'البيتزا', sortOrder: 2),
  Category(id: 'appetizers', nameAr: 'المقبلات', sortOrder: 3),
  Category(id: 'drinks', nameAr: 'المشروبات', sortOrder: 4),
  Category(id: 'burger', nameAr: 'البركر', sortOrder: 5),
  Category(id: 'sandwiches', nameAr: 'السندويشات', sortOrder: 6),
  Category(id: 'meals', nameAr: 'الوجبات', sortOrder: 7),
  Category(id: 'shawarma', nameAr: 'الشاورما', sortOrder: 8),
  Category(id: 'funker', nameAr: 'الفنكر', sortOrder: 9),
];

Product _item(String id, String category, String name, int price) =>
    Product(id: id, categoryId: category, nameAr: name, price: price);

List<Product> get seedProducts => [
  _item('rizo-dari', 'rizo', 'ريزو كرسبي داري', 5000),
  _item('rizo-smoked', 'rizo', 'ريزو كرسبي مدخن', 5000),
  _item('rizo-chicken-shawarma', 'rizo', 'ريزو شاورما دجاج', 5000),
  _item('rizo-meat-shawarma', 'rizo', 'ريزو شاورما لحم', 6000),
  _item('chicken-full-rice', 'chicken', 'دجاجة مع تمن', 16000),
  _item('chicken-full-no-rice', 'chicken', 'دجاجة بدون تمن', 14000),
  _item('chicken-half-rice', 'chicken', 'نصف دجاجة مع تمن', 10000),
  _item('chicken-half-no-rice', 'chicken', 'نصف دجاجة بدون تمن', 8000),
  _item('wings-full-rice', 'chicken', 'نفر أجنحة دجاج مع تمن', 16000),
  _item('wings-full-no-rice', 'chicken', 'نفر أجنحة بدون تمن', 10000),
  _item('wings-half-rice', 'chicken', 'نصف نفر أجنحة مع تمن', 9000),
  _item('wings-half-no-rice', 'chicken', 'نصف نفر أجنحة بدون تمن', 7000),
  ..._pizzaItems(),
  _item('app-large', 'appetizers', 'مقبلات كبير', 5000),
  _item('app-medium', 'appetizers', 'مقبلات وسط', 3500),
  _item('app-small', 'appetizers', 'مقبلات صغير', 2500),
  _item('hummus', 'appetizers', 'حمص بطحينة', 2000),
  _item('tabbouleh', 'appetizers', 'تبولة', 2500),
  _item('eggplant', 'appetizers', 'باذنجانية', 2000),
  _item('sausage', 'appetizers', 'نقانق', 2000),
  _item('jajik', 'appetizers', 'جاجيك', 2000),
  _item('coleslaw', 'appetizers', 'كولسلو', 2500),
  _item('pepsi', 'drinks', 'بيبسي', 500),
  _item('dew', 'drinks', 'ديو', 500),
  _item('mirinda-orange', 'drinks', 'ميرندا برتقال', 500),
  _item('mirinda-apple', 'drinks', 'ميرندا تفاح', 500),
  _item('seven-up', 'drinks', 'سفن', 500),
  _item('burger-classic', 'burger', 'بركر كلاسيك', 4500),
  _item('burger-bbq', 'burger', 'بركر باربكيو', 4500),
  _item('burger-smoked', 'burger', 'بركر مدخن', 4500),
  _item('burger-dari', 'burger', 'بركر داري', 4500),
  _item('burger-chicken', 'burger', 'بركر دجاج', 4000),
  _item('burger-chicken-jumbo', 'burger', 'بركر دجاج جامبو', 6000),
  _item('burger-meat-jumbo', 'burger', 'بركر لحم جامبو', 7000),
  _item('sandwich-zinger', 'sandwiches', 'سندويش زنجر', 4000),
  _item('sandwich-fajita', 'sandwiches', 'سندويش فاهيتا', 4000),
  _item('sandwich-hawi', 'sandwiches', 'سندويش هاوي', 4000),
  _item('sandwich-chicken-sub', 'sandwiches', 'سندويش چكن ساب', 4000),
  _item('sandwich-jalapeno', 'sandwiches', 'سندويش تشيكن هالبينو', 4000),
  _item('meal-zinger', 'meals', 'وجبة زنجر', 5000),
  _item('meal-fajita', 'meals', 'وجبة فاهيتا دجاج', 5000),
  _item('meal-chicken-sub', 'meals', 'وجبة چكن ساب', 5000),
  _item('meal-filo', 'meals', 'وجبة فيلو', 5000),
  _item('meal-hawi', 'meals', 'وجبة هاوي', 5000),
  _item('meal-jalapeno', 'meals', 'وجبة تشيكن هالبينو', 5000),
  _item('shawarma-chicken-sandwich', 'shawarma', 'سندويش شاورما دجاج', 2500),
  _item('shawarma-meat-sandwich', 'shawarma', 'سندويش شاورما لحم', 3000),
  _item('saj-chicken', 'shawarma', 'صاج دجاج', 3000),
  _item('saj-meat', 'shawarma', 'صاج لحم', 4000),
  _item('arabic-chicken', 'shawarma', 'وجبة عربي دجاج', 5000),
  _item('arabic-meat', 'shawarma', 'وجبة عربي لحم', 6000),
  _item('jumbo-meat', 'shawarma', 'وجبة جامبو لحم', 10000),
  _item('jumbo-chicken', 'shawarma', 'وجبة جامبو دجاج', 9000),
  _item('funker-large', 'funker', 'فنكر كبير', 4000),
  _item('funker-medium', 'funker', 'فنكر وسط', 2500),
  _item('funker-small', 'funker', 'فنكر صغير', 1500),
];

List<Product> _pizzaItems() {
  const pizzaTypes = [
    ('chicken', 'بيتزا دجاج', 5000, 8000, 11000),
    ('meat', 'بيتزا لحم', 6000, 10000, 13000),
    ('pepperoni', 'بيتزا بيبروني', 5000, 8000, 11000),
    ('mixed', 'بيتزا مشكل', 6000, 10000, 13000),
    ('margherita', 'بيتزا مارغريتا', 5000, 7000, 10000),
    ('vegetable', 'بيتزا خضار', 4000, 7000, 10000),
    ('four-seasons', 'بيتزا فصول الأربعة', 6000, 10000, 13000),
  ];

  return [
    for (final (id, name, small, medium, large) in pizzaTypes)
      Product(
        id: 'pizza-$id',
        categoryId: 'pizza',
        nameAr: name,
        price: small,
        variants: [
          ProductVariant(nameAr: 'صغير', price: small),
          ProductVariant(nameAr: 'وسط', price: medium),
          ProductVariant(nameAr: 'كبير', price: large),
        ],
      ),
  ];
}
