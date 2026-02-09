/* =========================================================
   ClickHouse | Задача 4
   Таблицы:
   - dwh.products(itemid, name_ax, brand_name_ax, category)
   - dwh.sales(sale_id, date, itemid, qty, price)
   - dwh.stock(date, itemid, qty)
   ========================================================= */


/* =========================================================
   1) Метрики по товарам
   ========================================================= */

WITH
    toStartOfMonth(today())                 AS this_month_start,
    addMonths(this_month_start, -1)          AS last_month_start,
    addMonths(this_month_start, -3)          AS three_months_start
SELECT
    p.itemid        AS itemid,
    p.name_ax       AS name_ax,
    p.brand_name_ax AS brand_name_ax,
    p.category      AS category,

    /* last full month qty */
    sumIf(s.qty, s.date >= last_month_start AND s.date < this_month_start)                    AS qty_last_month,

    /* last full month revenue */
    sumIf(s.qty * s.price, s.date >= last_month_start AND s.date < this_month_start)          AS revenue_last_month,

    /* last full month avg price */
    sumIf(s.qty * s.price, s.date >= last_month_start AND s.date < this_month_start)
        / nullIf(sumIf(s.qty, s.date >= last_month_start AND s.date < this_month_start), 0)   AS avg_price_last_month,

    /* avg qty for last 3 full months (M-3, M-2, M-1) */
    sumIf(s.qty, s.date >= three_months_start AND s.date < this_month_start) / 3              AS avg_qty_3m,

    /* current stock qty (last snapshot) */
    st.stock_current_qty                                                                      AS stock_current_qty,

    /* stock gap */
    st.stock_current_qty - (sumIf(s.qty, s.date >= three_months_start AND s.date < this_month_start) / 3)
                                                                                              AS stock_current_minus_avg3m
FROM dwh.products p
LEFT JOIN dwh.sales s
    ON s.itemid = p.itemid
   AND s.date >= three_months_start
   AND s.date <  this_month_start
LEFT JOIN
(
    SELECT
        itemid,
        argMax(qty, date) AS stock_current_qty
    FROM dwh.stock
    GROUP BY itemid
) st
    ON st.itemid = p.itemid
GROUP BY
    p.itemid, p.name_ax, p.brand_name_ax, p.category, st.stock_current_qty
HAVING
    qty_last_month > 0
;


/* =========================================================
   2) Топ-5 брендов по выручке за прошлый месяц + сравнение с предыдущим
   ========================================================= */

WITH
    toStartOfMonth(today())                 AS this_month_start,
    addMonths(this_month_start, -1)          AS last_month_start,
    addMonths(this_month_start, -2)          AS prev_month_start
SELECT
    brand_name_ax,
    revenue_last_month,
    revenue_prev_month,
    revenue_last_month - revenue_prev_month                                  AS delta_revenue,
    revenue_last_month / nullIf(revenue_prev_month, 0) - 1                    AS revenue_change_pct
FROM
(
    SELECT
        p.brand_name_ax AS brand_name_ax,
        sumIf(s.qty * s.price, s.date >= last_month_start AND s.date < this_month_start) AS revenue_last_month,
        sumIf(s.qty * s.price, s.date >= prev_month_start AND s.date < last_month_start) AS revenue_prev_month
    FROM dwh.sales s
    JOIN dwh.products p
        ON p.itemid = s.itemid
    WHERE
        s.date >= prev_month_start
        AND s.date < this_month_start
    GROUP BY
        p.brand_name_ax
)
ORDER BY
    revenue_last_month DESC
LIMIT 5
;
