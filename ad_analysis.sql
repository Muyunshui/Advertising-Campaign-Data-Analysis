##第一部分：整体广告效果分析

SELECT 
    COUNT(*) AS 曝光量, 
    SUM(点击) AS 点击量, 
    ROUND(SUM(点击)/COUNT(*),4) AS 整体CTR 
FROM raw_sample;

##第二部分：广告资源位效果分析

SELECT
  资源位,
  COUNT(*) AS 曝光量,
  SUM(点击) AS 点击量,
  ROUND(SUM(点击)/COUNT(*),4) AS CTR
FROM raw_sample
GROUP BY 资源位
ORDER BY CTR DESC;

##第三部分：商品类目 & 品牌效果分析

SELECT af.商品类目ID,
COUNT(*) AS 曝光,
SUM(rs.点击) AS 点击,
ROUND(SUM(rs.点击)/COUNT(*),4) AS CTR
FROM raw_sample rs
JOIN ad_feature af ON rs.广告单元ID = af.广告ID
GROUP BY af.商品类目ID
HAVING 曝光 >= 100
ORDER BY CTR DESC
LIMIT 10;

##第四部分：用户画像分析（高价值人群定位）

##1.不同年龄 、性别、年龄层次广告点击率
SELECT 
    up.性别1男2女,
    up.年龄层次,
    SUM(rs.点击) AS 点击量,
    COUNT(*) AS 曝光量
FROM raw_sample rs
JOIN user_profile up ON rs.用户ID = up.用户ID
GROUP BY up.性别1男2女, up.年龄层次;

##2.城市层级消费档次广告点击率
SELECT up.城市层级, up.消费档次,
SUM(rs.点击) AS 点击量, COUNT(*) AS 曝光量
FROM raw_sample rs
JOIN user_profile up ON rs.用户ID = up.用户ID
GROUP BY up.城市层级, up.消费档次;

##3.城市层级、购物深度广告点击率
SELECT up.城市层级, up.购物深度,
SUM(rs.点击) AS 点击量, COUNT(*) AS 曝光量
FROM raw_sample rs
JOIN user_profile up ON rs.用户ID = up.用户ID
GROUP BY up.城市层级, up.购物深度;

##4.城市层级 + 是否大学生广告点击率
SELECT up.城市层级, up.是否大学生,
SUM(rs.点击) AS 点击量, COUNT(*) AS 曝光量
FROM raw_sample rs
JOIN user_profile up ON rs.用户ID = up.用户ID
GROUP BY up.城市层级, up.是否大学生;

##5.消费档次 + 购物深度广告点击率
SELECT up.消费档次, up.购物深度,
SUM(rs.点击) AS 点击量, COUNT(*) AS 曝光量
FROM raw_sample rs
JOIN user_profile up ON rs.用户ID = up.用户ID
GROUP BY up.消费档次, up.购物深度;

##第五部分：用户历史行为与广告点击关系

SELECT
  IF(b.用户ID IS NOT NULL, '有历史行为', '无历史行为') AS 用户类型,
  COUNT(DISTINCT rs.用户ID) AS 用户数,
  SUM(rs.点击) AS 点击量,
  ROUND(SUM(rs.点击)/COUNT(*),4) AS CTR
FROM raw_sample rs
LEFT JOIN userbehavior b ON rs.用户ID = b.用户ID
GROUP BY 用户类型;

##第六部分：用户漏斗转化率

SELECT
    '1_浏览(pv)' AS `步骤`,
    COUNT(DISTINCT 用户ID) AS `用户数`,
    100.00 AS `整体转化率`,
    100.00 AS `步骤转化率`
FROM userbehavior
WHERE `行为类型` = 'pv'

UNION ALL

SELECT
    '2_加购(cart)' AS `步骤`,
    COUNT(DISTINCT 用户ID) AS `用户数`,
    ROUND(COUNT(DISTINCT 用户ID) / (SELECT COUNT(DISTINCT 用户ID) FROM userbehavior WHERE `行为类型` = 'pv') * 100, 2) AS `整体转化率`,
    ROUND(COUNT(DISTINCT 用户ID) / (SELECT COUNT(DISTINCT 用户ID) FROM userbehavior WHERE `行为类型` = 'pv') * 100, 2) AS `步骤转化率`
FROM userbehavior
WHERE `行为类型` = 'cart'

UNION ALL

SELECT
    '3_购买(buy)' AS `步骤`,
    COUNT(DISTINCT 用户ID) AS `用户数`,
    ROUND(COUNT(DISTINCT 用户ID) / (SELECT COUNT(DISTINCT 用户ID) FROM userbehavior WHERE `行为类型` = 'pv') * 100, 2) AS `整体转化率`,
    ROUND(COUNT(DISTINCT 用户ID) / (SELECT COUNT(DISTINCT 用户ID) FROM userbehavior WHERE `行为类型` = 'cart') * 100, 2) AS `步骤转化率`
FROM userbehavior
WHERE `行为类型` = 'buy'

ORDER BY `步骤`;

##第七部分：R-F-V 用户分层分析（改进版RFM加入浏览行为）

SELECT
    用户分层,
    COUNT(*) AS 用户数量
FROM (
    SELECT
        CASE
            WHEN R_score >= 4 AND F_score >= 4 AND V_score >= 4 THEN '高价值核心用户'
            WHEN V_score >= 4 AND F <= 2 AND last_view_days <= 90 THEN '高潜力浏览用户'
            WHEN V_score >= 4 AND F = 0 THEN '只逛不买用户'
            WHEN R_score <= 2 AND F_score >= 4 AND V_score >= 3 THEN '高价值沉睡用户'
            ELSE '一般用户'
        END AS 用户分层
    FROM (
        SELECT
            *,
            CASE WHEN R <= 60 THEN 5 WHEN R <= 180 THEN 3 ELSE 1 END AS R_score,
            CASE WHEN F >= 2 THEN 5 WHEN F >= 1 THEN 3 ELSE 1 END AS F_score,
            CASE WHEN V >= 10 THEN 5 WHEN V >= 5 THEN 3 ELSE 1 END AS V_score
        FROM (
            SELECT
                u.用户ID,
                IFNULL(ub.R, 999) AS R,
                IFNULL(ub.F, 0) AS F,
                IFNULL(uv.V, 0) AS V,
                IFNULL(uv.last_view_days, 999) AS last_view_days
            FROM 
                (SELECT DISTINCT 用户ID FROM userbehavior) u
            LEFT JOIN 
                (SELECT 用户ID,
                        DATEDIFF(CURDATE(), FROM_UNIXTIME(MAX(时间戳))) AS R,
                        COUNT(*) AS F
                 FROM userbehavior
                 WHERE 行为类型 = 'buy'
                 GROUP BY 用户ID) ub ON u.用户ID = ub.用户ID
            LEFT JOIN 
                (SELECT 用户ID,
                        COUNT(*) AS V,
                        DATEDIFF(CURDATE(), FROM_UNIXTIME(MAX(时间戳))) AS last_view_days
                 FROM userbehavior
                 WHERE 行为类型 = 'pv'
                 GROUP BY 用户ID) uv ON u.用户ID = uv.用户ID
        ) AS user_rfv
    ) AS user_score
) AS t
GROUP BY 用户分层
ORDER BY 用户数量 DESC;