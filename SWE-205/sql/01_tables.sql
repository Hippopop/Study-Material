-- ── 1.1  category ───────────────────────────────────────────
--  No dependencies on other tables.
--  All attributes depend solely on category_id  →  BCNF
CREATE TABLE category (
    category_id  INT          AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE,
    description  VARCHAR(255),
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
); -- NOTE: Menu categories – standalone lookup table.


-- ── 1.2  menu_item ──────────────────────────────────────────
--  category_id is an FK, not part of PK  →  no partial dep  →  2NF
--  price / name / description depend only on item_id       →  3NF
CREATE TABLE menu_item (
    item_id      INT            AUTO_INCREMENT PRIMARY KEY,
    category_id  INT            NOT NULL,
    name         VARCHAR(150)   NOT NULL,
    price        DECIMAL(10,2)  NOT NULL,
    is_available TINYINT(1)     NOT NULL DEFAULT 1,
    description  VARCHAR(255),
    created_at   TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_item_price   CHECK (price >= 0),
    CONSTRAINT fk_item_category FOREIGN KEY (category_id)
        REFERENCES category(category_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
); -- NOTE: Menu items – price changes do not affect past orders (snapshot pattern).


-- ── 1.3  restaurant_table ───────────────────────────────────
--  All attributes describe the physical table only  →  3NF / BCNF
CREATE TABLE restaurant_table (
    table_id     INT          AUTO_INCREMENT PRIMARY KEY,
    table_number VARCHAR(10)  NOT NULL UNIQUE,
    capacity     INT          NOT NULL,
    status       ENUM('available','occupied','reserved')
                              NOT NULL DEFAULT 'available',
    location     VARCHAR(100), -- indoor | outdoor | rooftop
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_table_cap CHECK (capacity > 0)
); -- NOTE: Physical dining tables – status managed by triggers.


-- ── 1.4  staff ──────────────────────────────────────────────
--  Separated from orders to avoid transitive dependency  →  3NF
CREATE TABLE staff (
    staff_id   INT          AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    role       ENUM('waiter','kitchen','manager') NOT NULL,
    phone      VARCHAR(20)  UNIQUE,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    hired_at   DATE,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
); -- NOTE: Restaurant employees – normalized separately from orders.


-- ── 1.5  orders ─────────────────────────────────────────────
--  table_id, staff_id are FKs only.
--  total_amount is maintained by triggers (documented deviation).
--  No non-key attr depends on another non-key attr  →  3NF
CREATE TABLE orders (
    order_id      INT            AUTO_INCREMENT PRIMARY KEY,
    table_id      INT            NOT NULL,
    staff_id      INT            NOT NULL,
    customer_name VARCHAR(100)   NOT NULL DEFAULT 'Walk-in',
    status        ENUM('open','billed','closed','cancelled')
                                 NOT NULL DEFAULT 'open',
    total_amount  DECIMAL(10,2)  NOT NULL DEFAULT 0.00
                                 -- NOTE: Kept in sync by triggers on order_item.
    notes         TEXT,
    created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_table FOREIGN KEY (table_id)
        REFERENCES restaurant_table(table_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_order_staff FOREIGN KEY (staff_id)
        REFERENCES staff(staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
); -- NOTE: One row per customer session / table sitting.


-- ── 1.6  order_item ─────────────────────────────────────────
--  Composite candidate key (order_id, item_id) but we use a
--  surrogate PK (order_item_id) to allow duplicate items
--  with different notes.
--
--  unit_price is a SNAPSHOT of menu_item.price at order time.
--  It depends on order_item_id (not on item_id alone) → 2NF ✔
--
--  subtotal = quantity × unit_price  →  STORED GENERATED column
--  (documented deviation: stored for query performance)
CREATE TABLE order_item (
    order_item_id INT            AUTO_INCREMENT PRIMARY KEY,
    order_id      INT            NOT NULL,
    item_id       INT            NOT NULL,
    quantity      INT            NOT NULL DEFAULT 1,
    unit_price    DECIMAL(10,2)  NOT NULL,
                                 -- NOTE: Price frozen at time of ordering.
    subtotal      DECIMAL(10,2)
                  GENERATED ALWAYS AS (quantity * unit_price) STORED
                  -- NOTE: Auto-computed; triggers use this to update orders.total_amount.
    special_note  VARCHAR(255),
    created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_oi_qty  CHECK (quantity > 0),

    CONSTRAINT fk_oi_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_oi_item  FOREIGN KEY (item_id)
        REFERENCES menu_item(item_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) -- NOTE: Order line items – price snapshot ensures historical accuracy.


-- ── 1.7  order_queue ────────────────────────────────────────
--  Separated from orders (Single Responsibility).
--  Queue metadata (priority, timestamps) does not depend on
--  order details  →  3NF.  1:1 with orders via UNIQUE.
CREATE TABLE order_queue (
    queue_id       INT              AUTO_INCREMENT PRIMARY KEY,
    order_id       INT              NOT NULL UNIQUE,
    status         ENUM('pending','in-progress','done')
                                    NOT NULL DEFAULT 'pending',
    priority       TINYINT UNSIGNED NOT NULL DEFAULT 5
                                    -- NOTE: 1 = urgent  10 = low.
    estimated_mins SMALLINT         NOT NULL DEFAULT 15,
    started_at     TIMESTAMP        NULL,
    completed_at   TIMESTAMP        NULL,
    created_at     TIMESTAMP        DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP        DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_queue_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) -- NOTE: Kitchen queue – lifecycle independent of the order record.


-- ── 1.8  payment ────────────────────────────────────────────
--  Isolated for auditability and to avoid transitive deps.
--  1:1 with orders  (UNIQUE on order_id).
CREATE TABLE payment (
    payment_id     INT            AUTO_INCREMENT PRIMARY KEY,
    order_id       INT            NOT NULL UNIQUE,
    amount         DECIMAL(10,2)  NOT NULL,
    payment_method ENUM('cash','card','mobile') NOT NULL,
    paid_at        TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    received_by    INT            

    CONSTRAINT fk_pay_order FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_pay_staff FOREIGN KEY (received_by)
        REFERENCES staff(staff_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) -- NOTE: Payment records – one payment closes one order.


-- ── 1.9  audit_log ──────────────────────────────────────────
--  Append-only log written by triggers.
--  No FK constraints intentionally (log must survive row deletes).
CREATE TABLE audit_log (
    log_id     BIGINT       AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    action     ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id  INT,
    old_value  TEXT,
    new_value  TEXT,
    changed_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
) -- NOTE: Trigger-driven immutable audit trail.


-- ── 1.10  ingredient ────────────────────────────────────────
--  Standalone lookup table for raw ingredients.
--  All attributes depend solely on ingredient_id → BCNF
CREATE TABLE ingredient (
    ingredient_id  INT            AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100)   NOT NULL UNIQUE,
    stock_qty      DECIMAL(10,2)  NOT NULL DEFAULT 0,
    unit           VARCHAR(20)    NOT NULL DEFAULT 'kg',
    reorder_level  DECIMAL(10,2)  NOT NULL DEFAULT 5,
    created_at     TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_stock_qty     CHECK (stock_qty >= 0),
    CONSTRAINT chk_reorder_level CHECK (reorder_level >= 0)
) -- NOTE: Raw ingredients with stock tracking.


-- ── 1.11  menu_item_ingredient ──────────────────────────────
--  Junction table for M:N between menu_item and ingredient.
--  Composite PK (item_id, ingredient_id) — no surrogate key.
--  quantity_needed depends on the whole PK → 2NF ✔
CREATE TABLE menu_item_ingredient (
    item_id         INT           NOT NULL,
    ingredient_id   INT           NOT NULL,
    quantity_needed DECIMAL(10,2) NOT NULL,

    PRIMARY KEY (item_id, ingredient_id),

    CONSTRAINT chk_qty_needed CHECK (quantity_needed > 0),

    CONSTRAINT fk_mii_item FOREIGN KEY (item_id)
        REFERENCES menu_item(item_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_mii_ingredient FOREIGN KEY (ingredient_id)
        REFERENCES ingredient(ingredient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) -- NOTE: M:N junction — which ingredients a menu item needs and how much;


