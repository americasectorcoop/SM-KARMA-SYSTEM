DROP PROCEDURE IF EXISTS KS_BANS_GET;

DELIMITER $$
CREATE PROCEDURE KS_BANS_GET(IN _admin_steam_id VARCHAR(32)) NO SQL

BEGIN

DECLARE _admin_id BIGINT DEFAULT SteamIdTo64(_admin_steam_id);

SELECT
  P.nickname,
  L.id AS ban_id
FROM
  ks_bans_logs AS L
  INNER JOIN players AS P ON P.steamid = L.target_steam_id
  INNER JOIN ks_bans_reasons AS R ON R.id = L.ban_reason_id
WHERE
  L.admin_hangman_steam_id = _admin_id
  AND L.actived = 1
ORDER BY L.id DESC;

END$$
DELIMITER ;