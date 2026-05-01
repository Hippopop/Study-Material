-- ── 3.1  Full menu with category name and ingredients ────────
CREATE OR REPLACE VIEW v_full_menu AS
SELECT
    mi.item_id,
    c.name                                AS category,
    mi.name                               AS item_name,
    mi.price,
    IF(mi.is_available = 1, 'Yes', 'No')  AS available,
    mi.description,
    COALESCE(
        GROUP_CONCAT(
            CONCAT(ing.name, ' (', mii.quantity_needed, ' ', ing.unit, ')')
            ORDER BY ing.name SEPARATOR ', '
        ),
        'No ingredients listed'
    )                                     AS ingredients
FROM       menu_item mi
JOIN       category  c   ON mi.category_id   = c.category_id
LEFT JOIN  menu_item_ingredient mii ON mi.item_id = mii.item_id
LEFT JOIN  ingredient           ing ON mii.ingredient_id = ing.ingredient_id
GROUP BY
    mi.item_id, c.name, mi.name, mi.price, mi.is_available, mi.description
ORDER BY c.name, mi.name;


-- ── 3.2  Table overview (current occupancy) ─────────────────
CREATE OR REPLACE VIEW v_table_status AS
SELECT
    rt.table_id,
    rt.table_number,
    rt.capacity,
    rt.location,
    rt.status                   AS table_status,
    o.order_id,
    o.customer_name,
    o.status                    AS order_status,
    o.total_amount,
    o.created_at                AS order_opened_at
FROM  restaurant_table rt
LEFT JOIN orders o
    ON rt.table_id = o.table_id
   AND o.status    = 'open';


-- ── 3.3  Active orders with item detail ─────────────────────
CREATE OR REPLACE VIEW v_active_orders AS
SELECT
    o.order_id,
    rt.table_number,
    o.customer_name,
    s.name          AS waiter,
    mi.name         AS item_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal,
    oi.special_note,
    o.status        AS order_status,
    oq.status       AS queue_status,
    o.total_amount
FROM  orders          o
JOIN  restaurant_table rt ON o.table_id  = rt.table_id
JOIN  staff            s  ON o.staff_id  = s.staff_id
JOIN  order_item       oi ON o.order_id  = oi.order_id
JOIN  menu_item        mi ON oi.item_id  = mi.item_id
LEFT JOIN order_queue  oq ON o.order_id  = oq.order_id
WHERE o.status = 'open';


-- ── 3.4  Kitchen queue (pending + in-progress) ──────────────
CREATE OR REPLACE VIEW v_kitchen_queue AS
SELECT
    oq.queue_id,
    oq.order_id,
    rt.table_number,
    o.customer_name,
    oq.status,
    oq.priority,
    oq.estimated_mins,
    oq.created_at   AS queued_at,
    oq.started_at,
    GROUP_CONCAT(
        CONCAT(oi.quantity, 'x ', mi.name)
        ORDER BY mi.name SEPARATOR '  |  '
    )               AS items_summary
FROM  order_queue      oq
JOIN  orders           o   ON oq.order_id  = o.order_id
JOIN  restaurant_table rt  ON o.table_id   = rt.table_id
JOIN  order_item       oi  ON o.order_id   = oi.order_id
JOIN  menu_item        mi  ON oi.item_id   = mi.item_id
WHERE oq.status IN ('pending', 'in-progress')
GROUP BY
    oq.queue_id, oq.order_id, rt.table_number, o.customer_name,
    oq.status, oq.priority, oq.estimated_mins, oq.created_at, oq.started_at
ORDER BY oq.priority ASC, oq.created_at ASC;


-- ── 3.5  Daily revenue summary ──────────────────────────────
CREATE OR REPLACE VIEW v_daily_revenue AS
SELECT
    DATE(p.paid_at)                AS sale_date,
    COUNT(DISTINCT p.order_id)     AS total_orders,
    SUM(p.amount)                  AS total_revenue,
    ROUND(AVG(p.amount), 2)        AS avg_order_value,
    SUM(CASE WHEN p.payment_method = 'cash'   THEN p.amount ELSE 0 END) AS cash_total,
    SUM(CASE WHEN p.payment_method = 'card'   THEN p.amount ELSE 0 END) AS card_total,
    SUM(CASE WHEN p.payment_method = 'mobile' THEN p.amount ELSE 0 END) AS mobile_total
FROM  payment p
GROUP BY DATE(p.paid_at)
ORDER BY sale_date DESC;


-- ── 3.6  Low stock ingredients with affected menu items ──────
CREATE OR REPLACE VIEW v_low_stock_items AS
SELECT
    ing.ingredient_id,
    ing.name                               AS ingredient,
    ing.stock_qty,
    ing.reorder_level,
    ing.unit,
    ROUND(ing.reorder_level - ing.stock_qty, 2)  AS shortage,
    GROUP_CONCAT(
        mi.name ORDER BY mi.name SEPARATOR ' | '
    )                                      AS affected_menu_items
FROM  ingredient ing
JOIN  menu_item_ingredient mii ON ing.ingredient_id = mii.ingredient_id
JOIN  menu_item            mi  ON mii.item_id        = mi.item_id
WHERE ing.stock_qty < ing.reorder_level
GROUP BY
    ing.ingredient_id, ing.name, ing.stock_qty,
    ing.reorder_level, ing.unit
ORDER BY shortage DESC;


