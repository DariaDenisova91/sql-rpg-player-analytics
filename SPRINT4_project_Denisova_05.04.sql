/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Денисова Дарья Валерьевна
 * Дата: 04.04.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
    COUNT(id) AS count_id,
    COUNT(CASE WHEN payer = 1 THEN id END) AS count_id_pay,
    ROUND(COUNT(CASE WHEN payer = 1 THEN id END)::numeric / COUNT(id),4) AS share_pay
FROM fantasy.users;

-- Вариант 2 без CASE (более быстрее и предпочтительней)
SELECT
    COUNT(id) AS count_id,
    SUM(payer) AS count_id_pay,
    AVG(payer) AS share_pay
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	race,
	COUNT(id) AS count_id_race,
    COUNT(CASE WHEN payer = 1 THEN id END) AS count_id_pay_race,
   	ROUND(COUNT(CASE WHEN payer = 1 THEN id END)::numeric / COUNT(id),4) AS share_pay_race
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY race
ORDER BY share_pay_race DESC;

-- Вариант 2 без CASE (более быстрее и предпочтительней)
SELECT 
	race,
	COUNT(id) AS count_id_race,
	SUM(payer) AS count_id_pay_race,
    ROUND(AVG(payer),4) AS share_pay_race
FROM fantasy.users AS u
JOIN fantasy.race AS r USING(race_id)
GROUP BY race
ORDER BY share_pay_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(amount) AS count_buy,
	SUM(amount) AS  sum_buy,
	MIN(amount) AS min_buy,
	MAX(amount) AS max_buy,
	ROUND(AVG(amount)::numeric,2) AS avg_buy,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median,
	ROUND(STDDEV(amount)::numeric,2) AS stand_dev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT 
	COUNT(CASE WHEN amount = 0 THEN 1 END) AS count_buy_zero,
	ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric/COUNT(amount),5) AS share_buy_zero
FROM fantasy.events;

-- Вариант 2 (с подзапросом. без CASE чтоб не гонять таблицу)
SELECT 
	COUNT(amount),
	(SELECT COUNT(amount) FROM fantasy.events)/COUNT(amount) AS share_buy_zero
FROM fantasy.events	
WHERE amount=0

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH paying_notpaying_users AS (
	SELECT
		u.id AS id_users,
		COUNT(e.amount) OVER(PARTITION BY u.id) AS count_buy_user,
		CASE WHEN payer = 0 THEN 'not_paying_user'
			 WHEN payer = 1 THEN 'paying_user' END AS status_pay_users,
		SUM(e.amount) OVER(PARTITION BY u.id) AS sum_buy_user
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id=e.id
)
SELECT 
	status_pay_users,
	COUNT (DISTINCT id_users) AS count_id_users,
	ROUND(AVG(count_buy_user)::numeric,2) AS avg_amount_users,
	ROUND(AVG(sum_buy_user)::numeric,2) AS avg_sum_amount_id
FROM paying_notpaying_users
GROUP BY status_pay_users;

-- Вариант 2 без оконных. Предпочтительней. Учитываются только активные клиента из events
SELECT
	CASE WHEN payer = 0 THEN 'not_paying_user'
		 WHEN payer = 1 THEN 'paying_user' END AS status_pay_users,
	COUNT(DISTINCT e.id) AS count_id_users,
	ROUND(COUNT(e.amount)::numeric/COUNT(DISTINCT e.id),2) AS avg_amount_users,
	ROUND(SUM(e.amount)::numeric/ COUNT(DISTINCT e.id),2) AS avg_sum_amount_id
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e ON u.id=e.id
WHERE e.amount > 0
GROUP BY status_pay_users

-- 2.4: Популярные эпические предметы:
WITH items_satus AS (
	SELECT 
		i.game_items,
		i.item_code,
		COUNT(*) AS count_sale,
		SUM(amount) AS sum_sale,
		COUNT(DISTINCT e.id) count_unic_users,
		SUM(COUNT(*)) OVER() AS total_count_sale,
		SUM(SUM(amount)) OVER() AS total_sum_sale,
		(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0) AS total_count_unic_users
	FROM fantasy.events AS e
	JOIN fantasy.items AS i ON e.item_code = i.item_code
	WHERE amount > 0
	GROUP BY i.item_code, i.game_items
)
SELECT 
	game_items,
	item_code,
	count_sale,
	ROUND((count_sale/total_count_sale)::numeric, 4) AS share_count_sale,
	sum_sale,
	ROUND((sum_sale/total_sum_sale)::numeric, 4) AS share_sum_sale,
	count_unic_users,
	total_count_unic_users,
	ROUND(count_unic_users::numeric/total_count_unic_users,4) AS share_share_unic_users
FROM items_satus	
ORDER BY count_sale DESC;

-- 2 вариант. Проще и без оконных. 
SELECT game_items, 
    COUNT(amount) AS count_sale, 
    ROUND(COUNT(amount)::numeric / (SELECT COUNT(amount) FROM fantasy.events),4) AS share_count_sale,
    COUNT (DISTINCT id) AS count_unic_users,
    ROUND(COUNT (DISTINCT id)::numeric / (SELECT COUNT(DISTINCT id) FROM fantasy.events),4) AS share_unic_users
FROM fantasy.events
RIGHT JOIN fantasy.items USING(item_code)
WHERE amount <> 0
GROUP BY game_items
ORDER BY count_sale DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH status_race AS (
	SELECT 
		race_id,
		COUNT(id) AS total_users
	FROM fantasy.users
	GROUP BY race_id
),
status_buy_users AS(
	SELECT 
		id,
		race_id,
		payer,
		COUNT(transaction_id) AS count_buy,
		SUM(amount) AS sum_buy
	FROM fantasy.events AS e
	JOIN fantasy.users AS u USING (id)
	WHERE amount >0
	GROUP BY id, race_id, payer
)
SELECT
	sbu.race_id,
	race,
	total_users,
	COUNT(id) AS count_users_pay,
	SUM(payer) AS count_users_with_buy,
	ROUND(COUNT(id)::numeric/total_users,2) AS share_pay,
	ROUND(SUM(payer)::numeric/total_users,2) AS share_activ_users,
	ROUND(AVG (count_buy)::numeric,2) AS avg_count_buy_user,
	ROUND(AVG(sum_buy)::numeric/AVG(count_buy),2) AS avg_buy_user_race,
	ROUND(AVG (sum_buy)::numeric,2) AS avg_sum_buy_user
FROM status_buy_users AS sbu
JOIN status_race AS sr USING (race_id)	
JOIN fantasy.race AS r USING (race_id)
GROUP BY sbu.race_id, race, total_users
ORDER BY race

-- Задача 2: Частота покупок
WITH 
interval_day_buy AS (
	SELECT 
		transaction_id,
		id,
		date::date,
        LAG(date::date) OVER (PARTITION BY id ORDER BY date::date) AS lag_date,
        date::date - LAG(date::date) OVER (PARTITION BY id ORDER BY date::date) AS days_interval
    FROM fantasy.events
    WHERE amount > 0
), 
active_buy_user AS (
 	SELECT
 		id,
 		COUNT(transaction_id) AS  count__buy_user,
 		AVG(days_interval) AS avg_days_interval,
 		NTILE(3) OVER(ORDER BY AVG(days_interval)) AS rank_users 	
 	FROM interval_day_buy
 	GROUP BY id
 	HAVING COUNT(transaction_id)>=25
),
user_stats AS (
	SELECT 
		au.id,
        au.count__buy_user,
        au.avg_days_interval,
        au.rank_users,
        u.payer
    FROM active_buy_user AS au
    JOIN fantasy.users AS u ON au.id = u.id
)    
SELECT
	CASE WHEN us.rank_users  = 1 THEN 'высокая частота'
		 WHEN us.rank_users  = 2 THEN 'умеренная частота'
		 WHEN us.rank_users  = 3 THEN 'низкая частота' END AS category,
		 COUNT(us.id) AS total_users_buy,
    	 COUNT(CASE WHEN us.payer = 1 THEN us.id END) AS active_count_users_buy,
    	 ROUND(COUNT(CASE WHEN us.payer = 1 THEN us.id END)::numeric / 
               COUNT(us.id), 4) AS share_active_users_buy,
    	 ROUND(AVG(us.count__buy_user), 2) AS avg_count__buy_user,
    	 ROUND(AVG(us.avg_days_interval),2) AS avg_days_interval_users
FROM user_stats AS us
GROUP BY category
ORDER BY avg_days_interval_users DESC;
