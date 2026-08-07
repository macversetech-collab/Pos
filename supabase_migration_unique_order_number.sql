-- ============================================================
-- SQL Migration: Add UNIQUE constraint on orders.order_number
-- Purpose: Prevent duplicate vouchers at the database level
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- Step 1: Check for any existing duplicates BEFORE adding constraint
-- Run this query first to see if cleanup is needed:
SELECT order_number, COUNT(*) as duplicate_count
FROM orders
GROUP BY order_number
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Step 2: If duplicates exist, keep only the EARLIEST record (by created_at)
-- Uncomment and run ONLY if Step 1 returned results:
--
-- DELETE FROM orders a
-- USING orders b
-- WHERE a.created_at > b.created_at
--   AND a.order_number = b.order_number;

-- Step 3: Add the UNIQUE constraint
-- This will fail if Step 2 was needed but not run
ALTER TABLE orders
ADD CONSTRAINT uq_orders_order_number UNIQUE (order_number);

-- Step 4: Verify the constraint was created
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'orders'
  AND constraint_type = 'UNIQUE';
