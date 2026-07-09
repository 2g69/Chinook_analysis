-- ============================================================
-- Анализ продаж цифрового музыкального магазина (Chinook)
-- СУБД: PostgreSQL 18
-- ============================================================


-- ============================================
-- БЛОК 1: Общая картина
-- ============================================

-- 1.1 Сколько всего клиентов в базе
SELECT COUNT(*) FROM customer;

-- 1.2 Клиенты по странам (по убыванию количества)
SELECT country, COUNT(*) AS customers_count
FROM customer
GROUP BY country
ORDER BY customers_count DESC;

-- 1.3 Топ-10 жанров по количеству треков (по genre_id)
SELECT genre_id, COUNT(*) AS number_of_tracks
FROM track
GROUP BY genre_id
ORDER BY number_of_tracks DESC
LIMIT 10;


-- ============================================
-- БЛОК 2: Деньги и JOIN
-- ============================================

-- 2.1 Топ-10 жанров по количеству треков (с названиями)
SELECT genre.name, COUNT(*) AS number_of_tracks
FROM track
JOIN genre ON track.genre_id = genre.genre_id
GROUP BY genre.name
ORDER BY number_of_tracks DESC
LIMIT 10;

-- 2.2 Топ-10 клиентов по сумме покупок
SELECT customer.first_name, customer.last_name, SUM(invoice.total) AS total_spent
FROM customer
JOIN invoice ON customer.customer_id = invoice.customer_id
GROUP BY customer.customer_id, customer.first_name, customer.last_name
ORDER BY total_spent DESC
LIMIT 10;

-- 2.3 Выручка по странам (топ-10)
SELECT billing_country, SUM(invoice.total) AS total_income
FROM invoice
GROUP BY billing_country
ORDER BY total_income DESC
LIMIT 10;

-- 2.4 Средний чек
SELECT ROUND(AVG(total), 2) AS average_invoice
FROM invoice;

-- 2.5 Топ-10 жанров по выручке (цепочка JOIN: invoice_line -> track -> genre)
SELECT genre.name, SUM(invoice_line.unit_price * invoice_line.quantity) AS total_income
FROM invoice_line
JOIN track ON invoice_line.track_id = track.track_id
JOIN genre ON track.genre_id = genre.genre_id
GROUP BY genre.name
ORDER BY total_income DESC
LIMIT 10;


-- ============================================
-- БЛОК 3: Динамика и оконные функции
-- ============================================

-- 3.1 Выручка по годам
SELECT EXTRACT(YEAR FROM invoice_date) AS year, SUM(total) AS total
FROM invoice
GROUP BY year
ORDER BY year;

-- 3.2 Выручка по месяцам (проверка сезонности)
SELECT EXTRACT(MONTH FROM invoice_date) AS month, SUM(total) AS total
FROM invoice
GROUP BY month
ORDER BY month;

-- 3.3 Топ-3 самых прибыльных трека в каждом жанре
-- Вариант А: ROW_NUMBER() — всегда ровно 3 трека на жанр.
-- При одинаковой выручке нумерует произвольно (1,2,3,4...), поэтому
-- лишние треки-"ничьи" отсекаются. Отвечает на вопрос:
-- "дай мне ровно 3 трека, даже если среди равных выбор произволен".
SELECT *
FROM (
    SELECT
        genre.name AS genre,
        track.name AS track,
        SUM(invoice_line.unit_price * invoice_line.quantity) AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY genre.name
            ORDER BY SUM(invoice_line.unit_price * invoice_line.quantity) DESC
        ) AS row_num
    FROM invoice_line
    JOIN track ON invoice_line.track_id = track.track_id
    JOIN genre ON track.genre_id = genre.genre_id
    GROUP BY genre.name, track.name
) AS ranked
WHERE row_num <= 3
ORDER BY genre, row_num;

-- 3.3 (альтернатива) Топ-3 трека в каждом жанре через RANK()
-- Вариант Б: RANK() — при одинаковой выручке присваивает одинаковый ранг
-- (1,1,1...), поэтому в жанрах с большим числом "ничьих" строк будет
-- больше трёх — показывает ВСЕХ претендентов на топ-места честно.
-- Отвечает на вопрос: "покажи топ-3 по местам, а при ничьей — всех, кто делит место".
SELECT *
FROM (
    SELECT
        genre.name AS genre,
        track.name AS track,
        SUM(invoice_line.unit_price * invoice_line.quantity) AS revenue,
        RANK() OVER (
            PARTITION BY genre.name
            ORDER BY SUM(invoice_line.unit_price * invoice_line.quantity) DESC
        ) AS rank
    FROM invoice_line
    JOIN track ON invoice_line.track_id = track.track_id
    JOIN genre ON track.genre_id = genre.genre_id
    GROUP BY genre.name, track.name
) AS ranked
WHERE rank <= 3
ORDER BY genre, rank;
