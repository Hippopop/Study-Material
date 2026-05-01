DELIMITER $$

-- ── 6.1  BEFORE INSERT on orders ────────────────────────────
--  Database-level guard: signals an error if someone tries to
--  INSERT an order for a non-available table without going
--  through sp_place_order (which also checks, but defense-in-depth).
CREATE TRIGGER trg_before_order_insert
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_tbl_status VARCHAR(20);

    SELECT status INTO v_tbl_status
    FROM   restaurant_table
    WHERE  table_id = NEW.table_id;

    IF v_tbl_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'TRIGGER ERROR: Restaurant table does not exist.';
    END IF;

    IF v_tbl_status != 'available' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'TRIGGER ERROR: Cannot open order – table is not available.';
    END IF;
END$$


-- ── 6.2  AFTER INSERT on orders ─────────────────────────────
--  Automatically:  (a) marks table as occupied
--                  (b) creates kitchen queue entry
--                  (c) writes audit log row
CREATE TRIGGER trg_after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    -- (a) Mark table occupied
    UPDATE restaurant_table
    SET    status = 'occupied'
    WHERE  table_id = NEW.table_id;

    -- (b) Create kitchen queue entry
    INSERT INTO order_queue(order_id, status, priority)
    VALUES (NEW.order_id, 'pending', 5);

    -- (c) Audit
    INSERT INTO audit_log(table_name, action, record_id, new_value)
    VALUES (
        'orders', 'INSERT', NEW.order_id,
        CONCAT('table_id=', NEW.table_id,
               ' | staff_id=', NEW.staff_id,
               ' | customer=', NEW.customer_name)
    );
END$$


-- ── 6.3  AFTER UPDATE on orders ─────────────────────────────
--  Automatically:  (a) frees the table when order closes/cancels
--                  (b) logs status changes to audit_log
CREATE TRIGGER trg_after_order_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- (a) Free table when order finishes
    IF NEW.status IN ('closed','cancelled')
       AND OLD.status NOT IN ('closed','cancelled') THEN

        UPDATE restaurant_table
        SET    status = 'available'
        WHERE  table_id = NEW.table_id;
    END IF;

    -- (b) Audit status changes
    IF NEW.status != OLD.status THEN
        INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
        VALUES (
            'orders', 'UPDATE', NEW.order_id,
            CONCAT('status=', OLD.status),
            CONCAT('status=', NEW.status, ' | total=', NEW.total_amount)
        );
    END IF;
END$$


-- ── 6.4  AFTER INSERT on order_item ─────────────────────────
--  Recalculates orders.total_amount whenever a new line item
--  is added. Uses fn_calculate_order_total() for accuracy.
CREATE TRIGGER trg_after_orderitem_insert
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
    UPDATE orders
    SET    total_amount = fn_calculate_order_total(NEW.order_id)
    WHERE  order_id     = NEW.order_id;
END$$


-- ── 6.5  AFTER UPDATE on order_item ─────────────────────────
--  Recalculates total if quantity or note changes.
CREATE TRIGGER trg_after_orderitem_update
AFTER UPDATE ON order_item
FOR EACH ROW
BEGIN
    UPDATE orders
    SET    total_amount = fn_calculate_order_total(NEW.order_id)
    WHERE  order_id     = NEW.order_id;
END$$


-- ── 6.6  AFTER DELETE on order_item ─────────────────────────
--  Recalculates total if a line item is removed.
CREATE TRIGGER trg_after_orderitem_delete
AFTER DELETE ON order_item
FOR EACH ROW
BEGIN
    UPDATE orders
    SET    total_amount = fn_calculate_order_total(OLD.order_id)
    WHERE  order_id     = OLD.order_id;
END$$


-- ── 6.7  AFTER UPDATE on menu_item ──────────────────────────
--  Logs price changes and availability toggles.
CREATE TRIGGER trg_after_menuitem_update
AFTER UPDATE ON menu_item
FOR EACH ROW
BEGIN
    IF NEW.is_available != OLD.is_available THEN
        INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
        VALUES (
            'menu_item', 'UPDATE', NEW.item_id,
            CONCAT('available=', OLD.is_available),
            CONCAT('available=', NEW.is_available)
        );
    END IF;

    IF NEW.price != OLD.price THEN
        INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
        VALUES (
            'menu_item', 'UPDATE', NEW.item_id,
            CONCAT('price=', OLD.price),
            CONCAT('price=', NEW.price)
        );
    END IF;
END$$


-- ── 6.8  AFTER UPDATE on order_queue ────────────────────────
--  Logs every kitchen status transition.
CREATE TRIGGER trg_after_queue_update
AFTER UPDATE ON order_queue
FOR EACH ROW
BEGIN
    IF NEW.status != OLD.status THEN
        INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
        VALUES (
            'order_queue', 'UPDATE', NEW.queue_id,
            CONCAT('status=', OLD.status),
            CONCAT('status=', NEW.status,
                   CASE WHEN NEW.status = 'in-progress'
                        THEN CONCAT(' | started_at=', COALESCE(NEW.started_at,'?'))
                        ELSE '' END,
                   CASE WHEN NEW.status = 'done'
                        THEN CONCAT(' | completed_at=', COALESCE(NEW.completed_at,'?'))
                        ELSE '' END)
        );
    END IF;
END$$

-- ── 6.9  AFTER INSERT on order_item (stock deduction) ────────
--  When a new order_item row is inserted, deducts the required
--  ingredient quantities from stock based on how many portions
--  were ordered. After deduction, calls sp_check_low_stock
--  to automatically disable any menu items that are now low.
CREATE TRIGGER trg_after_orderitem_stock_deduct
AFTER INSERT ON order_item
FOR EACH ROW
BEGIN
    -- Deduct stock for every ingredient used by this menu item
    UPDATE ingredient ing
    JOIN   menu_item_ingredient mii ON ing.ingredient_id = mii.ingredient_id
    SET    ing.stock_qty = ing.stock_qty - (mii.quantity_needed * NEW.quantity)
    WHERE  mii.item_id = NEW.item_id
      AND  ing.stock_qty > 0;

    -- Trigger the low stock check after every order item insertion
    BEGIN
        DECLARE v_disabled INT;
        DECLARE v_msg      VARCHAR(255);
        CALL sp_check_low_stock(v_disabled, v_msg);
    END;
END$$

DELIMITER ;


