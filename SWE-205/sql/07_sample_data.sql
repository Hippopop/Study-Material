-- Categories
INSERT INTO category (name, description) VALUES
    ('Starters',    'Appetizers and light bites'),
    ('Main Course', 'Hearty and filling mains'),
    ('Beverages',   'Hot and cold drinks'),
    ('Desserts',    'Sweet endings');

-- Menu Items
INSERT INTO menu_item (category_id, name, price, description) VALUES
    (1, 'Spring Rolls',         2.50,  'Crispy vegetable rolls with sweet chilli dip'),
    (1, 'Soup of the Day',      3.00,  'Ask your server for today\'s special'),
    (1, 'Chicken Wings',        5.50,  '6 pieces, BBQ glazed'),
    (2, 'Grilled Chicken',      8.50,  'Served with seasonal vegetables and mash'),
    (2, 'Beef Burger',          9.00,  'Angus beef, cheddar, lettuce, tomato'),
    (2, 'Pasta Arrabiata',      7.50,  'Spicy tomato sauce, penne, parmesan'),
    (2, 'Fish & Chips',        10.00,  'Beer-battered cod, mushy peas, tartar sauce'),
    (3, 'Lemonade',             1.80,  'Freshly squeezed'),
    (3, 'Coffee',               2.00,  'House blend, hot or iced'),
    (3, 'Mineral Water',        1.00,  '500ml still or sparkling'),
    (4, 'Chocolate Lava Cake',  4.50,  'Warm centre, vanilla ice cream'),
    (4, 'Cheesecake',           4.00,  'New York style, berry compote');

-- Restaurant Tables
INSERT INTO restaurant_table (table_number, capacity, location) VALUES
    ('T01', 2, 'indoor'),
    ('T02', 4, 'indoor'),
    ('T03', 4, 'indoor'),
    ('T04', 6, 'outdoor'),
    ('T05', 8, 'rooftop');

-- Staff
INSERT INTO staff (name, role, phone, hired_at) VALUES
    ('Alice Rahman',  'manager', '01711-000001', '2023-01-10'),
    ('Bob Hasan',     'waiter',  '01711-000002', '2023-03-15'),
    ('Carol Akter',   'waiter',  '01711-000003', '2023-04-20'),
    ('Dave Ahmed',    'kitchen', '01711-000004', '2023-02-01'),
    ('Eve Begum',     'kitchen', '01711-000005', '2023-05-12');


-- Ingredients
INSERT INTO ingredient (name, stock_qty, unit, reorder_level) VALUES
    ('Chicken breast',  15.00, 'kg',    2.00),
    ('Beef patty',      20.00, 'kg',    3.00),
    ('Pasta',           10.00, 'kg',    1.00),
    ('Tomato sauce',     8.00, 'litre', 1.00),
    ('Cod fillet',      12.00, 'kg',    2.00),
    ('Spring roll wrap', 100,  'piece', 20.00),
    ('Mixed vegetables', 10.00,'kg',    1.00),
    ('Chocolate',        5.00, 'kg',    0.50),
    ('Cream cheese',     4.00, 'kg',    0.50),
    ('Coffee beans',     3.00, 'kg',    0.50),
    ('Lemon',           30,    'piece', 10.00),
    ('Burger bun',      50,    'piece', 10.00),
    ('Bread crumbs',     5.00, 'kg',    0.50);

-- Link ingredients to menu items
-- Spring Rolls (item_id=1)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (1, 6, 2.00),   -- spring roll wrap
    (1, 7, 0.10);   -- mixed vegetables

-- Soup of the Day (item_id=2)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (2, 7, 0.15);   -- mixed vegetables

-- Chicken Wings (item_id=3)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (3, 1, 0.30);   -- chicken breast

-- Grilled Chicken (item_id=4)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (4, 1, 0.25),   -- chicken breast
    (4, 7, 0.10);   -- mixed vegetables

-- Beef Burger (item_id=5)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (5, 2, 0.20),   -- beef patty
    (5, 12, 1.00);  -- burger bun

-- Pasta Arrabiata (item_id=6)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (6, 3, 0.15),   -- pasta
    (6, 4, 0.10);   -- tomato sauce

-- Fish & Chips (item_id=7)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (7, 5, 0.25),   -- cod fillet
    (7, 13, 0.05);  -- bread crumbs

-- Lemonade (item_id=8)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (8, 11, 2.00);  -- lemon

-- Coffee (item_id=9)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (9, 10, 0.02);  -- coffee beans

-- Chocolate Lava Cake (item_id=11)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (11, 8, 0.08);  -- chocolate

-- Cheesecake (item_id=12)
INSERT INTO menu_item_ingredient (item_id, ingredient_id, quantity_needed) VALUES
    (12, 9, 0.10);  -- cream cheese


