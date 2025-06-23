SELECT * FROM audiobooks;
SELECT * FROM audio_cards;
SELECT * FROM listenings;
-- 1.Выведите сколько пользователей добавили книгу 'Coraline', сколько пользователей прослушало больше 10%.
SELECT COUNT(DISTINCT user_id ) AS user_count
FROM audio_cards
WHERE audiobook_uuid = ( SELECT uuid FROM audiobooks
						WHERE title = 'Coraline');

SELECT COUNT(DISTINCT user_id ) AS user_count
FROM listenings
WHERE audiobook_uuid = ( SELECT uuid FROM audiobooks
						WHERE title = 'Coraline')
AND (position_to - position_from) > (0.1 * (SELECT duration FROM audiobooks WHERE title = 'Coraline'));

-- 2 По каждой операционной системе и названию книги выведите количество пользователей, сумму прослушивания в часах, не учитывая тестовые прослушивания. 
SELECT a.title, l.os_name , COUNT(DISTINCT l.user_id ) AS user_count, (SUM(l.position_to - l.position_from) / 3600) AS sum_hour
FROM listenings AS l
JOIN audiobooks AS a
ON l.audiobook_uuid = a.uuid
WHERE l.is_test = 0
GROUP BY a.title, l.os_name;

-- 3.Найдите книгу, которую слушает больше всего людей
SELECT a.title AS book_name
FROM listenings AS l
JOIN audiobooks AS a
ON l.audiobook_uuid = a.uuid
GROUP BY a.title
ORDER BY COUNT(DISTINCT l.user_id) DESC
LIMIT 1;

-- 4.Найдите книгу, которую чаще всего дослушивают до конца.
SELECT a.title  AS book_name
FROM listenings AS l
JOIN audiobooks AS a
ON l.audiobook_uuid = a.uuid
WHERE a.duration  = l.position_to
GROUP BY a.title
ORDER BY COUNT(DISTINCT l.user_id) DESC
LIMIT 1;
