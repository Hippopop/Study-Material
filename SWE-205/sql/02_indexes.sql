-- menu_item
CREATE INDEX idx_item_category  ON menu_item (category_id);
CREATE INDEX idx_item_available ON menu_item (is_available);

-- orders
CREATE INDEX idx_order_table    ON orders (table_id);
CREATE INDEX idx_order_status   ON orders (status);
CREATE INDEX idx_order_created  ON orders (created_at);

-- order_item
CREATE INDEX idx_oi_order       ON order_item (order_id);
CREATE INDEX idx_oi_item        ON order_item (item_id);

-- order_queue
CREATE INDEX idx_queue_status   ON order_queue (status, priority);

-- audit_log
CREATE INDEX idx_audit_table    ON audit_log (table_name, changed_at);

-- ingredient
CREATE INDEX idx_ingredient_stock  ON ingredient (stock_qty);

-- menu_item_ingredient
CREATE INDEX idx_mii_item          ON menu_item_ingredient (item_id);
CREATE INDEX idx_mii_ingredient    ON menu_item_ingredient (ingredient_id);


