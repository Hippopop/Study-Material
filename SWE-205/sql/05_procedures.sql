DELIMITER $$

-- ── 5.1  sp_place_order ─────────────────────────────────────
--  Creates a new order for a table.
--  Uses: START TRANSACTION + SELECT … FOR UPDATE (row-level lock)
--        to prevent two concurrent orders on the same table.
--  The AFTER INSERT trigger on orders automatically creates the
--  kitchen queue entry and marks the table as occupied.
--
--  Usage:
--    CALL sp_place_order(1, 2, 'Mr. Karim', @order_id, @msg);
--    SELECT @order_id, @msg;
CREATE PROCEDURE sp_place_order(
    IN  p_table_id    INT,
    IN  p_staff_id    INT,
    IN  p_customer    VARCHAR(100),
    OUT p_order_id    INT,
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_table_status VARCHAR(20);

    -- Exit handler: rollback on any SQL error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_message  = 'ERROR: Transaction rolled back due to an unexpected error.';
    END;

    START TRANSACTION;

    -- Row-level lock prevents concurrent orders on the same table
    SELECT status INTO v_table_status
    FROM   restaurant_table
    WHERE  table_id = p_table_id
    FOR UPDATE;

    IF v_table_status IS NULL THEN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_message  = 'ERROR: Table not found.';

    ELSEIF v_table_status != 'available' THEN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_message  = CONCAT('ERROR: Table is currently [', v_table_status, ']. Cannot place order.');

    ELSE
        INSERT INTO orders(table_id, staff_id, customer_name)
        VALUES (p_table_id, p_staff_id, COALESCE(NULLIF(TRIM(p_customer),''), 'Walk-in'));

        SET p_order_id = LAST_INSERT_ID();

        -- trg_after_order_insert handles:
        --   • table status → 'occupied'
        --   • queue entry creation
        --   • audit log entry

        COMMIT;
        SET p_message = CONCAT('SUCCESS: Order #', p_order_id, ' placed for table ', p_table_id, '.');
    END IF;
END$$


-- ── 5.2  sp_add_item_to_order ───────────────────────────────
--  Adds a menu item to an existing open order.
--  Checks: order must be open; item must be available.
--  Triggers on order_item automatically update orders.total_amount.
--
--  Usage:
--    CALL sp_add_item_to_order(1, 3, 2, 'Less spicy', @msg);
CREATE PROCEDURE sp_add_item_to_order(
    IN  p_order_id   INT,
    IN  p_item_id    INT,
    IN  p_quantity   INT,
    IN  p_note       VARCHAR(255),
    OUT p_message    VARCHAR(255)
)
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_item_price   DECIMAL(10,2);
    DECLARE v_item_avail   TINYINT(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'ERROR: Could not add item. Transaction rolled back.';
    END;

    START TRANSACTION;

    -- Lock order row
    SELECT status
    INTO   v_order_status
    FROM   orders
    WHERE  order_id = p_order_id
    FOR UPDATE;

    -- Fetch item details
    SELECT price, is_available
    INTO   v_item_price, v_item_avail
    FROM   menu_item
    WHERE  item_id = p_item_id;

    IF v_order_status IS NULL THEN
        ROLLBACK;
        SET p_message = 'ERROR: Order not found.';

    ELSEIF v_order_status != 'open' THEN
        ROLLBACK;
        SET p_message = CONCAT('ERROR: Order is [', v_order_status, ']. Cannot add items.');

    ELSEIF v_item_price IS NULL THEN
        ROLLBACK;
        SET p_message = 'ERROR: Menu item not found.';

    ELSEIF fn_is_item_available(p_item_id) = 0 THEN
        ROLLBACK;
        SET p_message = 'ERROR: Item is currently unavailable.';

    ELSEIF COALESCE(p_quantity, 0) <= 0 THEN
        ROLLBACK;
        SET p_message = 'ERROR: Quantity must be at least 1.';

    ELSE
        INSERT INTO order_item(order_id, item_id, quantity, unit_price, special_note)
        VALUES (p_order_id, p_item_id, p_quantity, v_item_price, p_note);

        -- trg_after_orderitem_insert fires here → updates orders.total_amount

        COMMIT;
        SET p_message = CONCAT('SUCCESS: Added ', p_quantity, ' item(s) to order #', p_order_id, '.');
    END IF;
END$$


-- ── 5.3  sp_update_queue_status ─────────────────────────────
--  Moves a kitchen queue entry through its lifecycle.
--  Automatically records started_at and completed_at timestamps.
--
--  Usage:
--    CALL sp_update_queue_status(1, 'in-progress', @msg);
--    CALL sp_update_queue_status(1, 'done', @msg);
CREATE PROCEDURE sp_update_queue_status(
    IN  p_queue_id INT,
    IN  p_status   ENUM('pending','in-progress','done'),
    OUT p_message  VARCHAR(255)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'ERROR: Queue update failed.';
    END;

    SELECT COUNT(*) INTO v_exists
    FROM   order_queue
    WHERE  queue_id = p_queue_id;

    IF v_exists = 0 THEN
        SET p_message = 'ERROR: Queue entry not found.';
    ELSE
        START TRANSACTION;

        UPDATE order_queue
        SET
            status       = p_status,
            started_at   = CASE
                               WHEN p_status = 'in-progress' AND started_at IS NULL
                               THEN NOW()
                               ELSE started_at
                           END,
            completed_at = CASE
                               WHEN p_status = 'done'
                               THEN NOW()
                               ELSE completed_at
                           END
        WHERE queue_id = p_queue_id;

        -- trg_after_queue_update fires → writes to audit_log

        COMMIT;
        SET p_message = CONCAT('SUCCESS: Queue #', p_queue_id, ' status → [', p_status, '].');
    END IF;
END$$


-- ── 5.4  sp_process_payment ─────────────────────────────────
--  Pays an open order.
--  Demonstrates: transaction, row lock, function call, rollback.
--  After commit, trg_after_order_update frees the table.
--
--  Usage:
--    CALL sp_process_payment(1, 'cash', 1, @msg);
CREATE PROCEDURE sp_process_payment(
    IN  p_order_id  INT,
    IN  p_method    ENUM('cash','card','mobile'),
    IN  p_staff_id  INT,
    OUT p_message   VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_total  DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'ERROR: Payment failed. Transaction rolled back.';
    END;

    START TRANSACTION;

    -- Lock the order to prevent concurrent payment
    SELECT status, total_amount
    INTO   v_status, v_total
    FROM   orders
    WHERE  order_id = p_order_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SET p_message = 'ERROR: Order not found.';

    ELSEIF v_status != 'open' THEN
        ROLLBACK;
        SET p_message = CONCAT('ERROR: Order is already [', v_status, '].');

    ELSE
        -- Recalculate from source of truth
        SET v_total = fn_calculate_order_total(p_order_id);

        IF v_total <= 0 THEN
            ROLLBACK;
            SET p_message = 'ERROR: Order has no items. Cannot process payment.';
        ELSE
            INSERT INTO payment(order_id, amount, payment_method, received_by)
            VALUES (p_order_id, v_total, p_method, p_staff_id);

            UPDATE orders
            SET    status       = 'closed',
                   total_amount = v_total
            WHERE  order_id     = p_order_id;

            -- trg_after_order_update fires → marks table as 'available'

            COMMIT;
            SET p_message = CONCAT(
                'SUCCESS: Payment of BDT ', v_total,
                ' received via [', p_method, '] for order #', p_order_id, '.'
            );
        END IF;
    END IF;
END$$


-- ── 5.5  sp_cancel_order ────────────────────────────────────
--  Cancels an open or billed order and frees the table.
--
--  Usage:
--    CALL sp_cancel_order(2, @msg);
CREATE PROCEDURE sp_cancel_order(
    IN  p_order_id INT,
    OUT p_message  VARCHAR(255)
)
BEGIN
    DECLARE v_status   VARCHAR(20);
    DECLARE v_table_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'ERROR: Cancel failed. Transaction rolled back.';
    END;

    START TRANSACTION;

    SELECT status, table_id
    INTO   v_status, v_table_id
    FROM   orders
    WHERE  order_id = p_order_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SET p_message = 'ERROR: Order not found.';

    ELSEIF v_status IN ('closed', 'cancelled') THEN
        ROLLBACK;
        SET p_message = CONCAT('ERROR: Order is already [', v_status, ']. Cannot cancel.');

    ELSE
        UPDATE orders
        SET    status = 'cancelled'
        WHERE  order_id = p_order_id;

        -- trg_after_order_update handles table status reset

        UPDATE order_queue
        SET    status = 'done', completed_at = NOW()
        WHERE  order_id = p_order_id AND status != 'done';

        COMMIT;
        SET p_message = CONCAT('SUCCESS: Order #', p_order_id, ' cancelled. Table T', v_table_id, ' freed.');
    END IF;
END$$


-- ── 5.6  sp_toggle_menu_item ────────────────────────────────
--  Flips a menu item's availability on/off.
--  trg_after_menuitem_update logs the change automatically.
--
--  Usage:
--    CALL sp_toggle_menu_item(2, @msg);
CREATE PROCEDURE sp_toggle_menu_item(
    IN  p_item_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_current TINYINT(1);
    DECLARE v_name    VARCHAR(150);

    SELECT is_available, name
    INTO   v_current, v_name
    FROM   menu_item
    WHERE  item_id = p_item_id;

    IF v_current IS NULL THEN
        SET p_message = 'ERROR: Menu item not found.';
    ELSE
        UPDATE menu_item
        SET    is_available = IF(is_available = 1, 0, 1)
        WHERE  item_id      = p_item_id;

        SET p_message = CONCAT(
            'SUCCESS: [', v_name, '] is now ',
            IF(v_current = 1, 'UNAVAILABLE', 'AVAILABLE'), '.'
        );
    END IF;
END$$


-- ── 5.7  sp_add_menu_item ───────────────────────────────────
--  Inserts a new item into the menu.
--
--  Usage:
--    CALL sp_add_menu_item(2, 'Fish & Chips', 11.00, 'Classic British dish', @msg);
CREATE PROCEDURE sp_add_menu_item(
    IN  p_category_id INT,
    IN  p_name        VARCHAR(150),
    IN  p_price       DECIMAL(10,2),
    IN  p_description VARCHAR(255),
    OUT p_message     VARCHAR(255)
)
BEGIN
    DECLARE v_cat_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_cat_exists
    FROM   category
    WHERE  category_id = p_category_id;

    IF v_cat_exists = 0 THEN
        SET p_message = 'ERROR: Category not found.';
    ELSEIF p_price < 0 THEN
        SET p_message = 'ERROR: Price cannot be negative.';
    ELSE
        INSERT INTO menu_item(category_id, name, price, description)
        VALUES (p_category_id, p_name, p_price, p_description);

        SET p_message = CONCAT('SUCCESS: [', p_name, '] added to menu.');
    END IF;
END$$


-- ── 5.8  sp_daily_summary ───────────────────────────────────
--  Prints a summary for a given date (defaults to today).
--  Demonstrates calling stored functions inside a procedure.
--
--  Usage:
--    CALL sp_daily_summary(CURDATE());
--    CALL sp_daily_summary('2025-05-01');
CREATE PROCEDURE sp_daily_summary(IN p_date DATE)
BEGIN
    SELECT
        COALESCE(p_date, CURDATE())              AS report_date,
        COALESCE(COUNT(DISTINCT p.order_id), 0)  AS paid_orders,
        COALESCE(SUM(p.amount), 0)               AS total_revenue,
        COALESCE(ROUND(AVG(p.amount),2), 0)      AS avg_order_value,
        fn_count_orders_by_status('open')        AS currently_open_orders,
        fn_table_occupancy_rate()                AS table_occupancy_pct
    FROM payment p
    WHERE DATE(p.paid_at) = COALESCE(p_date, CURDATE());
END$$

-- ── 5.9  sp_restock_ingredient ───────────────────────────────
--  Adds stock to an ingredient and re-enables any menu items
--  that were disabled due to that ingredient being low.
--  After restocking, only re-enables items whose ALL ingredients
--  are now sufficiently stocked.
--
--  Usage:
--    CALL sp_restock_ingredient(1, 10.00, @msg);
CREATE PROCEDURE sp_restock_ingredient(
    IN  p_ingredient_id INT,
    IN  p_qty_to_add    DECIMAL(10,2),
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_exists    INT DEFAULT 0;
    DECLARE v_ing_name  VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'ERROR: Restock failed. Transaction rolled back.';
    END;

    SELECT COUNT(*), name
    INTO   v_exists, v_ing_name
    FROM   ingredient
    WHERE  ingredient_id = p_ingredient_id;

    IF v_exists = 0 THEN
        SET p_message = 'ERROR: Ingredient not found.';

    ELSEIF COALESCE(p_qty_to_add, 0) <= 0 THEN
        SET p_message = 'ERROR: Quantity to add must be greater than 0.';

    ELSE
        START TRANSACTION;

        -- Add stock
        UPDATE ingredient
        SET    stock_qty = stock_qty + p_qty_to_add
        WHERE  ingredient_id = p_ingredient_id;

        -- Re-enable menu items that now have all ingredients sufficiently stocked
        UPDATE menu_item mi
        SET    mi.is_available = 1
        WHERE  mi.is_available = 0
          AND  mi.item_id IN (SELECT mii.item_id
                              FROM   menu_item_ingredient mii
                              WHERE  mii.ingredient_id = p_ingredient_id)
          AND  NOT EXISTS (
                    SELECT 1
                    FROM   menu_item_ingredient mii2
                    JOIN   ingredient ing ON mii2.ingredient_id = ing.ingredient_id
                    WHERE  mii2.item_id = mi.item_id
                      AND  ing.stock_qty < ing.reorder_level
               );

        -- Log the restock
        INSERT INTO audit_log(table_name, action, record_id, new_value)
        VALUES (
            'ingredient', 'UPDATE', p_ingredient_id,
            CONCAT('restocked=', p_qty_to_add, ' | ingredient=', v_ing_name)
        );

        COMMIT;
        SET p_message = CONCAT(
            'SUCCESS: Added ', p_qty_to_add, ' units to [', v_ing_name, ']. ',
            'Affected menu items re-evaluated.'
        );
    END IF;
END$$


-- ── 5.10  sp_check_low_stock ─────────────────────────────────
--  CURSOR-based procedure.
--  Iterates through every ingredient below its reorder_level.
--  For each low ingredient, disables all linked menu items
--  and logs the action to audit_log.
--
--  This demonstrates: CURSOR, FETCH, DECLARE CONTINUE HANDLER
--  for NOT FOUND, row-by-row conditional logic with side effects.
--
--  Usage:
--    CALL sp_check_low_stock(@disabled_count, @msg);
CREATE PROCEDURE sp_check_low_stock(
    OUT p_disabled_count INT,
    OUT p_message        VARCHAR(255)
)
BEGIN
    -- Cursor variables
    DECLARE v_done          INT DEFAULT 0;
    DECLARE v_ingredient_id INT;
    DECLARE v_ing_name      VARCHAR(100);
    DECLARE v_stock         DECIMAL(10,2);
    DECLARE v_reorder       DECIMAL(10,2);

    -- Counter
    DECLARE v_total_disabled INT DEFAULT 0;
    DECLARE v_items_disabled INT DEFAULT 0;

    -- Cursor: fetch all ingredients below reorder level
    DECLARE cur CURSOR FOR
        SELECT ingredient_id, name, stock_qty, reorder_level
        FROM   ingredient
        WHERE  stock_qty < reorder_level;

    -- When cursor runs out of rows, set flag instead of throwing error
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur;

    -- ── Cursor loop ──────────────────────────────────────────
    fetch_loop: LOOP
        FETCH cur INTO v_ingredient_id, v_ing_name, v_stock, v_reorder;

        -- Exit when no more rows
        IF v_done = 1 THEN
            LEAVE fetch_loop;
        END IF;

        -- Disable all menu items that use this ingredient
        -- and are still marked available
        UPDATE menu_item
        SET    is_available = 0
        WHERE  is_available = 1
          AND  item_id IN (
                    SELECT item_id
                    FROM   menu_item_ingredient
                    WHERE  ingredient_id = v_ingredient_id
               );

        -- Count how many items were actually disabled this iteration
        SET v_items_disabled = ROW_COUNT();
        SET v_total_disabled  = v_total_disabled + v_items_disabled;

        -- Log per ingredient
        INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
        VALUES (
            'ingredient', 'UPDATE', v_ingredient_id,
            CONCAT('stock=', v_stock, ' | reorder_level=', v_reorder),
            CONCAT('status=LOW | items_disabled=', v_items_disabled,
                   ' | ingredient=', v_ing_name)
        );

    END LOOP fetch_loop;

    CLOSE cur;

    -- Set output
    SET p_disabled_count = v_total_disabled;
    SET p_message = CONCAT(
        'SUCCESS: Stock check complete. ',
        v_total_disabled, ' menu item(s) disabled due to low ingredients.'
    );
END$$

DELIMITER ;


