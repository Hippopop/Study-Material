-- ── DEMO 1 : View the menu ───────────────────────────────────
-- SELECT * FROM v_full_menu;

-- ── DEMO 2 : Place an order on Table T01, waiter Bob (id=2) ──
-- CALL sp_place_order(1, 2, 'Mr. Karim', @oid, @msg);
-- SELECT @oid AS order_id, @msg AS result;

-- ── DEMO 3 : Add items to the order ──────────────────────────
-- CALL sp_add_item_to_order(@oid, 1, 2, NULL, @msg);          -- 2× Spring Rolls
-- CALL sp_add_item_to_order(@oid, 4, 1, 'Extra sauce', @msg); -- 1× Grilled Chicken
-- CALL sp_add_item_to_order(@oid, 9, 2, NULL, @msg);          -- 2× Coffee
-- SELECT @msg;

-- ── DEMO 4 : Verify live total (function call) ───────────────
-- SELECT fn_calculate_order_total(@oid) AS live_total;

-- ── DEMO 5 : See active orders ───────────────────────────────
-- SELECT * FROM v_active_orders;

-- ── DEMO 6 : Kitchen picks up the order ──────────────────────
-- CALL sp_update_queue_status(1, 'in-progress', @msg);
-- SELECT @msg;

-- ── DEMO 7 : Kitchen completes the order ─────────────────────
-- CALL sp_update_queue_status(1, 'done', @msg);
-- SELECT @msg;

-- ── DEMO 8 : Process payment ─────────────────────────────────
-- CALL sp_process_payment(@oid, 'cash', 1, @msg);
-- SELECT @msg;

-- ── DEMO 9 : Check table is free again ───────────────────────
-- SELECT * FROM v_table_status;

-- ── DEMO 10 : Revenue for today ──────────────────────────────
-- SELECT * FROM v_daily_revenue;
-- CALL sp_daily_summary(CURDATE());

-- ── DEMO 11 : Full audit trail ───────────────────────────────
-- SELECT * FROM audit_log ORDER BY changed_at;

-- ── DEMO 12 : Toggle item availability ───────────────────────
-- CALL sp_toggle_menu_item(2, @msg);  -- Soup of the Day OFF
-- SELECT @msg;
-- CALL sp_toggle_menu_item(2, @msg);  -- Soup of the Day ON
-- SELECT @msg;

-- ── DEMO 13 : Occupancy metrics ──────────────────────────────
-- SELECT fn_table_occupancy_rate() AS occupancy_pct;
-- SELECT fn_count_orders_by_status('open') AS open_orders;

-- ── DEMO 14 : Cancel an order (rollback test) ────────────────
-- CALL sp_place_order(2, 3, 'Ms. Tania', @oid2, @msg);
-- CALL sp_add_item_to_order(@oid2, 5, 1, NULL, @msg);
-- CALL sp_cancel_order(@oid2, @msg);
-- SELECT @msg;
-- SELECT * FROM v_table_status;   -- T02 should be available again

-- ── DEMO 15 : Add a new menu item ────────────────────────────
-- CALL sp_add_menu_item(2, 'Lamb Chops', 14.00, 'Herb-marinated, medium-rare', @msg);
-- SELECT @msg;
-- SELECT * FROM v_full_menu;

-- ── DEMO 16 : View full menu with ingredients ─────────────────
-- SELECT * FROM v_full_menu;

-- ── DEMO 17 : Check current stock levels ─────────────────────
-- SELECT * FROM v_low_stock_items;

-- ── DEMO 18 : Manually run the low stock check (cursor demo) ──
-- CALL sp_check_low_stock(@disabled, @msg);
-- SELECT @disabled AS items_disabled, @msg AS result;

-- ── DEMO 19 : See which items got disabled ────────────────────
-- SELECT item_id, name, is_available FROM menu_item;

-- ── DEMO 20 : Restock an ingredient and re-enable items ───────
-- CALL sp_restock_ingredient(1, 10.00, @msg);  -- restock chicken breast
-- SELECT @msg;
-- SELECT item_id, name, is_available FROM menu_item;

-- ── DEMO 21 : Place an order and watch stock auto-deduct ───────
-- CALL sp_place_order(2, 2, 'Ms. Tania', @oid3, @msg);
-- CALL sp_add_item_to_order(@oid3, 4, 5, NULL, @msg); -- 5x Grilled Chicken
-- SELECT ingredient_id, name, stock_qty FROM ingredient WHERE ingredient_id IN (1,7);
-- The trigger fires, stock drops, sp_check_low_stock auto-runs

-- ============================================================
-- END OF SCRIPT
-- ============================================================