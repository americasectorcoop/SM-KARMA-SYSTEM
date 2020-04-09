DROP PROCEDURE IF EXISTS KS_BAN_ADD;

DELIMITER $$
CREATE PROCEDURE KS_BAN_ADD(IN _target_steam_id VARCHAR(32), IN _target_ipv4 VARCHAR(16), IN _admin_steam_id VARCHAR(32), IN _reason_id INT UNSIGNED)
    NO SQL
BEGIN

	DECLARE _is_banned INT DEFAULT 0;
	DECLARE _time_to_ban INT DEFAULT 0;

	-- Variables de transformación
	DECLARE _target_id BIGINT DEFAULT SteamIdTo64(_target_steam_id);
	DECLARE _target_ip BIGINT DEFAULT INET_ATON(_target_ipv4);
	DECLARE _admin_id BIGINT DEFAULT SteamIdTo64(_admin_steam_id);

	SELECT
		-- COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1 >= ban counter, numero de bans
		-- Se verifica si el conteo no supero el maximo permitodo
		-- si si se multiplica numer o de intento * tiempo por intento 
		IF((COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1) < R.max_limit, (COUNT(IF(L.dt_created >= NOW() - INTERVAL R.time_to_remain DAY, 1, NULL)) + 1) * R.time_by_attempt, 0) INTO _time_to_ban
	FROM ks_bans_reasons AS R
	LEFT JOIN ks_bans_logs AS L ON L.ban_reason_id=R.id AND L.forgiven=0 AND L.target_steam_id=_target_id AND L.ban_reason_id=_reason_id
	WHERE R.id=_reason_id;

	START TRANSACTION;

	INSERT INTO ks_bans_logs (
		target_steam_id, target_ip, admin_hangman_steam_id, ban_reason_id, dt_ban_expiration
	) VALUES(
		_target_id, _target_ip, _admin_id, _reason_id, IF(_time_to_ban > 0, NOW() + INTERVAL _time_to_ban MINUTE, NULL)
	);

	COMMIT;

END$$
DELIMITER ;