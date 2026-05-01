DELIMITER $$

-- ── 4.1  fn_calculate_order_total ───────────────────────────
--  Returns the live SUM of all line-item subtotals for an order.
--  Used by procedures to get an accurate total before payment.
CREATE FUNCTION fn_calculate_order_total(p_order_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(subtotal), 0.00)
    INTO   v_total
    FROM   order_item
    WHERE  order_id = p_order_id;

    RETURN v_total;
END$$


-- ── 4.2  fn_is_item_available ───────────────────────────────
--  Returns 1 if the menu item is available, 0 otherwise.
--  Used by sp_add_item_to_order as a guard.
CREATE FUNCTION fn_is_item_available(p_item_id INT)
RETURNS TINYINT(1)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_flag TINYINT(1) DEFAULT 0;

    SELECT is_available INTO v_flag
    FROM   menu_item
    WHERE  item_id = p_item_id;

    RETURN COALESCE(v_flag, 0);
END$$


-- ── 4.3  fn_count_orders_by_status ──────────────────────────
--  Returns the number of orders currently in a given status.
--  E.g.: SELECT fn_count_orders_by_status('open');
CREATE FUNCTION fn_count_orders_by_status(p_status VARCHAR(20))
RETURNS INT
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count
    FROM   orders
    WHERE  status = p_status;

    RETURN v_count;
END$$


-- ── 4.4  fn_table_occupancy_rate ────────────────────────────
--  Returns the percentage of tables currently occupied.
--  E.g.: SELECT fn_table_occupancy_rate();  → 40.00
CREATE FUNCTION fn_table_occupancy_rate()
RETURNS DECIMAL(5,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_total    INT DEFAULT 0;
    DECLARE v_occupied INT DEFAULT 0;

    SELECT COUNT(*) INTO v_total    FROM restaurant_table;
    SELECT COUNT(*) INTO v_occupied FROM restaurant_table WHERE status = 'occupied';

    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND((v_occupied / v_total) * 100, 2);
END$$

-- ── 4.5  fn_check_ingredient_stock ──────────────────────────
--  Returns the current stock quantity for a given ingredient.
--  Used by sp_check_low_stock and the order_item trigger
--  to decide whether to flag a shortage.
--
--  E.g.: SELECT fn_check_ingredient_stock(1);
CREATE FUNCTION fn_check_ingredient_stock(p_ingredient_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_stock DECIMAL(10,2) DEFAULT 0.00;

    SELECT stock_qty INTO v_stock
    FROM   ingredient
    WHERE  ingredient_id = p_ingredient_id;

    RETURN COALESCE(v_stock, 0.00);
END$$

DELIMITER ;


