/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Игнатьев Валерий
 * Дата: 01.07.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков


-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT(id) AS total_users,
	SUM(CASE WHEN payer > 0 THEN 1 ELSE 0 END) AS payer_users,
	ROUND(SUM(CASE WHEN payer > 0 THEN 1 ELSE 0 END)::NUMERIC/COUNT(id),2) AS payer_users_share
FROM fantasy.users;

--total_users|payer_users|payer_users_share|
-------------+-----------+-----------------+
--      22214|       3929|             0.18|


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
	r.race,
	SUM(CASE WHEN payer > 0 THEN 1 ELSE 0 END) AS payer_users,
	COUNT(u.id) AS total_users,
	ROUND(SUM(CASE WHEN payer > 0 THEN 1 ELSE 0 END)::NUMERIC/COUNT(u.id),2) AS payer_users_share
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY payer_users DESC;

--race    |payer_users|total_users|payer_users_share|
----------+-----------+-----------+-----------------+
--Human   |       1114|       6328|             0.18|
--Hobbit  |        659|       3648|             0.18|
--Orc     |        636|       3619|             0.18|
--Northman|        626|       3562|             0.18|
--Elf     |        427|       2501|             0.17|
--Demon   |        238|       1229|             0.19|
--Angel   |        229|       1327|             0.17|


--Выводы:
--Доля платящих пользователей -18%
--Все доли платящих пользователей по расам примерно одинаковые



-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(transaction_id) AS transaction_qty,
	SUM(amount) AS transactions_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount) AS average_amount,
	PERCENTILE_CONT(0.5) 
	WITHIN GROUP (ORDER BY amount) 
	AS median_amount,
	STDDEV(amount) AS standard_deviation
FROM fantasy.events;

--transaction_qty|transactions_amount|min_amount|max_amount|average_amount   |median_amount    |standard_deviation|
-----------------+-------------------+----------+----------+-----------------+-----------------+------------------+
--        1307678|          686615040|       0.0|  486615.1|525.6919663589833|74.86000061035156| 2517.345444427788|


--Выводы:
--Количество транзакций пользователей 1 307 678, сумма всех транзакций 686 615 040.
--Минимальная стоимость транзакции 0 райских лепестков, если убрать нулевые значения, то 0.1 райский лепесток.
--Максимальная транзакция 486 615.1 райский лепесток.
--Большой разброс между медианой (74.86) и средним значением (525.69). 
--Высокое стандартное отклонение (2517.35)



-- 2.2: Аномальные нулевые покупки:
WITH transaction_stats AS (
    SELECT
        COUNT(transaction_id) AS transaction_qty,
        SUM(CASE WHEN amount > 0 THEN 0 ELSE 1 END) AS zero_transaction_qty
    FROM fantasy.events
)
SELECT
    transaction_qty,
    zero_transaction_qty,
    ROUND(zero_transaction_qty::numeric / transaction_qty, 4) AS zero_transaction_share
FROM transaction_stats;

--transaction_qty|zero_transaction_qty|zero_transaction_share|
-----------------+--------------------+----------------------+
--        1307678|                 907|                0.0007|


--Выводы:
--Кол-во аномальных покупок с ценой 0 райских лепестков мало (0.07%), присутствуют покупки с маленькой ценой, как пример 0.1 райский лепесток. 
--Без цен на товары и правил игры нельзя сделать вывод, являются ли такие покупки аномальными
   


-- 2.3: Популярные эпические предметы:
WITH item_stats AS (
    SELECT
        game_items,
        COUNT(transaction_id) AS sales_qty,
        COUNT(DISTINCT id) AS users,
        SUM(COUNT(transaction_id)) OVER() AS total_sales
    FROM fantasy.events
    LEFT JOIN fantasy.items USING(item_code)
    WHERE amount > 0
    GROUP BY game_items
), total_users AS(
	 SELECT
	 	COUNT(DISTINCT id) AS users
	 FROM fantasy.events
	 WHERE amount > 0
)
SELECT
    game_items,
    sales_qty,
    ROUND(sales_qty::NUMERIC / total_sales, 6) AS sales_share,
    ROUND(users::NUMERIC / (SELECT * FROM total_users), 6) AS users_share
FROM item_stats
ORDER BY sales_qty DESC;

--game_items               |sales_qty|sales_share|users_share|
---------------------------+---------+-----------+-----------+
--Book of Legends          |  1004516|   0.768701|   0.884072|
--Bag of Holding           |   271875|   0.208051|   0.867687|
--Necklace of Wisdom       |    13828|   0.010582|   0.117958|
--Gems of Insight          |     3833|   0.002933|   0.067136|
--Treasure Map             |     3183|   0.002436|   0.059378|
--Amulet of Protection     |     1078|   0.000825|   0.032263|
--Silver Flask             |      795|   0.000608|   0.045893|
--Strength Elixir          |      580|   0.000444|   0.023998|
--Glowing Pendant          |      563|   0.000431|   0.025665|
-- и т.д


--Выводы:
--Самые популярные эпические товары:
--- “Book of Legends” принесла 76.87% от всех продаж и хоть раз купили ее 88.4% пользователей
--- “Bag of Holding” принесла 20.8% от всех продаж и хоть раз купили ее 86.76% пользователей
--Остальные предметы имеют значительно меньшую долю



-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH payed_users AS(
--Вычисляем всех игроков
	SELECT
		race_id,
		COUNT(id) AS total_users
	FROM fantasy.users
	GROUP BY race_id
), purchase_users AS(
-- Вычисляем игроков которые совершают покупки по расам и юзерам и их метрики
	SELECT
		race_id,
		e.id,
		COUNT(transaction_id) AS transactions_qty,
		SUM(amount) AS sum_amount
	FROM fantasy.events AS e
	LEFT JOIN fantasy.users USING(id)
	WHERE amount > 0
	GROUP BY race_id,e.id
), payers_by_purchase AS(
--Вычисляем платящих игроков, которые совершали покупки
	SELECT
		race_id,
		COUNT(id) AS payer_users
	FROM fantasy.users
	WHERE payer = 1 AND id IN (SELECT id FROM purchase_users)
	GROUP BY race_id
),purchase_by_race AS(
-- Вычисляем игроков которые совершают покупки по расам и их метрики
	SELECT
		race_id,
		COUNT(id) AS purchase_users,
		ROUND(AVG(transactions_qty),2) AS avg_transactions_per_user,
		ROUND(AVG(sum_amount)::NUMERIC/AVG(transactions_qty),2) AS avg_transaction_amount_per_user,
		ROUND(AVG(sum_amount)::NUMERIC,2) AS avg_amount_per_user
	FROM purchase_users
	GROUP BY race_id
) 
SELECT
	r.race,
	p.total_users,
	pbr.purchase_users,
	ROUND(pbr.purchase_users::NUMERIC/p.total_users, 2) AS purchasers_share,
	ROUND(pbp.payer_users::NUMERIC/pbr.purchase_users,2) AS payers_share,
	avg_transactions_per_user,
	avg_transaction_amount_per_user,
	avg_amount_per_user
FROM fantasy.race AS r
LEFT JOIN payed_users AS p ON r.race_id = p.race_id
LEFT JOIN purchase_by_race AS pbr ON r.race_id = pbr.race_id
LEFT JOIN payers_by_purchase AS pbp ON r.race_id = pbp.race_id;

--race    |total_users|purchase_users|purchasers_share|payers_share|avg_transactions_per_user|avg_transaction_amount_per_user|avg_amount_per_user|
----------+-----------+--------------+----------------+------------+-------------------------+-------------------------------+-------------------+
--Demon   |       1229|           737|            0.60|        0.20|                    77.87|                         529.06|           41197.38|
--Elf     |       2501|          1543|            0.62|        0.16|                    78.79|                         682.33|           53761.65|
--Angel   |       1327|           820|            0.62|        0.17|                   106.80|                         455.68|           48668.65|
--Hobbit  |       3648|          2266|            0.62|        0.18|                    86.13|                         552.90|           47620.92|
--Orc     |       3619|          2276|            0.63|        0.17|                    81.74|                         510.90|           41760.04|
--Northman|       3562|          2229|            0.63|        0.18|                    82.10|                         761.50|           62520.66|
--Human   |       6328|          3921|            0.62|        0.18|                   121.40|                         403.13|           48941.01|


--Выводы:
--Больше всего пользователей играет за людей 28,49% от всех пользователей. Хоббиты, Орки и Северяне занимают примерно 16% каждый.
--Доля игроков, которые совершают покупки в игре для каждой расы примерно одинаковые. Доля платящих игроков от пользователей, совершающих покупки для каждой расы примерно одинаковые.
--Больше всего покупок совершают Люди (121.4), для такого кол-ва играющих людей этот показатель не аномально высокий, и Ангелы (106.8) для 7,1% играющих за эту расу игроков этот показатель высокий.
--Средняя стоимость одной транзакции выше для Северян (761) и Эльфов (682). Разброс не велик.
--Средняя стоимость всех покупок на пользователя выше для Северян (62520.66) и Эльфов (53761.65).
--Гипотеза о равной потребности в покупках для разных рас подтверждается - различия в показателях незначительны.


--Общие выводы:
--Доля платящих пользователей стабильна для каждой расы и составляет 18%
--Раса персонажа не оказывает существенного влияния на платёжеспособность
--“Book of Legends” основной драйвер продаж 
--Наивысшая доля платящих пользователей от покупающих у демонов (20%)

--Рекомендации:
--Проработать продвижение Book of Legends как ключевого продукта
--Анализ нулевых транзакции и транзакций с аномальными ценами


