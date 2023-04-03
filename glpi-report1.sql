/*    ==Параметры сценариев==

    Версия исходного сервера : SQL Server 2016 (13.0.4001)
    Выпуск исходного ядра СУБД : Выпуск Microsoft SQL Server Standard Edition
    Тип исходного ядра СУБД : Изолированный SQL Server

    Версия целевого сервера : SQL Server 2017
    Выпуск целевого ядра СУБД : Выпуск Microsoft SQL Server Standard Edition
    Тип целевого ядра СУБД : Изолированный SQL Server
*/

USE [GLPI-Linked]
GO
/****** Object:  StoredProcedure [dbo].[GLPI_problems2]    Script Date: 13.02.2023 14:00:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[GLPI_problems1] 

AS
BEGIN
declare @dat1 datetime
declare @dat2 datetime
declare       @cmd nvarchar(max)
declare       @sql nvarchar(max)
declare @timestamp1 integer
declare @timestamp2 integer
declare @stime1 varchar(25)
declare @stime2 varchar(25)
declare @ls varchar(5)
declare @lr varchar(5)
set @dat2 =GETDATE()
set @dat1 =DATEADD(day, -1,@dat2)
SET @ls='&lt;'
SET @lr='&gt;'
set @timestamp1 =  DATEDIFF(SECOND, {d '1970-01-01'}, @dat1 at time zone 'Belarus Standard Time')
set @timestamp2 =  DATEDIFF(SECOND, {d '1970-01-01'}, @dat2 at time zone 'Belarus Standard Time')
set @stime1=CONVERT(VARCHAR(25), @timestamp1)
set @stime2=CONVERT(VARCHAR(25), @timestamp2)

CREATE TABLE #MyTempTable (
 id  int,
 org  VARCHAR (1024),
 dat_ust  datetime, 
 date_creation  datetime,
 dat_voz datetime,
 f_name VARCHAR (255), 
 f_description VARCHAR(MAX),
 krit VARCHAR (50), 
 kat VARCHAR (50), 
 stat VARCHAR (50), 
 comments VARCHAR (MAX), 
 solution VARCHAR (MAX), 
 initi VARCHAR (MAX), 
 bdate datetime,  
 edate datetime, 
 tip VARCHAR (25), 
 software VARCHAR (255), 
 du46 bit 
  );

 set @sql = '
SELECT
DATE_FORMAT(FROM_UNIXTIME(' + CONVERT(VARCHAR(25), @timestamp1) + '),"%d.%m.%Y %H:%i") as bdate,
DATE_FORMAT(FROM_UNIXTIME(' + CONVERT(VARCHAR(25), @timestamp2) + '),"%d.%m.%Y %H:%i") as edate,
glpi_tickets.id AS id,
glpi_entities.completename AS org,
      DATE AS dat_voz,
	  glpi_tickets.date_creation,
      solvedate AS dat_ust,
glpi_tickets.name AS f_name ,
REPLACE(REPLACE(glpi_tickets.content,"&lt;","<"),"&gt;",">") AS f_description ,
CASE
    WHEN STATUS<5 AND glpi_plugin_fields_failcategoryfielddropdowns.id>7
        THEN "Критическая неустранённая"
    WHEN STATUS>=5 AND glpi_plugin_fields_failcategoryfielddropdowns.id>7
        THEN "Критическая устранённая"
    WHEN STATUS<5 AND (glpi_plugin_fields_failcategoryfielddropdowns.id<8 or ISNULL(glpi_plugin_fields_failcategoryfielddropdowns.id))
        THEN "Некритическая"
    ELSE "Некритическая"
END AS krit,
 "отказ" as tip,
glpi_plugin_fields_ticketfailures.dufoursixfield as du46,
CASE
    WHEN ISNULL(glpi_plugin_fields_failcategoryfielddropdowns.name) OR glpi_plugin_fields_failcategoryfielddropdowns.name="_нет"
        THEN "E"
    ELSE glpi_plugin_fields_failcategoryfielddropdowns.name
END AS kat,
 CASE glpi_tickets.status
         WHEN 1 THEN "Новый"  
         WHEN 2 THEN "В работе (назначен)"  
         WHEN 3 THEN "В работе (запланирован)"  
         WHEN 4 THEN "Ожидающий"  
         WHEN 5 THEN "Решен"  
         ELSE "Закрыт"  
      END as stat,
REPLACE(REPLACE((SELECT GROUP_CONCAT(DATE_FORMAT(DATE_ADD(DATE, INTERVAL 0 HOUR),"%d.%m.%y %H:%i"), "  /", CONCAT(realname," ", firstname)  ,"/",  " - " ,content SEPARATOR " ") AS content FROM glpi_itilfollowups LEFT JOIN glpi_users ON glpi_users.id=glpi_itilfollowups.users_id WHERE itemtype = "Ticket" AND items_id=glpi_tickets.id AND is_private=0 AND content NOT LIKE "%Решение одобрено%" GROUP BY items_id),"&lt;","<"),"&gt;",">") AS comments,
REPLACE(REPLACE((SELECT GROUP_CONCAT(content SEPARATOR " ") AS content  FROM glpi_itilsolutions WHERE itemtype = "Ticket" AND items_id=glpi_tickets.id GROUP BY items_id),"&lt;","<"),"&gt;",">") AS solution,
(SELECT  GROUP_CONCAT(CONCAT(IFNULL(CONCAT(glpi_usertitles.name,"<br>"),""), realname," ", firstname," <br>", phone,"")) AS "Исполнитель" FROM glpi_tickets_users
 INNER JOIN glpi_users ON glpi_tickets_users.users_id=glpi_users.id 
 LEFT JOIN glpi_usertitles ON glpi_usertitles.id=glpi_users.usertitles_id
 WHERE type=1 AND tickets_id=glpi_tickets.id ) AS initi,
 (SELECT ifnull(GROUP_CONCAT(glpi_softwares.name SEPARATOR ", "), "") from glpi_items_tickets 
								LEFT JOIN glpi_softwares ON glpi_softwares.id=glpi_items_tickets.items_id
								WHERE itemtype= "Software" AND tickets_id=glpi_tickets.id) AS software 
FROM glpi_tickets 
LEFT JOIN glpi_entities ON glpi_tickets.entities_id = glpi_entities.id
LEFT JOIN glpi_plugin_fields_ticketfailures ON glpi_plugin_fields_ticketfailures.items_id=glpi_tickets.id
LEFT JOIN glpi_plugin_fields_failcategoryfielddropdowns ON glpi_plugin_fields_failcategoryfielddropdowns.id=glpi_plugin_fields_ticketfailures.plugin_fields_failcategoryfielddropdowns_id
LEFT JOIN (SELECT tickets_id, COUNT(problems_id) as countpr FROM glpi_problems_tickets GROUP BY tickets_id) pt on pt.tickets_id=glpi_tickets.id

WHERE glpi_tickets.is_deleted<>TRUE  AND glpi_plugin_fields_failcategoryfielddropdowns.id>4 
AND (glpi_tickets.name not like "%тест%" and glpi_tickets.name not like "%2222%") ' +
'AND (UNIX_TIMESTAMP(glpi_tickets.DATE)<=' + @stime2 + ' ' +
' AND ( UNIX_TIMESTAMP(glpi_tickets.solvedate)>=' + @stime1 + ' OR glpi_tickets.solvedate IS NULL ))' +
 ' ORDER BY glpi_tickets.DATE desc
'
  SET @cmd = N'INSERT INTO #MyTempTable SELECT 
 id,
 org,
 dat_ust, 
 date_creation,
 dat_voz,
 f_name, 
 f_description,
 krit, 
 kat, 
 stat, 
 comments, 
 solution, 
 initi, 
 bdate,  
 edate, 
 tip,
 software,
  du46 
			 FROM OPENQUERY ([GLPI.RW.BY], ' + char(39) + @sql + char(39) + ') o'
 EXEC sp_executesql @cmd

 set @sql = '
SELECT
DATE_FORMAT(FROM_UNIXTIME(' + CONVERT(VARCHAR(25), @timestamp1) + '),"%d.%m.%Y %H:%i") as bdate,
DATE_FORMAT(FROM_UNIXTIME(' + CONVERT(VARCHAR(25), @timestamp2) + '),"%d.%m.%Y %H:%i") as edate,
glpi_changes.id, 
glpi_entities.completename AS org,
DATE AS dat_voz,
glpi_changes.date_creation,
solvedate AS dat_ust,
glpi_changes.name AS f_name, 
REPLACE(REPLACE(glpi_changes.content,"&lt;","<"),"&gt;",">") AS f_description ,
"-" AS krit,
"плановые и регл. работы" as tip, 
0 as du46,
"-" AS kat,
 CASE glpi_changes.status
         WHEN 1 THEN "Новый"  
         WHEN 9 THEN "Оценка"  
         WHEN 10 THEN "Согласование"  
         WHEN 7 THEN "Принята"  
         WHEN 4 THEN "Ожидающие"  
         WHEN 11 THEN "Тестирование"  
         WHEN 12 THEN "Уточнение"  
         WHEN 5 THEN "Применено"  
         WHEN 8 THEN "Рассмотрение"  
         ELSE "Закрыто"  
      END AS stat,
REPLACE(REPLACE((SELECT GROUP_CONCAT(DATE_FORMAT(DATE_ADD(DATE, INTERVAL 0 HOUR),"%d.%m.%y %H:%i"), "  /", CONCAT(realname," ", firstname)  ,"/",  " - " ,content SEPARATOR " ") AS content FROM glpi_itilfollowups LEFT JOIN glpi_users ON glpi_users.id=glpi_itilfollowups.users_id WHERE itemtype = "Change" AND items_id=glpi_changes.id AND is_private=0 AND content NOT LIKE "%Решение одобрено%" GROUP BY items_id),"&lt;","<"),"&gt;",">") AS comments,
REPLACE(REPLACE((SELECT GROUP_CONCAT(content SEPARATOR " ") AS content  FROM glpi_itilsolutions WHERE itemtype = "Change" AND items_id=glpi_changes.id GROUP BY items_id),"&lt;","<"),"&gt;",">") AS solution,
(SELECT  GROUP_CONCAT(CONCAT(IFNULL(CONCAT(glpi_usertitles.name,"<br>"),""), realname," ", firstname," <br>", phone,"")) AS "Исполнитель" FROM glpi_changes_users
 INNER JOIN glpi_users ON glpi_changes_users.users_id=glpi_users.id 
 LEFT JOIN glpi_usertitles ON glpi_usertitles.id=glpi_users.usertitles_id
 WHERE type=1 AND changes_id=glpi_changes.id ) AS initi,
 (SELECT ifnull(GROUP_CONCAT(glpi_softwares.name SEPARATOR ", "), "") from glpi_changes_items 
								LEFT JOIN glpi_softwares ON glpi_softwares.id=glpi_changes_items.items_id
								WHERE itemtype= "Software" AND changes_id=glpi_changes.id) AS software
 FROM glpi_changes
LEFT JOIN glpi_entities ON glpi_changes.entities_id = glpi_entities.id
WHERE glpi_changes.is_deleted=0 AND (glpi_changes.name not like "%тест%" and glpi_changes.name not like "%222%") ' +
'AND (UNIX_TIMESTAMP(glpi_changes.DATE)<=' + @stime2 + ' ' +
' AND ( UNIX_TIMESTAMP(glpi_changes.solvedate)>=' + @stime1 + ' OR glpi_changes.solvedate IS NULL ))' +
 ' ORDER BY glpi_changes.DATE desc'

   SET @cmd = N'INSERT INTO #MyTempTable SELECT 
 id,
 org,
 dat_ust, 
 date_creation,
 dat_voz,
 f_name, 
 f_description,
 krit, 
 kat, 
 stat, 
 comments, 
 solution, 
 initi, 
 bdate,  
 edate, 
 tip,
  software,
  du46 
			 FROM OPENQUERY ([GLPI.RW.BY], ' + char(39) + @sql + char(39) + ') o'
 EXEC sp_executesql @cmd

 SELECT 
  id as "ИД",
 org as "Организация",
 dat_ust as "Дата устранения", 
 date_creation  as "Дата регистрации", 
 dat_voz as "Дата возникновения",
 f_name as "Наименование", 
 f_description as "Описание",
 krit as "Критичность", 
 kat as "Категория", 
 stat as "Статус", 
 comments as "Комментарии", 
 solution as "Решение", 
 initi as "Инициатор", 
 bdate,  
 edate, 
 tip,
 software,
 du46 as "ДУ-46"
  FROM #MyTempTable ORDER BY dat_voz
END
