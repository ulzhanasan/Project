create database Customer_Transaction;
use Customer_Transaction;
select * from customers;

update customers set Gender = null where Gender = '';
update customers set Age = null where Age = '';
alter table customers modify Age int null;

create table Transactions
(date_new date,
Id_check int,
ID_client int,
Count_products decimal(10,3),
Sum_payment decimal(10,2));

show variables like 'secure_file_priv';

load data infile 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS.csv'
into table Transactions
fields terminated by ','
lines terminated by '\n'
ignore 1 rows;

-- 1 Задание

-- 1. Отбираем транзакции за нужный период: с 01.06.2015 по 01.06.2016 (не включая 01.06.2016)
WITH filtered_transactions AS (
    SELECT *
    FROM Transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
),

-- 2. Получаем список месяцев, в которых у каждого клиента были транзакции
months_per_client AS (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS year_m
    FROM filtered_transactions
    GROUP BY ID_client, year_m
),

-- 3. Оставляем только тех клиентов, у кого есть транзакции в каждом из 12 месяцев периода
clients_with_full_year_history AS (
    SELECT ID_client
    FROM months_per_client
    GROUP BY ID_client
    HAVING COUNT(DISTINCT year_m) = 12  -- Только если транзакции есть во всех 12 разных месяцах
),

-- 4. Считаем статистику по таким клиентам:
-- - общее количество операций
-- - общая сумма всех покупок
-- - средний чек (средняя сумма одной операции)
client_stats AS (
    SELECT 
        t.ID_client,
        COUNT(*) AS total_transactions,       -- Общее количество операций
        SUM(t.Sum_payment) AS total_payment,  -- Общая сумма покупок
        AVG(t.Sum_payment) AS avg_check       -- Средняя сумма одной покупки
    FROM filtered_transactions t
    JOIN clients_with_full_year_history cfh ON t.ID_client = cfh.ID_client
    GROUP BY t.ID_client
)

-- 5. Выводим итоговые метрики по каждому клиенту
SELECT 
    cs.ID_client,
    cs.avg_check AS average_check,                -- Средний чек (за одну операцию)
    cs.total_payment / 12 AS avg_monthly_sum,     -- Средняя сумма покупок за месяц
    cs.total_transactions                         -- Количество всех операций за период
FROM client_stats cs;

-- 2 Задание

-- 1. Общая сумма и количество операций за год (для расчёта долей)
WITH yearly_totals AS (
    SELECT
        COUNT(*) AS total_transactions_year,
        SUM(t.Sum_payment) AS total_sum_year
    FROM Transactions t
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
),

-- 2. Основные показатели по месяцам
monthly_stats AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        COUNT(*) AS transactions_in_month,
        SUM(t.Sum_payment) AS total_sum_in_month,
        AVG(t.Sum_payment) AS avg_check_in_month,
        COUNT(DISTINCT t.ID_client) AS unique_clients_in_month
    FROM Transactions t
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY month
),

-- 3. Гендерная статистика по месяцам: количество клиентов и затраты по полу
gender_stats AS (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        c.Gender,
        COUNT(DISTINCT t.ID_client) AS client_count,
        SUM(t.Sum_payment) AS total_gender_sum
    FROM Transactions t
    JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
    GROUP BY month, c.Gender
)

-- 4. Итоговая выборка: соединяем месячную статистику с годовой
SELECT
    ms.month,

    -- Средний чек
    ROUND(ms.avg_check_in_month, 2) AS avg_check,

    -- Кол-во операций в месяц
    ms.transactions_in_month AS operations_count,

    -- Кол-во клиентов
    ms.unique_clients_in_month AS active_clients,

    -- Доля операций от общего за год
    ROUND(ms.transactions_in_month / yt.total_transactions_year * 100, 2) AS transaction_share_percent,

    -- Доля суммы от общей за год
    ROUND(ms.total_sum_in_month / yt.total_sum_year * 100, 2) AS sum_share_percent,

    -- Процентное распределение полов по количеству клиентов
    ROUND(100 * SUM(CASE WHEN gs.Gender = 'M' THEN gs.client_count ELSE 0 END) / ms.unique_clients_in_month, 2) AS percent_male,
    ROUND(100 * SUM(CASE WHEN gs.Gender = 'F' THEN gs.client_count ELSE 0 END) / ms.unique_clients_in_month, 2) AS percent_female,
    ROUND(100 * SUM(CASE WHEN gs.Gender IS NULL THEN gs.client_count ELSE 0 END) / ms.unique_clients_in_month, 2) AS percent_na,

    -- Доля затрат по полу от суммы за месяц
    ROUND(100 * SUM(CASE WHEN gs.Gender = 'M' THEN gs.total_gender_sum ELSE 0 END) / ms.total_sum_in_month, 2) AS spend_share_male,
    ROUND(100 * SUM(CASE WHEN gs.Gender = 'F' THEN gs.total_gender_sum ELSE 0 END) / ms.total_sum_in_month, 2) AS spend_share_female,
    ROUND(100 * SUM(CASE WHEN gs.Gender IS NULL THEN gs.total_gender_sum ELSE 0 END) / ms.total_sum_in_month, 2) AS spend_share_na

FROM monthly_stats ms
JOIN yearly_totals yt ON 1=1  -- для получения общей суммы и кол-ва операций
LEFT JOIN gender_stats gs ON ms.month = gs.month
GROUP BY ms.month, ms.transactions_in_month, ms.total_sum_in_month, ms.avg_check_in_month, ms.unique_clients_in_month, yt.total_transactions_year, yt.total_sum_year
ORDER BY ms.month;
